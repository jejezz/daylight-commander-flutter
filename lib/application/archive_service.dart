import 'dart:io';

import 'package:archive/archive_io.dart';

import '../domain/entities/file_entry.dart';

/// 압축/압축 해제. zip 우선 지원 (PLAN.md P1).
class ArchiveService {
  const ArchiveService();

  Future<void> compressToZip({
    required List<FileEntry> sources,
    required String zipPath,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    for (final entry in sources) {
      final path = entry.location.toFilePath();
      if (entry.isDirectory) {
        await encoder.addDirectory(Directory(path), includeDirName: true);
      } else {
        await encoder.addFile(File(path));
      }
    }
    await encoder.close();
  }

  Future<void> extractZip({
    required String zipPath,
    required String destinationDir,
  }) async {
    await extractFileToDisk(zipPath, destinationDir);
  }
}
