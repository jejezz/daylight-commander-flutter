// 파일 작업(복사·이동·삭제) 중에는 업데이트가 알리지도 설치하지도 않는다 — 설치는 앱을 종료시킨다.
// UpdateService 는 isBusy 가 true 인 동안 알림을 미루고 "지금 업데이트" 를 막는다 (update_test.dart).
// 여기서는 이 앱이 isBusy 를 어떻게 판정하는지만 확인한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daylight_commander/presentation/home/operation_controller.dart';

class _FakeOperation extends OperationController {
  void set(OperationState? value) => state = value;
}

void main() {
  late _FakeOperation operation;
  late ProviderContainer container;

  setUp(() {
    operation = _FakeOperation();
    container = ProviderContainer(overrides: [
      operationControllerProvider.overrideWith((ref) => operation),
    ]);
  });
  tearDown(() => container.dispose());

  const running = OperationState(kind: OperationKind.copy, done: 3, total: 10, currentName: 'a.txt');

  test('유휴일 때는 바쁘지 않다', () {
    expect(isFileOperationRunning(container), isFalse);
  });

  test('복사·이동·삭제가 진행 중이면 바쁘다', () {
    for (final kind in OperationKind.values) {
      operation.set(OperationState(kind: kind, done: 1, total: 4, currentName: 'x'));
      expect(isFileOperationRunning(container), isTrue, reason: kind.name);
    }
  });

  test('오류로 멈춘 채 배너에 남은 작업은 진행 중이 아니다', () {
    operation.set(const OperationState(
        kind: OperationKind.copy, done: 3, total: 10, currentName: 'a.txt', error: '권한 없음'));
    expect(isFileOperationRunning(container), isFalse);
  });

  test('작업이 끝나면(null) 다시 바쁘지 않다', () {
    operation.set(running);
    expect(isFileOperationRunning(container), isTrue);
    operation.set(null);
    expect(isFileOperationRunning(container), isFalse);
  });
}
