import 'dart:io';

import 'package:dio/dio.dart' hide CancelToken, ProgressCallback;
import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../domain/entities/file_conflict.dart';
import '../domain/entities/file_entry.dart';
import 'cancel_token.dart';
import 'file_operation_service.dart';
import 'remote_dir_walk.dart';
import 'webdav_session_manager.dart';

/// 로컬↔WebDAV, WebDAV↔WebDAV 전송. [FtpTransferService]와 같은 구조. WebDAV의
/// DELETE/MOVE는 컬렉션(폴더)에 대해 서버가 알아서 재귀 처리해주지만, 업로드/
/// 다운로드는 그런 서버 기능이 없어 직접 재귀 순회한다(폴더 내부 개별 충돌
/// 확인은 지원하지 않고 있으면 덮어씀 — FTP/SFTP와 같은 스코프 축소).
class WebdavTransferService {
  const WebdavTransferService(this._sessions);

  final WebdavSessionManager _sessions;

  webdav.Client _requireClient(Uri webdavUri) {
    final client = _sessions.clientForUri(webdavUri);
    if (client == null) {
      throw StateError('연결된 WebDAV 세션이 없습니다. 먼저 WebDAV 서버에 연결하세요.');
    }
    return client;
  }

  Future<webdav.File?> _statOrNull(webdav.Client client, String path) async {
    try {
      return await client.readProps(path);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<RemoteDirEntry>> _listRemote(webdav.Client client, String path) async {
    final files = await client.readDir(path);
    return files
        .where((f) => f.name != null && f.name!.isNotEmpty)
        .map((f) => RemoteDirEntry(name: f.name!, isDirectory: f.isDir ?? false))
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
          mkdirRemote: client.mkdirAll,
          uploadFile: (file, path) => client.writeFromFile(file.path, path),
        );
      } else {
        final file = File(localPath);
        final existing = await _statOrNull(client, remotePath);
        if (existing != null) {
          final action = bulkAction ??
              await onConflict(FileConflict(
                sourcePath: localPath,
                destinationPath: remotePath,
                sourceSizeBytes: await file.length(),
                destinationSizeBytes: existing.size,
                sourceModifiedAt: (await file.stat()).modified,
                destinationModifiedAt: existing.mTime,
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
        await client.writeFromFile(localPath, remotePath);
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
          downloadFile: (path, file) => client.read2File(path, file.path),
        );
      } else {
        final localFile = File(localPath);
        if (await localFile.exists()) {
          final remoteProps = await client.readProps(entry.location.path);
          final action = bulkAction ??
              await onConflict(FileConflict(
                sourcePath: entry.location.path,
                destinationPath: localPath,
                sourceSizeBytes: remoteProps.size,
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
        await client.read2File(entry.location.path, localPath);
      }

      if (deleteSourceAfter) {
        await client.remove(entry.isDirectory ? '${entry.location.path}/' : entry.location.path);
      }
      done++;
      onProgress?.call(FileOperationProgress(done: done, total: total, currentName: entry.name));
    }
  }

  /// 서로 다른(혹은 같은) WebDAV 세션 간 전송 — 로컬 임시 폴더 경유
  /// ([FtpTransferService.transferBetweenFtpSessions]와 같은 이유).
  Future<void> transferBetweenWebdavSessions({
    required List<FileEntry> sources,
    required Uri destinationDir,
    required bool deleteSourceAfter,
    required ConflictResolver onConflict,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (sources.isEmpty) return;
    final tempDir = await Directory.systemTemp.createTemp('daylight_commander_webdav_');
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
          await srcClient.remove(entry.isDirectory ? '${entry.location.path}/' : entry.location.path);
        }
      }
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> deleteEntry(FileEntry entry) async {
    final client = _requireClient(entry.location);
    await client.remove(entry.isDirectory ? '${entry.location.path}/' : entry.location.path);
  }

  Future<void> createFolder({required Uri parentDir, required String name}) async {
    final client = _requireClient(parentDir);
    final path = parentDir.path.isEmpty ? '/' : parentDir.path;
    await client.mkdir('$path/$name');
  }

  Future<void> rename({required Uri location, required String newName}) async {
    final client = _requireClient(location);
    final dir = p.posix.dirname(location.path);
    await client.rename(location.path, '$dir/$newName', false);
  }

  Future<String> _availableRemoteName(webdav.Client client, String dir, String name) async {
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    var i = 2;
    String candidate;
    do {
      candidate = '$base ($i)$ext';
      i++;
    } while (await _statOrNull(client, '$dir/$candidate') != null);
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
