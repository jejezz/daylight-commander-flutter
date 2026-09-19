import 'cancel_token.dart';
import 'file_operation_service.dart';
import 'ftp_session_manager.dart';
import 'ftp_transfer_service.dart';
import '../domain/entities/file_entry.dart';

const _localOps = FileOperationService();

/// 소스/목적지의 URI 스킴을 보고 로컬-로컬(dart:io 그대로), 업로드, 다운로드,
/// FTP 세션간 전송 중 알맞은 경로로 보낸다 (ARCHITECTURE.md 4장의
/// FileSystemRepository 승격 지점 — 로컬은 그대로, FTP만 새 경로 추가).
Future<void> performTransfer({
  required List<FileEntry> sources,
  required Uri destinationDir,
  required bool isMove,
  required ConflictResolver onConflict,
  required FtpSessionManager ftpSessions,
  ProgressCallback? onProgress,
  CancelToken? cancelToken,
}) async {
  if (sources.isEmpty) return;

  final destIsFtp = destinationDir.scheme == 'ftp';
  final allLocal = sources.every((e) => e.location.scheme == 'file');
  final allFtp = sources.every((e) => e.location.scheme == 'ftp');

  if (!destIsFtp && allLocal) {
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

  final ftpTransfer = FtpTransferService(ftpSessions);

  if (destIsFtp && allLocal) {
    await ftpTransfer.upload(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return;
  }

  if (!destIsFtp && allFtp) {
    await ftpTransfer.download(
      sources: sources,
      destinationDir: destinationDir.toFilePath(),
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return;
  }

  if (destIsFtp && allFtp) {
    await ftpTransfer.transferBetweenFtpSessions(
      sources: sources,
      destinationDir: destinationDir,
      deleteSourceAfter: isMove,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return;
  }

  throw UnsupportedError('로컬과 FTP가 섞인 항목은 한 번에 옮길 수 없습니다.');
}
