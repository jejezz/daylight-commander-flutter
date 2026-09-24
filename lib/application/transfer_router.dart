import 'dart:io';

import 'package:path/path.dart' as p;

import 'cancel_token.dart';
import 'file_operation_service.dart';
import 'ftp_session_manager.dart';
import 'ftp_transfer_service.dart';
import 'sftp_session_manager.dart';
import 'sftp_transfer_service.dart';
import 'webdav_session_manager.dart';
import 'webdav_transfer_service.dart';
import '../domain/entities/file_conflict.dart';
import '../domain/entities/file_entry.dart';

const _localOps = FileOperationService();

bool _isWebdavScheme(String scheme) => scheme == 'webdav' || scheme == 'webdavs';

/// 소스/목적지의 URI 스킴을 보고 로컬-로컬(dart:io 그대로), 업로드, 다운로드,
/// 같은 프로토콜의 세션간 전송, 서로 다른 프로토콜간 전송(로컬 임시 폴더
/// 경유) 중 알맞은 경로로 보낸다 (ARCHITECTURE.md 4장의 FileSystemRepository
/// 승격 지점 — 로컬은 그대로, 원격 스킴이 늘어날 때마다 분기만 추가).
Future<void> performTransfer({
  required List<FileEntry> sources,
  required Uri destinationDir,
  required bool isMove,
  required ConflictResolver onConflict,
  required FtpSessionManager ftpSessions,
  required SftpSessionManager sftpSessions,
  required WebdavSessionManager webdavSessions,
  ProgressCallback? onProgress,
  CancelToken? cancelToken,
}) async {
  if (sources.isEmpty) return;

  final destScheme = destinationDir.scheme;
  final srcScheme = sources.first.location.scheme;
  final sameSrcScheme = sources.every((e) => e.location.scheme == srcScheme);
  if (!sameSrcScheme) {
    throw UnsupportedError('여러 스킴이 섞인 항목은 한 번에 옮길 수 없습니다.');
  }

  final ftpTransfer = FtpTransferService(ftpSessions);
  final sftpTransfer = SftpTransferService(sftpSessions);
  final webdavTransfer = WebdavTransferService(webdavSessions);

  if (destScheme == 'file' && srcScheme == 'file') {
    if (isMove) {
      await _localOps.move(
        sources: sources,
        destinationDir: destinationDir.toFilePath(),
        onConflict: onConflict,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } else {
      await _localOps.copy(
        sources: sources,
        destinationDir: destinationDir.toFilePath(),
        onConflict: onConflict,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
    return;
  }

  if (destScheme == 'file' && srcScheme == 'ftp') {
    return ftpTransfer.download(
      sources: sources,
      destinationDir: destinationDir.toFilePath(),
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  if (destScheme == 'file' && srcScheme == 'sftp') {
    return sftpTransfer.download(
      sources: sources,
      destinationDir: destinationDir.toFilePath(),
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  if (destScheme == 'file' && _isWebdavScheme(srcScheme)) {
    return webdavTransfer.download(
      sources: sources,
      destinationDir: destinationDir.toFilePath(),
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  if (destScheme == 'ftp' && srcScheme == 'file') {
    return ftpTransfer.upload(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  if (destScheme == 'sftp' && srcScheme == 'file') {
    return sftpTransfer.upload(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  if (_isWebdavScheme(destScheme) && srcScheme == 'file') {
    return webdavTransfer.upload(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  if (destScheme == 'ftp' && srcScheme == 'ftp') {
    return ftpTransfer.transferBetweenFtpSessions(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  if (destScheme == 'sftp' && srcScheme == 'sftp') {
    return sftpTransfer.transferBetweenSftpSessions(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  if (_isWebdavScheme(destScheme) && _isWebdavScheme(srcScheme)) {
    return webdavTransfer.transferBetweenWebdavSessions(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  final srcIsRemote = srcScheme != 'file';
  final destIsRemote = destScheme != 'file';
  if (srcIsRemote && destIsRemote) {
    // 서로 다른 원격 프로토콜간 전송(예: FTP → SFTP) — 표준 전송 명령이 있을
    // 리 없으니 로컬 임시 폴더를 경유한다. 같은 프로토콜의 세션간 전송과
    // 원리는 같지만 스킴이 다르므로 위의 전용 분기들을 못 타서 여기로 온다.
    return _crossProtocolTransfer(
      sources: sources,
      destinationDir: destinationDir,
      isMove: isMove,
      onConflict: onConflict,
      ftpTransfer: ftpTransfer,
      sftpTransfer: sftpTransfer,
      webdavTransfer: webdavTransfer,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  throw UnsupportedError('로컬과 원격이 섞인 항목은 한 번에 옮길 수 없습니다.');
}

Future<void> _downloadToLocal({
  required List<FileEntry> sources,
  required String destinationDir,
  required FtpTransferService ftpTransfer,
  required SftpTransferService sftpTransfer,
  required WebdavTransferService webdavTransfer,
  required ConflictResolver onConflict,
  CancelToken? cancelToken,
}) {
  final scheme = sources.first.location.scheme;
  if (scheme == 'ftp') {
    return ftpTransfer.download(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: false,
      onConflict: onConflict,
      cancelToken: cancelToken,
    );
  }
  if (scheme == 'sftp') {
    return sftpTransfer.download(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: false,
      onConflict: onConflict,
      cancelToken: cancelToken,
    );
  }
  return webdavTransfer.download(
    sources: sources,
    destinationDir: destinationDir,
    deleteSourceAfter: false,
    onConflict: onConflict,
    cancelToken: cancelToken,
  );
}

Future<void> _uploadFromLocal({
  required List<FileEntry> sources,
  required Uri destinationDir,
  required FtpTransferService ftpTransfer,
  required SftpTransferService sftpTransfer,
  required WebdavTransferService webdavTransfer,
  required ConflictResolver onConflict,
  ProgressCallback? onProgress,
  CancelToken? cancelToken,
}) {
  final scheme = destinationDir.scheme;
  if (scheme == 'ftp') {
    return ftpTransfer.upload(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: false,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  if (scheme == 'sftp') {
    return sftpTransfer.upload(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: false,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  return webdavTransfer.upload(
    sources: sources,
    destinationDir: destinationDir,
    deleteSourceAfter: false,
    onConflict: onConflict,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );
}

Future<void> _deleteRemoteEntry({
  required FileEntry entry,
  required FtpTransferService ftpTransfer,
  required SftpTransferService sftpTransfer,
  required WebdavTransferService webdavTransfer,
}) {
  final scheme = entry.location.scheme;
  if (scheme == 'ftp') return ftpTransfer.deleteEntry(entry);
  if (scheme == 'sftp') return sftpTransfer.deleteEntry(entry);
  return webdavTransfer.deleteEntry(entry);
}

Future<void> _crossProtocolTransfer({
  required List<FileEntry> sources,
  required Uri destinationDir,
  required bool isMove,
  required ConflictResolver onConflict,
  required FtpTransferService ftpTransfer,
  required SftpTransferService sftpTransfer,
  required WebdavTransferService webdavTransfer,
  ProgressCallback? onProgress,
  CancelToken? cancelToken,
}) async {
  final tempDir = await Directory.systemTemp.createTemp('daylight_commander_xfer_');
  try {
    await _downloadToLocal(
      sources: sources,
      destinationDir: tempDir.path,
      ftpTransfer: ftpTransfer,
      sftpTransfer: sftpTransfer,
      webdavTransfer: webdavTransfer,
      onConflict: onConflict,
      cancelToken: cancelToken,
    );
    final tempEntries = [
      for (final entry in sources)
        FileEntry(
          location: Uri.file(p.join(tempDir.path, entry.name)),
          name: entry.name,
          isDirectory: entry.isDirectory,
        ),
    ];
    await _uploadFromLocal(
      sources: tempEntries,
      destinationDir: destinationDir,
      ftpTransfer: ftpTransfer,
      sftpTransfer: sftpTransfer,
      webdavTransfer: webdavTransfer,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (isMove) {
      for (final entry in sources) {
        await _deleteRemoteEntry(
          entry: entry,
          ftpTransfer: ftpTransfer,
          sftpTransfer: sftpTransfer,
          webdavTransfer: webdavTransfer,
        );
      }
    }
  } finally {
    await tempDir.delete(recursive: true);
  }
}

/// 원격 항목(파일/폴더) 하나를 정확히 [targetPath]로 내려받는다 — 앱 밖으로
/// 끌어낸 원격 항목의 파일 프로미스(드롭된 뒤에 파일을 만드는 방식)용.
///
/// [targetPath]의 이름은 Finder가 충돌을 피해 고른 것(`report 2.pdf`)일 수
/// 있어 [FileEntry.name]과 다를 수 있다. 다운로드 서비스는 항목 이름 그대로
/// 저장하므로 같은 폴더 안의 숨은 임시 폴더에 받은 뒤 [targetPath]로 이름만
/// 바꾼다 — 같은 볼륨이라 복사 없이 옮겨지고, 받다가 실패해도 드롭한 자리에
/// 반쯤 받은 파일이 남지 않는다.
Future<void> downloadEntryTo({
  required FileEntry entry,
  required String targetPath,
  required FtpSessionManager ftpSessions,
  required SftpSessionManager sftpSessions,
  required WebdavSessionManager webdavSessions,
}) async {
  if (await FileSystemEntity.type(targetPath, followLinks: false) !=
      FileSystemEntityType.notFound) {
    // Finder는 비어 있는 이름을 주지만 다른 앱은 아닐 수 있다 — 덮어쓰지 않는다.
    throw FileSystemException('이미 있는 항목', targetPath);
  }
  final staging = await Directory(p.dirname(targetPath)).createTemp('.daylight_commander_dl_');
  try {
    await _downloadToLocal(
      sources: [entry],
      destinationDir: staging.path,
      ftpTransfer: FtpTransferService(ftpSessions),
      sftpTransfer: SftpTransferService(sftpSessions),
      webdavTransfer: WebdavTransferService(webdavSessions),
      // 방금 만든 빈 폴더라 충돌이 날 수 없다.
      onConflict: (_) async => ConflictAction.cancel,
    );
    final downloaded = p.join(staging.path, entry.name);
    if (entry.isDirectory) {
      await Directory(downloaded).rename(targetPath);
    } else {
      await File(downloaded).rename(targetPath);
    }
  } finally {
    await staging.delete(recursive: true);
  }
}
