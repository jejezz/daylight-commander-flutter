import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'about/app_menu_bar.dart';
import 'about/daylight_about.dart';
import 'about/extra_licenses.dart';
import 'app_identity.dart';
import 'application/usecases/drop_promise_cache.dart';
import 'l10n/app_localizations.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/font_scale_provider.dart';
import 'presentation/theme/locale_provider.dart';
import 'presentation/theme/theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerExtraLicenses();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 720),
      minimumSize: Size(960, 600),
      title: AppIdentity.displayName,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 이전 실행에서 남은 Finder 드롭 임시 사본 정리 (기다리지 않는다).
  const DropPromiseCache().clear();

  runApp(const ProviderScope(child: DaylightCommanderApp()));
}

class DaylightCommanderApp extends ConsumerStatefulWidget {
  const DaylightCommanderApp({super.key});

  @override
  ConsumerState<DaylightCommanderApp> createState() => _DaylightCommanderAppState();
}

class _DaylightCommanderAppState extends ConsumerState<DaylightCommanderApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  // macOS 앱 메뉴의 "About" 가 앱 바의 정보 버튼과 같은 대화상자를 연다 (about-dialog.md §1).
  void _showAbout() {
    final context = _navigatorKey.currentContext;
    if (context != null) showDaylightAbout(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppIdentity.displayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // OS 언어가 한국어면 한국어, 그 밖의 모든 언어는 영어 (localization.md §3). 콜백이 없으면 지원 목록의 첫 언어(ko)로 떨어진다.
      localeResolutionCallback: (device, supported) =>
          device?.languageCode == 'ko' ? const Locale('ko') : const Locale('en'),
      builder: (context, child) => AppMenuBar(
        onAbout: _showAbout,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
          child: child!,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
