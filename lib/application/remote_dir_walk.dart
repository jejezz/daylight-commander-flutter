import 'dart:io';

import 'package:path/path.dart' as p;

/// SFTP/WebDAV 원격 디렉터리 항목 하나 (재귀 전송에만 쓰는 최소 정보).
class RemoteDirEntry {
  const RemoteDirEntry({required this.name, required this.isDirectory});

  final String name;
  final bool isDirectory;
}

/// 로컬 폴더를 재귀적으로 원격에 올린다. `ftpconnect`와 달리 dartssh2/
/// webdav_client에는 폴더 통째 업로드 헬퍼가 없어서 직접 순회한다. FTP처럼
/// 폴더 내부 개별 충돌 확인은 하지 않고 있으면 덮어쓴다 (PLAN.md 스코프 축소).
Future<void> uploadDirectoryRecursive({
  required Directory localDir,
  required String remoteDirPath,
  required Future<void> Function(String path) mkdirRemote,
  required Future<void> Function(File localFile, String remotePath) uploadFile,
}) async {
  await mkdirRemote(remoteDirPath);
  await for (final entity in localDir.list()) {
    final name = p.basename(entity.path);
    final childRemotePath = '$remoteDirPath/$name';
    if (entity is Directory) {
      await uploadDirectoryRecursive(
        localDir: entity,
        remoteDirPath: childRemotePath,
        mkdirRemote: mkdirRemote,
        uploadFile: uploadFile,
      );
    } else if (entity is File) {
      await uploadFile(entity, childRemotePath);
    }
  }
}

/// 원격 폴더를 재귀적으로 로컬에 내려받는다. 업로드와 대칭.
Future<void> downloadDirectoryRecursive({
  required String remoteDirPath,
  required Directory localDir,
  required Future<List<RemoteDirEntry>> Function(String path) listRemote,
  required Future<void> Function(String remotePath, File localFile) downloadFile,
}) async {
  await localDir.create(recursive: true);
  final entries = await listRemote(remoteDirPath);
  for (final entry in entries) {
    final childRemotePath = '$remoteDirPath/${entry.name}';
    final localPath = p.join(localDir.path, entry.name);
    if (entry.isDirectory) {
      await downloadDirectoryRecursive(
        remoteDirPath: childRemotePath,
        localDir: Directory(localPath),
        listRemote: listRemote,
        downloadFile: downloadFile,
      );
    } else {
      await downloadFile(childRemotePath, File(localPath));
    }
  }
}

/// 원격 폴더를 재귀적으로 삭제한다 (SFTP/WebDAV 모두 빈 폴더만 지울 수
/// 있어서 아래부터 위로 지워야 한다).
Future<void> deleteDirectoryRecursive({
  required String remoteDirPath,
  required Future<List<RemoteDirEntry>> Function(String path) listRemote,
  required Future<void> Function(String path) deleteFile,
  required Future<void> Function(String path) deleteEmptyDir,
}) async {
  final entries = await listRemote(remoteDirPath);
  for (final entry in entries) {
    final childPath = '$remoteDirPath/${entry.name}';
    if (entry.isDirectory) {
      await deleteDirectoryRecursive(
        remoteDirPath: childPath,
        listRemote: listRemote,
        deleteFile: deleteFile,
        deleteEmptyDir: deleteEmptyDir,
      );
    } else {
      await deleteFile(childPath);
    }
  }
  await deleteEmptyDir(remoteDirPath);
}
