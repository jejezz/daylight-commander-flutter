import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/main.dart';

/// 글자 크기를 "크게"(1.15배)로 키운 상태로 2-pane 화면을 그려도 컬럼
/// 헤더/행의 고정폭 SizedBox가 오버플로하지 않는지 확인한다 — i18n
/// 작업(PLAN.md 12번) 때 영어 "Modified"가 고정폭을 오버플로했던 것과
/// 같은 종류의 회귀를 잡기 위한 테스트.
void main() {
  testWidgets('글자 크기를 크게 해도 2-pane 화면이 오버플로 없이 그려진다', (tester) async {
    SharedPreferences.setMockInitialValues({'font_scale': 1.15});

    await tester.pumpWidget(
      const ProviderScope(child: DaylightCommanderApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });
}
