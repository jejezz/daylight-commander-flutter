import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/file_entry.dart';

/// 로컬 디렉터리 목록을 읽어 [FileEntry] 리스트로 변환한다.
///
/// SMB/FTP 지원이 추가되면 이 유스케이스는 FileSystemRepository 인터페이스
/// (ARCHITECTURE.md 4장) 뒤로 이동한다. 로컬 전용인 지금은 dart:io를 직접 사용해
/// 불필요한 추상화를 피한다.
class ListLocalDirectory {
  const ListLocalDirectory();

  Future<List<FileEntry>> call(String directoryPath) async {
    final dir = Directory(directoryPath);
    final entries = <FileEntry>[];
    await for (final entity in dir.list(followLinks: false)) {
      final FileStat stat;
      try {
        stat = await entity.stat();
      } on FileSystemException {
        continue;
      }
      final name = p.basename(entity.path);
      entries.add(FileEntry(
        location: Uri.file(entity.path),
        name: name,
        isDirectory: entity is Directory,
        sizeBytes: entity is File ? stat.size : null,
        modifiedAt: stat.modified,
        isHidden: name.startsWith('.'),
      ));
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }
}
