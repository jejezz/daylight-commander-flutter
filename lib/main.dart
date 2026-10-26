import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'about/app_menu_bar.dart';
import 'about/daylight_about.dart';
import 'about/extra_licenses.dart';
import 'app_identity.dart';
import 'application/usecases/drop_promise_cache.dart';
import 'l10n/app_localizations.dart';
import 'presentation/home/folder_auto_refresh.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/home/operation_controller.dart';
import 'presentation/home/pane_layout_provider.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/font_scale_provider.dart';
import 'settings/app_settings.dart';
import 'update/update_scope.dart';
import 'update/update_service.dart';
import 'window/window_dock.dart';
import 'window/window_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerExtraLicenses();
  MediaKit.ensureInitialized();

  // 업데이트 서비스가 "복사·이동 중인가"를 알아야 해서 컨테이너를 직접 만든다.
  final container = ProviderContainer();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await _prepareWindow(container);
  }

  // 이전 실행에서 남은 Finder 드롭 임시 사본 정리 (기다리지 않는다).
  const DropPromiseCache().clear();

  final settings = await AppSettings.load();

  // 데스크톱이 아니거나 UPDATE_SERVER 가 비어 있으면 null — 업데이트 확인 없음. 파일 작업 중에는
  // 알리지도 설치하지도 않는다 (설치는 앱을 종료시킨다).
  final updates = await UpdateService.create(isBusy: () => isFileOperationRunning(container));
  // UpdateScope 는 MaterialApp 위 — 정보 창이 이것을 읽어 "업데이트 확인" 버튼을 붙인다.
  runApp(UpdateScope(
    service: updates,
    child: UncontrolledProviderScope(
      container: container,
      child: DaylightCommanderApp(settings: settings, updates: updates),
    ),
  ));
}

/// 지난 실행의 창 크기·위치·도킹 상태로 창을 연다. 1패널 모드로 끝냈다면 처음부터 최소 크기를
/// 낮춰 두고(도킹을 한 번 거쳐야 줄어드는 문제 방지), 도킹 중이었다면 같은 가장자리에 다시 붙인다.
Future<void> _prepareWindow(ProviderContainer container) async {
  final saved = await WindowStateStore.load();
  final prefs = await SharedPreferences.getInstance();
  final singlePane = prefs.getBool(paneSingleModeKey) ?? false;
  final minimum = minimumWindowSize(singlePane: singlePane);

  var size = saved.size ?? const Size(1200, 720);
  size = Size(
    size.width < minimum.width ? minimum.width : size.width,
    size.height < minimum.height ? minimum.height : size.height,
  );

  // 모니터가 여럿이면(Windows) 저장된 좌표 대신 창이 마지막에 있던 모니터 가운데에
  // 연다(그 모니터가 없으면 주 모니터). 모니터마다 배율이 다르면 좌표를 그대로
  // 복원할 수 없어서(setBounds가 창이 있는 모니터의 배율을 곱한다 —
  // centerWindowOnDisplay 문서 참고), 어느 모니터인지만 기억해 가운데에 놓는다.
  // 모니터가 하나뿐이면 기존처럼 저장된 위치를 그대로 복원한다.
  Offset? position;
  Display? centerOn;
  final displays = Platform.isWindows ? await screenRetriever.getAllDisplays() : const <Display>[];
  if (displays.length > 1) {
    final primary = await screenRetriever.getPrimaryDisplay();
    centerOn = displays.firstWhere((d) => d.name == saved.displayName, orElse: () => primary);
  } else {
    final savedBounds = saved.bounds;
    if (savedBounds != null) {
      try {
        final moved = (savedBounds.topLeft) & size;
        if (boundsVisibleOn(moved, await displayWorkAreas())) position = moved.topLeft;
      } catch (_) {}
    }
  }

  final windowOptions = WindowOptions(
    size: size,
    minimumSize: minimum,
    title: AppIdentity.displayName,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (centerOn != null) {
      await centerWindowOnDisplay(centerOn, size);
    } else if (position != null) {
      await setBoundsAcrossMonitors(Rect.fromLTWH(position.dx, position.dy, size.width, size.height));
    }
    await windowManager.show();
    await windowManager.focus();
    final edge = saved.dockEdge;
    if (singlePane && edge != null) {
      await container.read(windowDockProvider.notifier).dock(edge);
    }
    // 복원이 끝난 뒤에 시작해야, 복원 중의 크기 변화가 저장되지 않는다.
    WindowStateSaver(isDocked: () => container.read(windowDockProvider) != null).start();
  });
}

class DaylightCommanderApp extends ConsumerStatefulWidget {
  const DaylightCommanderApp({super.key, required this.settings, this.updates});

  /// 테마 모드·언어 (theme_mode / app_locale).
  final AppSettings settings;

  /// 시작할 때 새 버전을 확인한다. null 이면 업데이트 확인을 쓰지 않는다.
  final UpdateService? updates;

  @override
  ConsumerState<DaylightCommanderApp> createState() => _DaylightCommanderAppState();
}

class _DaylightCommanderAppState extends ConsumerState<DaylightCommanderApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  static final bool _isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_syncWindowBrightness);
    _syncWindowBrightness();
    widget.updates?.startAutomaticCheck(_navigatorKey);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_syncWindowBrightness);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱에서 다크를 골라도 OS가 라이트면 제목 표시줄은 밝게 남는다 (theming.md §4).
  @override
  void didChangePlatformBrightness() => _syncWindowBrightness();

  void _syncWindowBrightness() {
    if (!_isDesktop || Platform.isLinux) return;
    final brightness = switch (widget.settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    windowManager.setBrightness(brightness);
  }

  // macOS 앱 메뉴의 "About" 가 앱 바의 정보 버튼과 같은 대화상자를 연다 (about-dialog.md §1).
  void _showAbout() {
    final context = _navigatorKey.currentContext;
    if (context != null) showDaylightAbout(context);
  }

  void _checkForUpdates() {
    final context = _navigatorKey.currentContext;
    if (context != null) widget.updates?.checkManually(context);
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    return AppSettingsScope(
      settings: widget.settings,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          title: AppIdentity.displayName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: widget.settings.themeMode,
          locale: widget.settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: AppSettings.resolveLocale,
          builder: (context, child) => AppMenuBar(
            onAbout: _showAbout,
            onCheckForUpdates: widget.updates == null ? null : _checkForUpdates,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
              child: child!,
            ),
          ),
          home: const FolderAutoRefresh(child: HomeScreen()),
        ),
      ),
    );
  }
}
