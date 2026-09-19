import 'package:ftpconnect/ftpconnect.dart';

import '../../domain/entities/file_entry.dart';
import '../ftp_session_manager.dart';

String joinFtpPath(String base, String name) {
  if (base.isEmpty || base == '/') return '/$name';
  return base.endsWith('/') ? '$base$name' : '$base/$name';
}

/// [directory](ftp:// URI)에 대응하는 이미 연결된 세션을 찾아 목록을 읽는다.
/// 연결이 없으면 예외를 던진다 — 호출부(PaneController)가 그대로 상태의
/// error로 흘려보내 "먼저 연결하세요" 메시지로 보여준다.
class ListFtpDirectory {
  const ListFtpDirectory(this._sessions);

  final FtpSessionManager _sessions;

  Future<List<FileEntry>> call(Uri directory) async {
    final client = _sessions.clientForUri(directory);
    if (client == null) {
      throw StateError('연결된 FTP 세션이 없습니다. 먼저 FTP 서버에 연결하세요.');
    }
    final remotePath = directory.path.isEmpty ? '/' : directory.path;
    final entries = await client.listDirectoryContent(remotePath);
    return entries
        .where((e) => e.name != '.' && e.name != '..' && e.name.isNotEmpty)
        .map((e) => _toFileEntry(e, directory))
        .toList();
  }

  FileEntry _toFileEntry(FTPEntry entry, Uri baseDir) {
    final childPath = joinFtpPath(baseDir.path, entry.name);
    return FileEntry(
      location: baseDir.replace(path: childPath),
      name: entry.name,
      isDirectory: entry.type == FTPEntryType.dir,
      sizeBytes: entry.type == FTPEntryType.file ? entry.size : null,
      modifiedAt: entry.modifyTime,
      isHidden: entry.name.startsWith('.'),
      source: FileSourceType.ftp,
    );
  }
}
