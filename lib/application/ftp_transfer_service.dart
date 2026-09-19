import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;

import '../domain/entities/file_conflict.dart';
import '../domain/entities/file_entry.dart';
import 'cancel_token.dart';
import 'file_operation_service.dart';
import 'ftp_session_manager.dart';

/// 로컬↔FTP, FTP↔FTP 전송. 개별 파일은 충돌 확인(스킵/덮어쓰기/이름변경/모두
/// 적용)을 지원하지만, 폴더 전체 업로드/다운로드는 `ftpconnect` 패키지의
/// 재귀 헬퍼에 위임해 폴더 내부 개별 충돌 확인은 지원하지 않는다 — 폴더
/// 통째 전송 시 이미 있는 항목은 그냥 덮어써진다 (PLAN.md P2, 스코프 축소 명시).
class FtpTransferService {
  const FtpTransferService(this._sessions);

  final FtpSessionManager _sessions;

  FTPConnect _requireClient(Uri ftpUri) {
    final client = _sessions.clientForUri(ftpUri);
    if (client == null) {
      throw StateError('연결된 FTP 세션이 없습니다. 먼저 FTP 서버에 연결하세요.');
    }
    return client;
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
      await client.changeDirectory(destPath);
      final localPath = entry.location.toFilePath();

      if (entry.isDirectory) {
        await client.uploadDirectory(Directory(localPath), entry.name);
      } else {
        final file = File(localPath);
        var remoteName = entry.name;
        if (await client.existFile(remoteName)) {
          final action = bulkAction ??
              await onConflict(FileConflict(
                sourcePath: localPath,
                destinationPath: '$destPath/$remoteName',
                sourceSizeBytes: await file.length(),
                destinationSizeBytes: await client.sizeFile(remoteName),
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
            remoteName = await _availableRemoteName(client, remoteName);
          }
        }
        final ok = await client.uploadFile(file, sRemoteName: remoteName);
        if (!ok) throw StateError('업로드 실패: ${entry.name}');
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
      final remoteDir = p.posix.dirname(entry.location.path);
      await client.changeDirectory(remoteDir.isEmpty ? '/' : remoteDir);
      var localPath = p.join(destinationDir, entry.name);

      if (entry.isDirectory) {
        await client.downloadDirectory(entry.name, Directory(localPath));
      } else {
        final localFile = File(localPath);
        if (await localFile.exists()) {
          final action = bulkAction ??
              await onConflict(FileConflict(
                sourcePath: entry.location.path,
                destinationPath: localPath,
                sourceSizeBytes: entry.sizeBytes,
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
        final ok = await client.downloadFile(entry.name, File(localPath));
        if (!ok) throw StateError('다운로드 실패: ${entry.name}');
      }

      if (deleteSourceAfter) {
        if (entry.isDirectory) {
          await client.deleteNonEmptyDirectory(entry.name);
        } else {
          await client.deleteFile(entry.name);
        }
      }
      done++;
      onProgress?.call(FileOperationProgress(done: done, total: total, currentName: entry.name));
    }
  }

  /// 서로 다른(혹은 같은) FTP 세션 간 전송 — 로컬 임시 폴더를 경유한다.
  /// (FTP 표준에는 서버간 직접 복사 명령이 없다.)
  Future<void> transferBetweenFtpSessions({
    required List<FileEntry> sources,
    required Uri destinationDir,
    required bool deleteSourceAfter,
    required ConflictResolver onConflict,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (sources.isEmpty) return;
    final tempDir = await Directory.systemTemp.createTemp('daylight_commander_ftp_');
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
          final remoteDir = p.posix.dirname(entry.location.path);
          await srcClient.changeDirectory(remoteDir.isEmpty ? '/' : remoteDir);
          if (entry.isDirectory) {
            await srcClient.deleteNonEmptyDirectory(entry.name);
          } else {
            await srcClient.deleteFile(entry.name);
          }
        }
      }
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> deleteEntry(FileEntry entry) async {
    final client = _requireClient(entry.location);
    final remoteDir = p.posix.dirname(entry.location.path);
    await client.changeDirectory(remoteDir.isEmpty ? '/' : remoteDir);
    final ok = entry.isDirectory
        ? await client.deleteNonEmptyDirectory(entry.name)
        : await client.deleteFile(entry.name);
    if (!ok) throw StateError('삭제 실패: ${entry.name}');
  }

  Future<void> createFolder({required Uri parentDir, required String name}) async {
    final client = _requireClient(parentDir);
    final path = parentDir.path.isEmpty ? '/' : parentDir.path;
    await client.changeDirectory(path);
    final ok = await client.makeDirectory(name);
    if (!ok) throw StateError('폴더 생성 실패: $name');
  }

  Future<void> rename({required Uri location, required String newName}) async {
    final client = _requireClient(location);
    final dir = p.posix.dirname(location.path);
    await client.changeDirectory(dir.isEmpty ? '/' : dir);
    final oldName = p.posix.basename(location.path);
    final ok = await client.rename(oldName, newName);
    if (!ok) throw StateError('이름 변경 실패: $oldName → $newName');
  }

  Future<String> _availableRemoteName(FTPConnect client, String name) async {
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    var i = 2;
    String candidate;
    do {
      candidate = '$base ($i)$ext';
      i++;
    } while (await client.existFile(candidate));
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
