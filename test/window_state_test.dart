import 'dart:ui';

import 'package:daylight_commander/window/window_dock.dart';
import 'package:daylight_commander/window/window_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('저장한 창 위치·크기·도킹 상태를 그대로 읽는다', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await WindowStateStore.load()).bounds, isNull);

    await WindowStateStore.saveBounds(const Rect.fromLTWH(30, 40, 700, 500));
    await WindowStateStore.saveDock(DockEdge.right);
    final saved = await WindowStateStore.load();
    expect(saved.bounds, const Rect.fromLTWH(30, 40, 700, 500));
    expect(saved.size, const Size(700, 500));
    expect(saved.dockEdge, DockEdge.right);

    await WindowStateStore.saveDock(null);
    expect((await WindowStateStore.load()).dockEdge, isNull);
  });

  test('모니터 밖으로 나간 저장 위치는 쓰지 않는다', () {
    const areas = [Rect.fromLTWH(0, 0, 1440, 900)];
    expect(
      boundsVisibleOn(const Rect.fromLTWH(100, 100, 960, 600), areas),
      isTrue,
    );
    expect(
      boundsVisibleOn(const Rect.fromLTWH(3000, 100, 960, 600), areas),
      isFalse,
    );
    // 가장자리에 걸쳐 일부만 보여도 잡고 끌 수 있으면 쓴다.
    expect(
      boundsVisibleOn(const Rect.fromLTWH(1300, 100, 960, 600), areas),
      isTrue,
    );
    expect(
      boundsVisibleOn(const Rect.fromLTWH(1430, 100, 960, 600), areas),
      isFalse,
    );
  });

  test('1패널 모드는 처음부터 낮은 최소 창 크기를 쓴다', () {
    expect(minimumWindowSize(singlePane: false), const Size(960, 600));
    expect(minimumWindowSize(singlePane: true).width, lessThan(960));
  });
}
