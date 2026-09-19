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
