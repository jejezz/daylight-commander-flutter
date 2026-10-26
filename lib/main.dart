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

  // 모니터가 여럿이면(Windows) 저장된 좌표로 복원하려 하지 않고 늘 주 모니터
  // 가운데에 연다. 모니터 배율이 서로 다를 때 저장된 좌표를 그대로 복원하려다
  // 창이 화면 밖으로 빠지는 문제를 여러 차례 겪었고, FancyZones 같은 창 관리
  // 유틸리티가 위치를 다시 덮어쓰는 경우까지 겹쳐서, 좌표를 정교하게 다루는
  // 대신 가장 단순하고 항상 보이는 방법을 쓰기로 했다(사용자 결정). 모니터가
  // 하나뿐이면(가장 흔한 경우) 그런 문제가 없으니 기존처럼 저장된 위치를
  // 그대로 복원한다.
  Offset? position;
  final displays = Platform.isWindows ? await screenRetriever.getAllDisplays() : const <Display>[];
  if (displays.length > 1) {
    // 주 모니터는 원점(0,0)에 있어서 screen_retriever의 논리 좌표가
    // window_manager의 좌표와 같은 단위다(틀어지는 건 원점이 아닌 보조
    // 모니터뿐). 물리 픽셀로 계산하면 배율이 큰 모니터에서 창이 오른쪽
    // 모니터에 걸쳐 버린다.
    final primary = await screenRetriever.getPrimaryDisplay();
    final origin = primary.visiblePosition ?? Offset.zero;
    final area = primary.visibleSize ?? primary.size;
    position = Offset(
      origin.dx + ((area.width - size.width) / 2).clamp(0, double.infinity),
      origin.dy + ((area.height - size.height) / 2).clamp(0, double.infinity),
    );
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
    // 숨긴 채로 옮긴 뒤 보여주면, getBounds()가 보고하는 창틀 좌표는 맞는데도
    // 실제 화면에는 안 보이는 경우가 있었다(렌더링 서피스가 모니터를 넘어갈 때
    // 제대로 못 따라간 것으로 추정). 먼저 보여준 뒤 옮기면 이미 떠 있는 창을
    // 드래그하는 것과 같은 경로를 타서 더 안정적이다.
    await windowManager.show();
    if (position != null) {
      await setBoundsAcrossMonitors(Rect.fromLTWH(position.dx, position.dy, size.width, size.height));
    }
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
