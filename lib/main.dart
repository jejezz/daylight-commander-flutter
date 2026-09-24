import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'application/usecases/drop_promise_cache.dart';
import 'l10n/app_localizations.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/font_scale_provider.dart';
import 'presentation/theme/locale_provider.dart';
import 'presentation/theme/theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 720),
      minimumSize: Size(960, 600),
      title: 'Daylight Commander',
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

class DaylightCommanderApp extends ConsumerWidget {
  const DaylightCommanderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    return MaterialApp(
      title: 'Daylight Commander',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
