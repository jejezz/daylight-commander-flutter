import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:daylight_commander/l10n/app_localizations.dart';
import 'package:daylight_commander/presentation/widgets/about_dialog.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Daylight Commander',
      packageName: 'com.ptype.daylight_commander',
      version: '1.1.1',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  testWidgets('정보 다이얼로그가 실제 패키지 버전을 표시한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showAboutInfoDialog(context),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.runAsync(() async {
      await tester.tap(find.text('open'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
    await tester.pump();

    expect(find.text('Daylight Commander 정보'), findsOneWidget);
    expect(find.text('버전 1.1.1+4'), findsOneWidget);
    expect(find.text('라이선스: MIT'), findsOneWidget);
  });
}
