import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cancel_token.dart';
import '../../application/file_operation_service.dart';
import '../../application/ftp_session_manager.dart';
import '../../application/ftp_transfer_service.dart';
import '../../application/transfer_router.dart';
import '../../domain/entities/file_entry.dart';

enum OperationKind { copy, move, delete }

class OperationState {
  const OperationState({
    required this.kind,
    required this.done,
    required this.total,
    required this.currentName,
    this.error,
  });

  final OperationKind kind;
  final int done;
  final int total;
  final String currentName;
  final String? error;

  double get ratio => total == 0 ? 1 : done / total;
}

/// 현재 진행 중인 파일 작업 하나를 추적한다.
///
/// ARCHITECTURE.md 5장의 정책대로 큐는 순차 실행(동시 1개)만 지원한다.
/// 로컬-로컬은 [FileOperationService]로, FTP가 관여하면 [performTransfer]가
/// 업로드/다운로드/세션간 전송으로 라우팅한다 (transfer_router.dart).
class OperationController extends StateNotifier<OperationState?> {
  OperationController() : super(null);

  final _service = const FileOperationService();
  CancelToken? _cancelToken;

  void cancel() => _cancelToken?.cancel();

  Future<void> runCopy({
    required List<FileEntry> sources,
    required Uri destinationDir,
    required ConflictResolver onConflict,
    required FtpSessionManager ftpSessions,
  }) {
    return _run(
      OperationKind.copy,
      (token, onProgress) => performTransfer(
        sources: sources,
        destinationDir: destinationDir,
        isMove: false,
        onConflict: onConflict,
        ftpSessions: ftpSessions,
        onProgress: onProgress,
        cancelToken: token,
      ),
    );
  }

  Future<void> runMove({
    required List<FileEntry> sources,
    required Uri destinationDir,
    required ConflictResolver onConflict,
    required FtpSessionManager ftpSessions,
  }) {
    return _run(
      OperationKind.move,
      (token, onProgress) => performTransfer(
        sources: sources,
        destinationDir: destinationDir,
        isMove: true,
        onConflict: onConflict,
        ftpSessions: ftpSessions,
        onProgress: onProgress,
        cancelToken: token,
      ),
    );
  }

  Future<void> runDelete({
    required List<FileEntry> entries,
    required bool toTrash,
    required FtpSessionManager ftpSessions,
  }) {
    return _run(OperationKind.delete, (token, onProgress) async {
      final ftpTransfer = FtpTransferService(ftpSessions);
      final total = entries.length;
      var done = 0;
      for (final entry in entries) {
        token.throwIfCancelled();
        if (entry.location.scheme == 'ftp') {
          await ftpTransfer.deleteEntry(entry);
        } else {
          await _service.delete(entries: [entry], toTrash: toTrash);
        }
        done++;
        onProgress(FileOperationProgress(done: done, total: total, currentName: entry.name));
      }
    });
  }

  Future<void> _run(
    OperationKind kind,
    Future<void> Function(CancelToken token, ProgressCallback onProgress) task,
  ) async {
    final token = CancelToken();
    _cancelToken = token;
    state = OperationState(kind: kind, done: 0, total: 1, currentName: '');
    try {
      await task(token, (progress) {
        state = OperationState(
          kind: kind,
          done: progress.done,
          total: progress.total,
          currentName: progress.currentName,
        );
      });
    } on OperationCancelledException {
      // 사용자가 취소함 — 별도 에러 표시 없이 종료.
    } catch (e) {
      state = OperationState(
        kind: kind,
        done: state?.done ?? 0,
        total: state?.total ?? 1,
        currentName: '',
        error: e.toString(),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
    } finally {
      _cancelToken = null;
      if (mounted) state = null;
    }
  }
}

final operationControllerProvider =
    StateNotifierProvider<OperationController, OperationState?>(
  (ref) => OperationController(),
);
