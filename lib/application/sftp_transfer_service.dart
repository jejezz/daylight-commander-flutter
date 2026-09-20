import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../domain/entities/file_conflict.dart';
import '../domain/entities/file_entry.dart';
import 'cancel_token.dart';
import 'file_operation_service.dart';
import 'remote_dir_walk.dart';
import 'sftp_session_manager.dart';

/// 로컬↔SFTP, SFTP↔SFTP 전송. [FtpTransferService]와 같은 구조 — 개별 파일은
/// 충돌 확인을 지원하지만, dartssh2에는 폴더 통째 전송 헬퍼가 없어 직접
/// 재귀 순회한다(폴더 내부 개별 충돌 확인은 지원하지 않고 있으면 덮어씀).
class SftpTransferService {
  const SftpTransferService(this._sessions);

  final SftpSessionManager _sessions;

  SftpClient _requireClient(Uri sftpUri) {
    final client = _sessions.clientForUri(sftpUri);
    if (client == null) {
      throw StateError('연결된 SFTP 세션이 없습니다. 먼저 SFTP 서버에 연결하세요.');
    }
    return client;
  }

  Future<bool> _exists(SftpClient client, String path) async {
    try {
      await client.stat(path);
      return true;
    } on SftpStatusError catch (e) {
      if (e.code == SftpStatusCode.noSuchFile) return false;
      rethrow;
    }
  }

  Future<void> _writeFile(SftpClient client, File localFile, String remotePath) async {
    final handle = await client.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
    );
    try {
      await handle.writeBytes(await localFile.readAsBytes());
    } finally {
      await handle.close();
    }
  }

  Future<void> _readFile(SftpClient client, String remotePath, File localFile) async {
    await localFile.parent.create(recursive: true);
    final handle = await client.open(remotePath);
    try {
      final sink = localFile.openWrite();
      await handle.downloadTo(sink);
      await sink.close();
    } finally {
      await handle.close();
    }
  }

  Future<List<RemoteDirEntry>> _listRemote(SftpClient client, String path) async {
    final names = await client.listdir(path);
    return names
        .where((e) => e.filename != '.' && e.filename != '..')
        .map((e) => RemoteDirEntry(name: e.filename, isDirectory: e.attr.isDirectory))
        .toList();
  }

  Future<void> upload({
    required List<FileEntry> sources,
    required Uri destinationDir,
    required bool deleteSourceAfter,
    required ConflictResolver onConflict,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final client = _requireClient(destinationDir);
    final destPath = destinationDir.path.isEmpty ? '/' : destinationDir.path;
    final total = sources.length;
    var done = 0;
    ConflictAction? bulkAction;

    for (final entry in sources) {
      cancelToken?.throwIfCancelled();
      final localPath = entry.location.toFilePath();
      var remoteName = entry.name;
      var remotePath = '$destPath/$remoteName';

      if (entry.isDirectory) {
        await uploadDirectoryRecursive(
          localDir: Directory(localPath),
          remoteDirPath: remotePath,
          mkdirRemote: (path) async {
            if (!await _exists(client, path)) await client.mkdir(path);
          },
          uploadFile: (file, path) => _writeFile(client, file, path),
        );
      } else {
        final file = File(localPath);
        if (await _exists(client, remotePath)) {
          final stat = await client.stat(remotePath);
          final action = bulkAction ??
              await onConflict(FileConflict(
                sourcePath: localPath,
                destinationPath: remotePath,
                sourceSizeBytes: await file.length(),
                destinationSizeBytes: stat.size,
                sourceModifiedAt: (await file.stat()).modified,
                destinationModifiedAt: null,
              ));
          if (action == ConflictAction.overwriteAll) bulkAction = ConflictAction.overwrite;
          if (action == ConflictAction.skipAll) bulkAction = ConflictAction.skip;
          if (action == ConflictAction.cancel) throw const OperationCancelledException();
          final effective = bulkAction ?? action;
          if (effective == ConflictAction.skip) {
            done++;
            onProgress?.call(FileOperationProgress(done: done, total: total, currentName: entry.name));
            continue;
          } else if (effective == ConflictAction.rename) {
            remoteName = await _availableRemoteName(client, destPath, remoteName);
            remotePath = '$destPath/$remoteName';
          }
        }
        await _writeFile(client, file, remotePath);
      }

      if (deleteSourceAfter) {
        if (entry.isDirectory) {
          await Directory(localPath).delete(recursive: true);
        } else {
          await File(localPath).delete();
        }
      }
      done++;
      onProgress?.call(FileOperationProgress(done: done, total: total, currentName: entry.name));
    }
  }

  Future<void> download({
    required List<FileEntry> sources,
    required String destinationDir,
    required bool deleteSourceAfter,
    required ConflictResolver onConflict,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (sources.isEmpty) return;
    final client = _requireClient(sources.first.location);
    final total = sources.length;
    var done = 0;
    ConflictAction? bulkAction;

    for (final entry in sources) {
      cancelToken?.throwIfCancelled();
      var localPath = p.join(destinationDir, entry.name);

      if (entry.isDirectory) {
        await downloadDirectoryRecursive(
          remoteDirPath: entry.location.path,
          localDir: Directory(localPath),
          listRemote: (path) => _listRemote(client, path),
          downloadFile: (path, file) => _readFile(client, path, file),
        );
      } else {
        final localFile = File(localPath);
        if (await localFile.exists()) {
          final stat = await client.stat(entry.location.path);
          final action = bulkAction ??
              await onConflict(FileConflict(
                sourcePath: entry.location.path,
                destinationPath: localPath,
                sourceSizeBytes: stat.size,
                destinationSizeBytes: await localFile.length(),
                sourceModifiedAt: entry.modifiedAt,
                destinationModifiedAt: (await localFile.stat()).modified,
              ));
          if (action == ConflictAction.overwriteAll) bulkAction = ConflictAction.overwrite;
          if (action == ConflictAction.skipAll) bulkAction = ConflictAction.skip;
          if (action == ConflictAction.cancel) throw const OperationCancelledException();
          final effective = bulkAction ?? action;
          if (effective == ConflictAction.skip) {
            done++;
            onProgress?.call(FileOperationProgress(done: done, total: total, currentName: entry.name));
            continue;
          } else if (effective == ConflictAction.rename) {
            localPath = await _availableLocalName(localPath);
          }
        }
        await _readFile(client, entry.location.path, File(localPath));
      }

      if (deleteSourceAfter) {
        if (entry.isDirectory) {
          await deleteDirectoryRecursive(
            remoteDirPath: entry.location.path,
            listRemote: (path) => _listRemote(client, path),
            deleteFile: client.remove,
            deleteEmptyDir: client.rmdir,
          );
        } else {
          await client.remove(entry.location.path);
        }
      }
      done++;
      onProgress?.call(FileOperationProgress(done: done, total: total, currentName: entry.name));
    }
  }

  /// 서로 다른(혹은 같은) SFTP 세션 간 전송 — 로컬 임시 폴더 경유
  /// ([FtpTransferService.transferBetweenFtpSessions]와 같은 이유: SFTP
  /// 표준에도 서버간 직접 복사 명령이 없다).
  Future<void> transferBetweenSftpSessions({
    required List<FileEntry> sources,
    required Uri destinationDir,
    required bool deleteSourceAfter,
    required ConflictResolver onConflict,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (sources.isEmpty) return;
    final tempDir = await Directory.systemTemp.createTemp('daylight_commander_sftp_');
    try {
      await download(
        sources: sources,
        destinationDir: tempDir.path,
        deleteSourceAfter: false,
        onConflict: onConflict,
        cancelToken: cancelToken,
      );
      final tempEntries = [
        for (final entry in sources)
          FileEntry(
            location: Uri.file(p.join(tempDir.path, entry.name)),
            name: entry.name,
            isDirectory: entry.isDirectory,
          ),
      ];
      await upload(
        sources: tempEntries,
        destinationDir: destinationDir,
        deleteSourceAfter: false,
        onConflict: onConflict,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      if (deleteSourceAfter) {
        final srcClient = _requireClient(sources.first.location);
        for (final entry in sources) {
          if (entry.isDirectory) {
            await deleteDirectoryRecursive(
              remoteDirPath: entry.location.path,
              listRemote: (path) => _listRemote(srcClient, path),
              deleteFile: srcClient.remove,
              deleteEmptyDir: srcClient.rmdir,
            );
          } else {
            await srcClient.remove(entry.location.path);
          }
        }
      }
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> deleteEntry(FileEntry entry) async {
    final client = _requireClient(entry.location);
    if (entry.isDirectory) {
      await deleteDirectoryRecursive(
        remoteDirPath: entry.location.path,
        listRemote: (path) => _listRemote(client, path),
        deleteFile: client.remove,
        deleteEmptyDir: client.rmdir,
      );
    } else {
      await client.remove(entry.location.path);
    }
  }

  Future<void> createFolder({required Uri parentDir, required String name}) async {
    final client = _requireClient(parentDir);
    final path = parentDir.path.isEmpty ? '/' : parentDir.path;
    await client.mkdir('$path/$name');
  }

  Future<void> createFile({required Uri parentDir, required String name}) async {
    final client = _requireClient(parentDir);
    final path = parentDir.path.isEmpty ? '/' : parentDir.path;
    final handle = await client.open(
      '$path/$name',
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
    );
    await handle.close();
  }

  Future<void> rename({required Uri location, required String newName}) async {
    final client = _requireClient(location);
    final dir = p.posix.dirname(location.path);
    await client.rename(location.path, '$dir/$newName');
  }

  Future<String> _availableRemoteName(SftpClient client, String dir, String name) async {
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    var i = 2;
    String candidate;
    do {
      candidate = '$base ($i)$ext';
      i++;
    } while (await _exists(client, '$dir/$candidate'));
    return candidate;
  }

  Future<String> _availableLocalName(String path) async {
    final dir = p.dirname(path);
    final ext = p.extension(path);
    final base = p.basenameWithoutExtension(path);
    var i = 2;
    String candidate;
    do {
      candidate = p.join(dir, '$base ($i)$ext');
      i++;
    } while (await FileSystemEntity.type(candidate) != FileSystemEntityType.notFound);
    return candidate;
  }
}
