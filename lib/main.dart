import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
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
import 'presentation/viewer/video_host.dart';
import 'update/update_scope.dart';
import 'update/update_service.dart';
import 'window/window_dock.dart';
import 'window/window_placement.dart';
import 'window/window_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerExtraLicenses();
  MediaKit.ensureInitialized();

  // 업데이트 서비스가 "복사·이동 중인가"를 알아야 해서 컨테이너를 직접 만든다.
  final container = ProviderContainer();

  // 창을 실제로 보일 준비(위치·크기 계산)가 끝나면 호출할 함수. 첫 프레임이 그려지기 전에 부르면
  // 테마가 입혀지지 않은 빈 화면이 잠깐 보였다가 바뀌는 깜빡임이 생기므로, 첫 프레임 뒤로 미룬다.
  Future<void> Function()? showWindow;
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    showWindow = await _prepareWindow(container);
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

  if (showWindow != null) {
    final show = showWindow;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(show()));
  }
}

/// 다음 프레임이 그려질 때까지 기다린다. 지금 막 레이아웃이 바뀌어 다시 그려야 할 프레임이
/// 예약돼 있지 않을 수도 있어, 프레임을 하나 더 예약해 둔다.
Future<void> _nextFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
  WidgetsBinding.instance.scheduleFrame();
  return completer.future;
}

/// 지난 실행의 창 크기·위치·도킹 상태를 계산해 둔다. 창을 실제로 보이려면 돌려준 함수를 불러야 한다
/// (첫 프레임이 그려진 뒤에 부르는 것은 호출하는 쪽의 몫). 1패널 모드로 끝냈다면 처음부터 최소 크기를
/// 낮춰 두고(도킹을 한 번 거쳐야 줄어드는 문제 방지), 도킹 중이었다면 같은 가장자리에 다시 붙인다.
Future<Future<void> Function()> _prepareWindow(ProviderContainer container) async {
  final saved = await WindowStateStore.load();
  final prefs = await SharedPreferences.getInstance();
  final singlePane = prefs.getBool(paneSingleModeKey) ?? false;
  final minimum = minimumWindowSize(singlePane: singlePane);

  // Windows는 WindowPlacement가 크기·위치·최대화를 기억하고 복원한다(window-placement.md).
  // 도킹 중에는 저장하지 않아, 다음 실행 때 도킹 전 크기로 돌아온다. 그 밖의 OS는 기존 방식.
  final placement = WindowPlacement.enabled
      ? WindowPlacement(
          prefs,
          defaultSize: const Size(1200, 720),
          isDocked: () => container.read(windowDockProvider) != null,
        )
      : null;

  var size = (placement == null ? saved.size : null) ?? const Size(1200, 720);
  size = Size(
    size.width < minimum.width ? minimum.width : size.width,
    size.height < minimum.height ? minimum.height : size.height,
  );

  Offset? position;
  final savedBounds = saved.bounds;
  if (placement == null && savedBounds != null) {
    try {
      final moved = (savedBounds.topLeft) & size;
      if (boundsVisibleOn(moved, await displayWorkAreas())) position = moved.topLeft;
    } catch (_) {}
  }

  final windowOptions = WindowOptions(
    size: size,
    minimumSize: minimum,
    center: placement == null && position == null,
    title: AppIdentity.displayName,
  );
  final placed = Completer<void>();
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (placement != null) {
      await placement.placeInitially();
    } else if (position != null) {
      await setBoundsAcrossMonitors(Rect.fromLTWH(position.dx, position.dy, size.width, size.height));
    }
    placed.complete();
  });

  return () async {
    await placed.future;
    // 배치(모니터 이동·배율 변경)가 끝난 직후에도 Flutter가 그 크기로 다시 그릴 프레임이
    // 아직 안 나왔을 수 있어, 한 프레임 더 기다렸다가 보여준다 (창 안 내용이 잠깐 엉뚱한
    // 크기로 보였다가 바뀌는 것을 막는다).
    await _nextFrame();
    await windowManager.show();
    await windowManager.focus();
    final edge = saved.dockEdge;
    if (singlePane && edge != null) {
      await container.read(windowDockProvider.notifier).dock(edge);
    }
    // 복원이 끝난 뒤에 시작해야, 복원 중의 크기 변화가 저장되지 않는다.
    if (placement != null) {
      placement.attach();
    } else {
      WindowStateSaver(isDocked: () => container.read(windowDockProvider) != null).start();
    }
  };
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
          theme: AppTheme.light(widget.settings.palette),
          darkTheme: AppTheme.dark(widget.settings.palette),
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
              child: VideoHostLayer(child: child!),
            ),
          ),
          home: const FolderAutoRefresh(child: HomeScreen()),
        ),
      ),
    );
  }
}
