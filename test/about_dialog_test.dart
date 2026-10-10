// From jejezz/application-release-templates common/ @ conventions-v1.
// conventions/about-dialog.md §4 — 정보 창이 열리고 버전·저작권·라이선스
// 화면이 동작하는지. daylight_commander를 앱의 pubspec name으로 바꾼다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:daylight_commander/about/about_dialog.dart';
import 'package:daylight_commander/about/daylight_about.dart';
import 'package:daylight_commander/app_identity.dart';
import 'package:daylight_commander/l10n/app_localizations.dart';

Widget _host(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: AppAboutDialog(version: '1.4.2', buildNumber: '37', tagline: 'Tagline', description: 'Description'),
      ),
    );

void main() {
  testWidgets('shows name, version, copyright and license (ko)', (tester) async {
    await tester.pumpWidget(_host(const Locale('ko')));
    expect(find.text(AppIdentity.displayName), findsOneWidget);
    expect(find.text('버전 1.4.2 (빌드 37)'), findsOneWidget);
    expect(find.text(AppIdentity.copyright), findsOneWidget);
    expect(find.text(AppIdentity.licenseName), findsOneWidget);
  });

  testWidgets('English strings', (tester) async {
    await tester.pumpWidget(_host(const Locale('en')));
    expect(find.text('Version 1.4.2 (build 37)'), findsOneWidget);
    expect(find.text('Open Source Licenses'), findsOneWidget);
  });

  testWidgets('open-source licenses page opens', (tester) async {
    await tester.pumpWidget(_host(const Locale('en')));
    await tester.tap(find.text('Open Source Licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('Daylight Commander: 소개와 주요 기능이 정보 창에 나온다', (tester) async {
    PackageInfo.setMockInitialValues(
        appName: 'Daylight Commander', packageName: 'art.zoomon.daylightcommander', version: '1.4.1', buildNumber: '20', buildSignature: '');
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(onPressed: () => showDaylightAbout(context), child: const Text('open')),
      ),
    ));
    await tester.runAsync(() async {
      await tester.tap(find.text('open'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
    expect(find.text(l10n.aboutTagline), findsOneWidget);
    expect(find.text(l10n.aboutFeatureNetwork), findsOneWidget);
    expect(find.text('버전 1.4.1 (빌드 20)'), findsOneWidget);
  });
}
