import 'package:webdav_client/webdav_client.dart' as webdav;

import '../../domain/entities/file_entry.dart';
import '../webdav_session_manager.dart';

String joinWebdavPath(String base, String name) {
  if (base.isEmpty || base == '/') return '/$name';
  return base.endsWith('/') ? '$base$name' : '$base/$name';
}

/// [directory](webdav:// 또는 webdavs:// URI)에 대응하는 이미 연결된 세션을
/// 찾아 목록을 읽는다. 연결이 없으면 예외를 던진다 — [ListFtpDirectory]와
/// 같은 패턴.
class ListWebdavDirectory {
  const ListWebdavDirectory(this._sessions);

  final WebdavSessionManager _sessions;

  Future<List<FileEntry>> call(Uri directory) async {
    final client = _sessions.clientForUri(directory);
    if (client == null) {
      throw StateError('연결된 WebDAV 세션이 없습니다. 먼저 WebDAV 서버에 연결하세요.');
    }
    final remotePath = directory.path.isEmpty ? '/' : directory.path;
    final files = await client.readDir(remotePath);
    return files
        .where((f) => f.name != null && f.name!.isNotEmpty)
        .map((f) => _toFileEntry(f, directory))
        .toList();
  }

  FileEntry _toFileEntry(webdav.File webdavFile, Uri baseDir) {
    final name = webdavFile.name!;
    final isDir = webdavFile.isDir ?? false;
    final childPath = joinWebdavPath(baseDir.path, name);
    return FileEntry(
      location: baseDir.replace(path: childPath),
      name: name,
      isDirectory: isDir,
      sizeBytes: isDir ? null : webdavFile.size,
      modifiedAt: webdavFile.mTime,
      isHidden: name.startsWith('.'),
      source: FileSourceType.webdav,
    );
  }
}
