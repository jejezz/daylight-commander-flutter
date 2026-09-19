import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/file_entry.dart';

/// 임의의 로컬 경로 하나를 [FileEntry]로 만든다. OS(Finder/탐색기)에서 드래그해
/// 앱으로 드롭한 파일처럼, 우리 패널이 목록으로 갖고 있지 않은 경로를 다뤄야
/// 할 때 쓴다 (일반 디렉터리 목록은 `ListLocalDirectory`를 그대로 쓴다).
Future<FileEntry> localFileEntryFor(String path) async {
  final stat = await FileStat.stat(path);
  final isDirectory = stat.type == FileSystemEntityType.directory;
  final name = p.basename(path);
  return FileEntry(
    location: Uri.file(path),
    name: name,
    isDirectory: isDirectory,
    sizeBytes: isDirectory ? null : stat.size,
    modifiedAt: stat.modified,
    isHidden: name.startsWith('.'),
  );
}
