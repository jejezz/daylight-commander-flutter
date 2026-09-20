import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/entities/file_conflict.dart';
import '../domain/entities/file_entry.dart';
import 'cancel_token.dart';

class FileOperationProgress {
  const FileOperationProgress({
    required this.done,
    required this.total,
    required this.currentName,
  });

  final int done;
  final int total;
  final String currentName;
}

typedef ConflictResolver = Future<ConflictAction> Function(FileConflict conflict);
typedef ProgressCallback = void Function(FileOperationProgress progress);

/// 복사/이동/삭제/새 폴더/이름변경을 수행한다.
///
/// 로컬 파일시스템만 지원하는 현재 단계에서는 `dart:io`를 직접 사용해 순차
/// 실행한다 (Isolate 오프로딩은 ARCHITECTURE.md 5장의 향후 최적화 항목).
class FileOperationService {
  const FileOperationService();

  Future<void> copy({
    required List<FileEntry> sources,
    required String destinationDir,
    required ConflictResolver onConflict,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) =>
      _transfer(
        sources: sources,
        destinationDir: destinationDir,
        onConflict: onConflict,
        onProgress: onProgress,
        cancelToken: cancelToken,
        deleteSourceAfter: false,
      );

  Future<void> move({
    required List<FileEntry> sources,
    required String destinationDir,
    required ConflictResolver onConflict,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) =>
      _transfer(
        sources: sources,
        destinationDir: destinationDir,
        onConflict: onConflict,
        onProgress: onProgress,
        cancelToken: cancelToken,
        deleteSourceAfter: true,
      );

  Future<void> _transfer({
    required List<FileEntry> sources,
    required String destinationDir,
    required ConflictResolver onConflict,
    required bool deleteSourceAfter,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final total = await _countFiles(sources);
    var done = 0;
    ConflictAction? bulkAction;

    void reportFile(String name) {
      done++;
      onProgress?.call(
        FileOperationProgress(done: done, total: total, currentName: name),
      );
    }

    Future<void> handleFile(File srcFile, String destPath) async {
      cancelToken?.throwIfCancelled();
      final destFile = File(destPath);
      var finalDestPath = destPath;
      if (await destFile.exists()) {
        final action = bulkAction ??
            await onConflict(FileConflict(
              sourcePath: srcFile.path,
              destinationPath: destPath,
              sourceSizeBytes: await srcFile.length(),
              destinationSizeBytes: await destFile.length(),
              sourceModifiedAt: (await srcFile.stat()).modified,
              destinationModifiedAt: (await destFile.stat()).modified,
            ));
        if (action == ConflictAction.overwriteAll) bulkAction = ConflictAction.overwrite;
        if (action == ConflictAction.skipAll) bulkAction = ConflictAction.skip;
        if (action == ConflictAction.cancel) {
          throw const OperationCancelledException();
        }
        final effective = bulkAction ?? action;
        if (effective == ConflictAction.skip) {
          reportFile(p.basename(srcFile.path));
          return;
        } else if (effective == ConflictAction.rename) {
          finalDestPath = await _availableName(destPath);
        }
      }
      await srcFile.copy(finalDestPath);
      if (deleteSourceAfter) await srcFile.delete();
      reportFile(p.basename(srcFile.path));
    }

    Future<void> handleDirectory(Directory srcDir, String destPath) async {
      cancelToken?.throwIfCancelled();
      final destDir = Directory(destPath);
      if (!await destDir.exists()) await destDir.create(recursive: true);
      await for (final entity in srcDir.list(followLinks: false)) {
        cancelToken?.throwIfCancelled();
        final childDest = p.join(destPath, p.basename(entity.path));
        if (entity is Directory) {
          await handleDirectory(entity, childDest);
        } else if (entity is File) {
          await handleFile(entity, childDest);
        }
      }
      if (deleteSourceAfter) {
        try {
          await srcDir.delete();
        } catch (_) {
          // 건너뛴 항목이 남아있어 비어있지 않으면 삭제하지 않는다.
        }
      }
    }

    for (final entry in sources) {
      cancelToken?.throwIfCancelled();
      final srcPath = entry.location.toFilePath();
      final destPath = p.join(destinationDir, entry.name);

      if (deleteSourceAfter && await _tryFastRename(srcPath, destPath)) {
        done += await _countFiles([entry]);
        onProgress?.call(
          FileOperationProgress(done: done, total: total, currentName: entry.name),
        );
        continue;
      }

      if (entry.isDirectory) {
        await handleDirectory(Directory(srcPath), destPath);
      } else {
        await handleFile(File(srcPath), destPath);
      }
    }
  }

  Future<void> delete({
    required List<FileEntry> entries,
    required bool toTrash,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final total = entries.length;
    var done = 0;
    for (final entry in entries) {
      cancelToken?.throwIfCancelled();
      final path = entry.location.toFilePath();
      if (!(toTrash && await _moveToTrash(path))) {
        if (entry.isDirectory) {
          await Directory(path).delete(recursive: true);
        } else {
          await File(path).delete();
        }
      }
      done++;
      onProgress?.call(FileOperationProgress(done: done, total: total, currentName: entry.name));
    }
  }

  Future<void> createFolder({required String parentDir, required String name}) async {
    final dir = Directory(p.join(parentDir, name));
    if (await dir.exists()) {
      throw StateError('이미 같은 이름의 폴더가 있습니다.');
    }
    await dir.create();
  }

  Future<void> createFile({required String parentDir, required String name}) async {
    final file = File(p.join(parentDir, name));
    if (await file.exists()) {
      throw StateError('이미 같은 이름의 파일이 있습니다.');
    }
    await file.create();
  }

  Future<void> rename({required String path, required String newName}) async {
    final newPath = p.join(p.dirname(path), newName);
    if (await FileSystemEntity.type(newPath) != FileSystemEntityType.notFound) {
      throw StateError('이미 같은 이름이 있습니다.');
    }
    final isDir = await FileSystemEntity.isDirectory(path);
    if (isDir) {
      await Directory(path).rename(newPath);
    } else {
      await File(path).rename(newPath);
    }
  }

  Future<bool> _tryFastRename(String srcPath, String destPath) async {
    if (await FileSystemEntity.type(destPath) != FileSystemEntityType.notFound) {
      return false;
    }
    try {
      if (await FileSystemEntity.isDirectory(srcPath)) {
        await Directory(srcPath).rename(destPath);
      } else {
        await File(srcPath).rename(destPath);
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<String> _availableName(String path) async {
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

  Future<int> _countFiles(List<FileEntry> entries) async {
    var count = 0;
    for (final entry in entries) {
      final path = entry.location.toFilePath();
      if (entry.isDirectory) {
        await for (final entity in Directory(path).list(recursive: true, followLinks: false)) {
          if (entity is File) count++;
        }
      } else {
        count++;
      }
    }
    return count == 0 ? 1 : count;
  }

  /// OS 휴지통으로 이동을 시도한다 (best-effort, 쉘 명령 위임).
  /// 실패하면 false를 반환해 호출부가 영구 삭제로 폴백할 수 있게 한다.
  Future<bool> _moveToTrash(String path) async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('trash', [path]);
        if (result.exitCode == 0) return true;
        final osa = await Process.run('osascript', [
          '-e',
          'tell application "Finder" to delete POSIX file "$path"',
        ]);
        return osa.exitCode == 0;
      }
      if (Platform.isLinux) {
        try {
          final gio = await Process.run('gio', ['trash', path]);
          if (gio.exitCode == 0) return true;
        } on ProcessException {
          // gio 없음 — 다음 후보로.
        }
        try {
          final trashPut = await Process.run('trash-put', [path]);
          if (trashPut.exitCode == 0) return true;
        } on ProcessException {
          // trash-cli도 없음.
        }
        return false;
      }
      if (Platform.isWindows) {
        final isDir = await FileSystemEntity.isDirectory(path);
        final method = isDir ? 'DeleteDirectory' : 'DeleteFile';
        final psPath = path.replaceAll("'", "''");
        final script = "Add-Type -AssemblyName Microsoft.VisualBasic; "
            "[Microsoft.VisualBasic.FileIO.FileSystem]::$method('$psPath', "
            "'OnlyErrorDialogs', 'SendToRecycleBin')";
        final result = await Process.run('powershell', ['-NoProfile', '-Command', script]);
        return result.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
    return false;
  }
}
