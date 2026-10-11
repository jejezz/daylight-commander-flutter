// 테마·언어 메뉴: 체크 표시가 있는 팝업이고, 고르면 설정이 바뀌고 저장된다 (theming.md §3, localization.md §4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/l10n/app_localizations.dart';
import 'package:daylight_commander/settings/app_settings.dart';
import 'package:daylight_commander/presentation/theme/font_scale_provider.dart';
import 'package:daylight_commander/presentation/widgets/font_scale_menu.dart';
import 'package:daylight_commander/settings/settings_menus.dart';

void main() {
  Future<AppSettings> pump(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final settings = await AppSettings.load();
    await tester.pumpWidget(AppSettingsScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          locale: settings.locale ?? const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Row(children: [ThemeMenuButton(), LanguageMenuButton()]),
          ),
        ),
      ),
    ));
    return settings;
  }

  testWidgets('테마 메뉴: 지금 값에 체크가 있고, 고르면 바뀌고 저장된다', (tester) async {
    final settings = await pump(tester, {'theme_mode': 'light'});
    await tester.tap(find.byIcon(Icons.light_mode_rounded));
    await tester.pumpAndSettle();

    final checked = tester.widgetList<CheckedPopupMenuItem<ThemeMode>>(find.byType(CheckedPopupMenuItem<ThemeMode>));
    expect(checked.where((i) => i.checked).single.value, ThemeMode.light);

    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<ThemeMode>, '다크'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getString('theme_mode'), 'dark');
  });

  testWidgets('언어 메뉴: 영어를 고르면 바뀌고 저장된다, 시스템을 고르면 저장값이 지워진다', (tester) async {
    final settings = await pump(tester, {});
    await tester.tap(find.byIcon(Icons.language_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<String>, 'English'));
    await tester.pumpAndSettle();
    expect(settings.locale, const Locale('en'));
    expect((await SharedPreferences.getInstance()).getString('app_locale'), 'en');

    await tester.tap(find.byIcon(Icons.language_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((w) => w is CheckedPopupMenuItem<String> && w.value == ''));
    await tester.pumpAndSettle();
    expect(settings.locale, isNull);
    expect((await SharedPreferences.getInstance()).containsKey('app_locale'), isFalse);
  });

  testWidgets('이전 버전에서 저장한 설정(theme_mode, app_locale)을 그대로 읽는다', (tester) async {
    final settings = await pump(tester, {'theme_mode': 'dark', 'app_locale': 'en'});
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.locale, const Locale('en'));
  });

  testWidgets('글자 크기 메뉴: 지금 값에 체크가 있고, 고르면 바뀌고 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({'font_scale': 1.15});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(fontScaleProvider); // 저장된 값을 읽기 시작
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: FontScaleMenuButton()),
      ),
    ));
    await tester.tap(find.byType(FontScaleMenuButton));
    await tester.pumpAndSettle();
    final checked = tester.widgetList<CheckedPopupMenuItem<double>>(find.byType(CheckedPopupMenuItem<double>));
    expect(checked.where((i) => i.checked).single.value, 1.15);

    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<double>, '작게'));
    await tester.pumpAndSettle();
    expect(container.read(fontScaleProvider), 0.9);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect((await SharedPreferences.getInstance()).getDouble('font_scale'), 0.9);
  });
}
