// 설정 창: 테마·색 구성·글자 크기·언어를 고르면 바뀌고 저장된다 (theming.md §3, localization.md §4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/l10n/app_localizations.dart';
import 'package:daylight_commander/presentation/theme/app_theme.dart';
import 'package:daylight_commander/presentation/theme/font_scale_provider.dart';
import 'package:daylight_commander/settings/app_settings.dart';
import 'package:daylight_commander/settings/settings_dialog.dart';

void main() {
  Future<(AppSettings, ProviderContainer)> pump(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final settings = await AppSettings.load();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(fontScaleProvider);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: AppSettingsScope(
        settings: settings,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => MaterialApp(
            locale: settings.locale ?? const Locale('ko'),
            theme: AppTheme.light(settings.palette),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SettingsDialog()),
          ),
        ),
      ),
    ));
    return (settings, container);
  }

  Future<void> saved(WidgetTester tester) => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));

  testWidgets('테마: 고르면 바뀌고 저장된다', (tester) async {
    final (settings, _) = await pump(tester, {'theme_mode': 'light'});
    await tester.tap(find.text('다크'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    await saved(tester);
    expect((await SharedPreferences.getInstance()).getString('theme_mode'), 'dark');
  });

  testWidgets('색 구성: 기본은 새턴, 고르면 바뀌고 저장된다', (tester) async {
    final (settings, _) = await pump(tester, {});
    expect(settings.palette, ColorPalette.saturn);
    await tester.tap(find.text('청록'));
    await tester.pumpAndSettle();
    expect(settings.palette, ColorPalette.teal);
    await saved(tester);
    expect((await SharedPreferences.getInstance()).getString('theme_palette'), 'teal');
  });

  testWidgets('저장된 색 구성을 읽는다', (tester) async {
    final (settings, _) = await pump(tester, {'theme_palette': 'highContrast'});
    expect(settings.palette, ColorPalette.highContrast);
    expect(AppTheme.dark(ColorPalette.highContrast).colorScheme.surface, Colors.black);
    expect(AppTheme.light(ColorPalette.rose).colorScheme.primary, ColorPalette.rose.lightPrimary);
  });

  testWidgets('글자 크기: 고르면 바뀌고 저장된다', (tester) async {
    final (_, container) = await pump(tester, {'font_scale': 1.15});
    expect(container.read(fontScaleProvider), 1.15);
    await tester.tap(find.text('작게'));
    await tester.pumpAndSettle();
    expect(container.read(fontScaleProvider), 0.9);
    await saved(tester);
    expect((await SharedPreferences.getInstance()).getDouble('font_scale'), 0.9);
  });

  testWidgets('언어: 영어를 고르면 바뀌고 저장된다, 시스템을 고르면 저장값이 지워진다', (tester) async {
    final (settings, _) = await pump(tester, {});
    await tester.tap(find.text('언어').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(settings.locale, const Locale('en'));
    await saved(tester);
    expect((await SharedPreferences.getInstance()).getString('app_locale'), 'en');

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(settings.locale, isNull);
    await saved(tester);
    expect((await SharedPreferences.getInstance()).containsKey('app_locale'), isFalse);
  });

  testWidgets('이전 버전에서 저장한 설정(theme_mode, app_locale)을 그대로 읽는다', (tester) async {
    final (settings, _) = await pump(tester, {'theme_mode': 'dark', 'app_locale': 'en'});
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.locale, const Locale('en'));
  });
}
