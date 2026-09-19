import 'dart:io';

import 'package:archive/archive_io.dart';

import '../domain/entities/file_entry.dart';

/// zip 내부 항목 하나(디렉터리 포함)의 메타데이터. [listZipEntries]가 돌려준다.
class ArchiveEntry {
  const ArchiveEntry({
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modifiedAt,
  });

  /// zip 안에서의 전체 경로 (슬래시 구분, 디렉터리 표시 슬래시는 없음).
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime? modifiedAt;
}

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

  /// zip 전체를 디스크에 풀지 않고 중앙 디렉터리만 읽어 내부 항목 목록을
  /// 돌려준다 (PLAN.md P2 — "압축파일 내부 미리보기"). [InputFileStream]을
  /// 쓰므로 파일 내용은 지연 로드되어 큰 zip도 목록만 볼 때는 가볍다.
  Future<List<ArchiveEntry>> listZipEntries(String zipPath) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      return [
        for (final file in archive.files)
          ArchiveEntry(
            name: file.name,
            isDirectory: file.isDirectory,
            size: file.size,
            modifiedAt: file.isDirectory ? null : file.lastModDateTime,
          ),
      ];
    } finally {
      await input.close();
    }
  }

  /// zip 안의 파일 하나만 [destinationPath]로 꺼낸다 (미리보기에서 열람할 때
  /// 임시 파일로 씀 — zip 전체는 풀지 않는다).
  Future<void> extractZipEntry({
    required String zipPath,
    required String entryName,
    required String destinationPath,
  }) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final target = archive.files.firstWhere((f) => f.name == entryName && f.isFile);
      final bytes = target.readBytes();
      if (bytes == null) return;
      // 이미 메모리에 있는 바이트를 쓰는 것뿐이라 동기 쓰기로 충분하다.
      File(destinationPath).writeAsBytesSync(bytes);
    } finally {
      await input.close();
    }
  }
}
