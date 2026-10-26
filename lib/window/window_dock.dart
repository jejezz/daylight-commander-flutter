import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'window_state.dart';

enum DockEdge { left, right }

/// 창 도킹 폭 (논리 픽셀). 앱 바와 기능 막대가 겨우 들어가는 최소한의 폭이다.
const dockedWindowWidth = 520.0;
const _normalMinimumSize = Size(960, 600);
const _dockedMinimumWidth = 480.0;

/// 1패널 모드에서 도킹하지 않았을 때의 최소 창 크기. 도킹 창과 같아서, 창을 좁게
/// 줄인 상태로 도킹/해제를 오가도 크기가 갑자기 바뀌지 않는다.
const _singlePaneMinimumSize = Size(_dockedMinimumWidth, 480);

/// 디렉토리 트리가 도킹되어 있을 때 2패널 모드에 추가로 필요한 폭(트리 기본 폭 +
/// 분할선). tree_dock_provider.dart의 treeDockDefaultWidth(220)와 함께 맞춰 바꾼다.
/// 창을 더 키울 수 없는 상황에 대한 보험은 _PaneArea의 폭 계산이 맡는다.
const _treeDockExtraWidth = 230.0;

/// 시작할 때 쓸 최소 창 크기. 1패널 모드로 끝냈다면 처음부터 낮춰 둔다 — 그렇지 않으면
/// 도킹을 한 번 거치기 전까지 창이 960 폭 아래로 줄어들지 않는다.
Size minimumWindowSize({required bool singlePane}) =>
    singlePane ? _singlePaneMinimumSize : _normalMinimumSize;

bool get windowDockSupported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// [bounds]가 중심으로 걸쳐 있는 모니터의 작업 영역. 모니터 정보가 없거나
/// 어디에도 안 걸치면 첫 번째 모니터(그마저 없으면 [bounds] 자신)를 쓴다.
Rect _hostWorkArea(Rect bounds, List<Display> displays) {
  Rect work(Display d) => (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size);
  final center = bounds.center;
  return displays.map(work).firstWhere(
        (r) => r.contains(center),
        orElse: () => displays.isEmpty ? bounds : work(displays.first),
      );
}

/// [bounds]를 크기는 그대로 두고 [area] 밖으로 빠지지 않게 왼쪽/위로 당긴다.
Rect _clampRectInto(Rect bounds, Rect area) {
  var left = bounds.left;
  var top = bounds.top;
  if (left + bounds.width > area.right) left = area.right - bounds.width;
  if (left < area.left) left = area.left;
  if (top + bounds.height > area.bottom) top = area.bottom - bounds.height;
  if (top < area.top) top = area.top;
  return Rect.fromLTWH(left, top, bounds.width, bounds.height);
}

/// [bounds]를 크기는 그대로 두고, 화면 밖으로 빠지지 않게 왼쪽/위로 당긴다.
/// 오른쪽에 보조 모니터가 있을 때 창을 오른쪽으로 키우면 모니터 밖으로 빠질 수
/// 있어서(`_growToAtLeast`/`undock`에서 이 문제가 실제로 있었다) 키우거나
/// 복원할 때마다 이 함수를 거친다. Windows는 `virtualScreenBounds`(모든 모니터를
/// 합친 전체 경계, window_manager와 같은 Win32 좌표계)로 당긴다 — 모니터별
/// 작업 영역(screen_retriever)은 모니터마다 DPI가 다르면 좌표가 어긋날 수 있다
/// (window_state.dart의 virtualScreenBounds 문서 참고). 다른 OS나 정보를 못
/// 읽은 경우에는 지금 걸쳐 있는 모니터의 작업 영역을 쓴다.
Future<Rect> _clampToHostMonitor(Rect bounds) async {
  final virtualScreen = virtualScreenBounds();
  if (virtualScreen != null) return _clampRectInto(bounds, virtualScreen);
  try {
    final displays = await screenRetriever.getAllDisplays();
    return _clampRectInto(bounds, _hostWorkArea(bounds, displays));
  } catch (_) {
    return bounds;
  }
}

/// 앱 창을 화면(작업 영역) 왼쪽/오른쪽 가장자리에 세로로 꽉 차게 붙인다.
/// OS의 AppBar 도킹이 아니라 창 크기와 위치만 바꾸는 방식이라, 해제하면 도킹 전 위치·크기로 돌아간다.
class WindowDockController extends StateNotifier<DockEdge?> {
  WindowDockController() : super(null);

  Rect? _restoreBounds;
  bool _singlePane = false;
  bool _treeDockOpen = false;

  Size get _idleMinimum {
    if (_singlePane) return _singlePaneMinimumSize;
    final extra = _treeDockOpen ? _treeDockExtraWidth : 0.0;
    return Size(_normalMinimumSize.width + extra, _normalMinimumSize.height);
  }

  /// 창이 [minimum]보다 작으면 그 크기까지 키운다. `setMinimumSize`는 앞으로의
  /// 드래그 리사이즈만 제한할 뿐, 이미 그보다 작아진 창을 직접 키워주지는 않는다.
  /// 키운 뒤에는 [_clampToHostMonitor]로 모니터 밖으로 빠지지 않게 당긴다.
  Future<void> _growToAtLeast(Size minimum) async {
    final bounds = await windowManager.getBounds();
    if (bounds.width < minimum.width || bounds.height < minimum.height) {
      final grown = Rect.fromLTWH(
        bounds.left,
        bounds.top,
        math.max(bounds.width, minimum.width),
        math.max(bounds.height, minimum.height),
      );
      await setBoundsAcrossMonitors(await _clampToHostMonitor(grown));
    }
  }

  /// 1패널 모드 여부가 바뀌면 최소 창 크기를 맞춘다. 1패널에서는 도킹 폭까지
  /// 자유롭게 줄일 수 있고, 2패널로 돌아가면 원래 최소 크기로 되돌리면서 창이
  /// 이미 그보다 좁으면 직접 키운다. 도킹 중에는 도킹 최소 크기를 유지한다.
  Future<void> setSinglePane(bool singlePane) async {
    _singlePane = singlePane;
    if (state != null || !windowDockSupported) return;
    try {
      final minimum = _idleMinimum;
      await windowManager.setMinimumSize(minimum);
      await _growToAtLeast(minimum);
    } catch (_) {}
  }

  /// 디렉토리 트리 도킹 열림 여부가 바뀌면 2패널 모드의 최소 창 폭을 그만큼
  /// 늘리거나 줄이고, 창이 이미 그보다 좁으면 직접 키운다. 1패널 모드와 도킹
  /// 중에는 트리 폭을 고려하지 않는다(패널 하나만 넓게 쓰므로 덜 빠듯하다).
  Future<void> setTreeDockOpen(bool open) async {
    _treeDockOpen = open;
    if (_singlePane || state != null || !windowDockSupported) return;
    try {
      final minimum = _idleMinimum;
      await windowManager.setMinimumSize(minimum);
      await _growToAtLeast(minimum);
    } catch (_) {}
  }

  Future<void> dock(DockEdge edge) async {
    if (!windowDockSupported) return;
    try {
      final current = await windowManager.getBounds();
      // 이미 도킹된 상태에서 반대편으로 옮길 때는 처음 원래 위치를 유지한다.
      _restoreBounds ??= current;

      final displays = await screenRetriever.getAllDisplays();
      final area = _hostWorkArea(current, displays);

      final width = dockedWindowWidth.clamp(_dockedMinimumWidth, area.width);
      await windowManager.setMinimumSize(const Size(_dockedMinimumWidth, 480));
      await setBoundsAcrossMonitors(Rect.fromLTWH(
        edge == DockEdge.left ? area.left : area.right - width,
        area.top,
        width,
        area.height,
      ));
      state = edge;
      // 다음 실행에서 같은 도킹 상태와 도킹 전 위치·크기로 복원할 수 있게 남긴다.
      await WindowStateStore.saveBounds(_restoreBounds!);
      await WindowStateStore.saveDock(edge);
    } catch (_) {
      // 창 플러그인이 없거나 실패하면 도킹하지 않고 현재 상태를 유지한다.
    }
  }

  Future<void> undock() async {
    final restore = _restoreBounds;
    if (state == null && restore == null) return;
    _restoreBounds = null;
    state = null;
    if (!windowDockSupported) return;
    try {
      await WindowStateStore.saveDock(null);
      final minimum = _idleMinimum;
      await windowManager.setMinimumSize(minimum);
      if (restore != null) {
        // 도킹 전 위치로 복원하되, 그 사이 모드가 바뀌어 최소 크기보다 작아졌다면
        // 키우고, 모니터 밖으로 빠지지 않게 당긴다.
        final grown = Rect.fromLTWH(
          restore.left,
          restore.top,
          math.max(restore.width, minimum.width),
          math.max(restore.height, minimum.height),
        );
        await setBoundsAcrossMonitors(await _clampToHostMonitor(grown));
      } else {
        await _growToAtLeast(minimum);
      }
    } catch (_) {}
  }
}

final windowDockProvider = StateNotifierProvider<WindowDockController, DockEdge?>(
  (ref) => WindowDockController(),
);
