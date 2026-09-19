import 'package:dartssh2/dartssh2.dart';

import '../../domain/entities/file_entry.dart';
import '../sftp_session_manager.dart';

String joinSftpPath(String base, String name) {
  if (base.isEmpty || base == '/') return '/$name';
  return base.endsWith('/') ? '$base$name' : '$base/$name';
}

/// [directory](sftp:// URI)에 대응하는 이미 연결된 세션을 찾아 목록을 읽는다.
/// 연결이 없으면 예외를 던진다 — [ListFtpDirectory]와 같은 패턴.
class ListSftpDirectory {
  const ListSftpDirectory(this._sessions);

  final SftpSessionManager _sessions;

  Future<List<FileEntry>> call(Uri directory) async {
    final client = _sessions.clientForUri(directory);
    if (client == null) {
      throw StateError('연결된 SFTP 세션이 없습니다. 먼저 SFTP 서버에 연결하세요.');
    }
    final remotePath = directory.path.isEmpty ? '/' : directory.path;
    final names = await client.listdir(remotePath);
    return names
        .where((e) => e.filename != '.' && e.filename != '..' && e.filename.isNotEmpty)
        .map((e) => _toFileEntry(e, directory))
        .toList();
  }

  FileEntry _toFileEntry(SftpName sftpName, Uri baseDir) {
    final childPath = joinSftpPath(baseDir.path, sftpName.filename);
    final attr = sftpName.attr;
    final modifyTime = attr.modifyTime;
    return FileEntry(
      location: baseDir.replace(path: childPath),
      name: sftpName.filename,
      isDirectory: attr.isDirectory,
      sizeBytes: attr.isDirectory ? null : attr.size,
      modifiedAt: modifyTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(modifyTime * 1000),
      isHidden: sftpName.filename.startsWith('.'),
      source: FileSourceType.sftp,
    );
  }
}
