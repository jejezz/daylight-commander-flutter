/// 진행 중인 파일 작업을 취소하기 위한 토큰 (ARCHITECTURE.md 5장).
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const OperationCancelledException();
  }
}

class OperationCancelledException implements Exception {
  const OperationCancelledException();

  @override
  String toString() => '작업이 취소되었습니다.';
}
