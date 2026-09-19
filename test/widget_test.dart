import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:daylight_commander/main.dart';

void main() {
  testWidgets('앱이 크래시 없이 2-pane 화면을 그린다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DaylightCommanderApp()),
    );
    // 로컬 디렉터리 목록 로딩(실제 dart:io 비동기 작업)이 끝날 시간을 준다.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Daylight Commander'), findsOneWidget);
  });
}
