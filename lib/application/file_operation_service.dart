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

    /// 대상 경로에 이미 무언가 있으면 사용자에게 물어 최종 대상 경로를
    /// 돌려준다. 건너뛰기면 null. 덮어쓰기면 대상 경로를 그대로 돌려주고,
    /// 폴더를 덮어쓸 때 기존 항목을 지우는 건 호출부 몫이다.
    Future<String?> resolveConflict(
      FileSystemEntity src,
      String destPath, {
      required bool isDirectory,
    }) async {
      final destType = await FileSystemEntity.type(destPath, followLinks: false);
      if (destType == FileSystemEntityType.notFound) return destPath;
      final srcStat = await src.stat();
      final destStat = await FileStat.stat(destPath);
      final action = bulkAction ??
          await onConflict(FileConflict(
            sourcePath: src.path,
            destinationPath: destPath,
            sourceSizeBytes: isDirectory ? null : srcStat.size,
            destinationSizeBytes:
                destType == FileSystemEntityType.file ? destStat.size : null,
            sourceModifiedAt: srcStat.modified,
            destinationModifiedAt: destStat.modified,
            isDirectory: isDirectory,
          ));
      if (action == ConflictAction.overwriteAll) bulkAction = ConflictAction.overwrite;
      if (action == ConflictAction.skipAll) bulkAction = ConflictAction.skip;
      if (action == ConflictAction.cancel) {
        throw const OperationCancelledException();
      }
      final effective = bulkAction ?? action;
      if (effective == ConflictAction.skip) return null;
      if (effective == ConflictAction.rename) {
        return _availableName(destPath, isDirectory: isDirectory);
      }
      return destPath;
    }

    Future<void> handleFile(File srcFile, String destPath) async {
      cancelToken?.throwIfCancelled();
      final finalDestPath = await resolveConflict(srcFile, destPath, isDirectory: false);
      if (finalDestPath == null) {
        reportFile(p.basename(srcFile.path));
        return;
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
      var destPath = p.join(destinationDir, entry.name);

      // 폴더는 최상위에서 한 번만 묻는다 — 덮어쓰기는 기존 폴더를 통째로
      // 교체하고, 이름 바꾸기는 "폴더 2"로 새로 만든다. 기존 폴더 안에
      // 내용을 병합하면서 파일마다 묻지 않는다.
      if (entry.isDirectory) {
        final resolved =
            await resolveConflict(Directory(srcPath), destPath, isDirectory: true);
        if (resolved == null) {
          done += await _countFiles([entry]);
          onProgress?.call(
            FileOperationProgress(done: done, total: total, currentName: entry.name),
          );
          continue;
        }
        if (resolved == destPath) await _removeExisting(destPath, protect: srcPath);
        destPath = resolved;
      }

      // 개수는 rename 전에 센다 — rename 후에는 원본 경로가 사라진다.
      final entryFileCount = deleteSourceAfter ? await _countFiles([entry]) : 0;
      if (deleteSourceAfter && await _tryFastRename(srcPath, destPath)) {
        done += entryFileCount;
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

  /// 폴더 덮어쓰기 전에 대상에 있던 항목을 지운다. 복사할 원본이 그 안에
  /// 들어 있으면 원본까지 지워지므로 거부한다.
  Future<void> _removeExisting(String destPath, {required String protect}) async {
    if (await FileSystemEntity.type(destPath, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return;
    }
    if (p.equals(destPath, protect) || p.isWithin(destPath, protect)) {
      throw StateError('원본이 들어 있는 폴더는 덮어쓸 수 없습니다.');
    }
    if (await FileSystemEntity.isDirectory(destPath)) {
      await Directory(destPath).delete(recursive: true);
    } else {
      await File(destPath).delete();
    }
  }

  /// 충돌 시 "이름 바꿔서 복사"에 쓸 빈 이름을 찾는다. macOS는 Finder와 같은
  /// "이름 2.ext", 그 외는 "이름 (2).ext". 폴더는 확장자를 나누지 않는다.
  Future<String> _availableName(String path, {required bool isDirectory}) async {
    final dir = p.dirname(path);
    final ext = isDirectory ? '' : p.extension(path);
    final base = isDirectory ? p.basename(path) : p.basenameWithoutExtension(path);
    var i = 2;
    String candidate;
    do {
      final suffix = Platform.isMacOS ? ' $i' : ' ($i)';
      candidate = p.join(dir, '$base$suffix$ext');
      i++;
    } while (await FileSystemEntity.type(candidate, followLinks: false) !=
        FileSystemEntityType.notFound);
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
