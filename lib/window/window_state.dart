import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart'
    show
        GetSystemMetrics,
        SM_CXVIRTUALSCREEN,
        SM_CYVIRTUALSCREEN,
        SM_XVIRTUALSCREEN,
        SM_YVIRTUALSCREEN;
import 'package:window_manager/window_manager.dart';

import 'window_dock.dart';

const _kLeft = 'window_x';
const _kTop = 'window_y';
const _kWidth = 'window_width';
const _kHeight = 'window_height';
const _kDockEdge = 'window_dock_edge';

/// 지난 실행이 남긴 창 상태. [bounds]는 도킹하지 않은 상태의 위치·크기(도킹 중이어도
/// 도킹 전 값)이고, [dockEdge]는 도킹 중이었다면 붙어 있던 가장자리다.
class SavedWindowState {
  const SavedWindowState({this.bounds, this.dockEdge});

  final Rect? bounds;
  final DockEdge? dockEdge;

  Size? get size => bounds?.size;
}

/// 창 위치·크기·도킹 상태를 SharedPreferences에 저장하고 읽는다.
class WindowStateStore {
  static Future<SavedWindowState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble(_kWidth);
    final h = prefs.getDouble(_kHeight);
    final x = prefs.getDouble(_kLeft);
    final y = prefs.getDouble(_kTop);
    Rect? bounds;
    if (w != null && h != null && w > 0 && h > 0) {
      bounds = Rect.fromLTWH(x ?? 0, y ?? 0, w, h);
    }
    final edge = DockEdge.values.asNameMap()[prefs.getString(_kDockEdge)];
    return SavedWindowState(bounds: bounds, dockEdge: edge);
  }

  static Future<void> saveBounds(Rect bounds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLeft, bounds.left);
    await prefs.setDouble(_kTop, bounds.top);
    await prefs.setDouble(_kWidth, bounds.width);
    await prefs.setDouble(_kHeight, bounds.height);
  }

  static Future<void> saveDock(DockEdge? edge) async {
    final prefs = await SharedPreferences.getInstance();
    if (edge == null) {
      await prefs.remove(_kDockEdge);
    } else {
      await prefs.setString(_kDockEdge, edge.name);
    }
  }
}

/// 저장된 창 위치가 연결된 모니터 안에 (대부분) 들어오는지. 모니터를 뺐거나 해상도가 바뀌어
/// 창이 화면 밖에 놓이는 것을 막는다.
bool boundsVisibleOn(Rect bounds, List<Rect> workAreas) {
  for (final area in workAreas) {
    final overlap = bounds.intersect(area);
    if (overlap.width >= 120 && overlap.height >= 80) return true;
  }
  return false;
}

/// 창을 옮기거나 크기를 바꾸면 잠시 뒤 새 위치·크기를 저장한다. 도킹 중이거나 최대화·전체화면·
/// 최소화 상태에서는 저장하지 않는다 — 다음 실행 때 도킹 전 크기로 돌아와야 하기 때문이다.
class WindowStateSaver with WindowListener {
  WindowStateSaver({required this.isDocked});

  final bool Function() isDocked;
  Timer? _timer;

  void start() => windowManager.addListener(this);

  void dispose() {
    _timer?.cancel();
    windowManager.removeListener(this);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    if (isDocked()) return;
    try {
      if (await windowManager.isMaximized() ||
          await windowManager.isFullScreen() ||
          await windowManager.isMinimized()) {
        return;
      }
      await WindowStateStore.saveBounds(await windowManager.getBounds());
    } catch (_) {}
  }

  @override
  void onWindowResize() => _schedule();

  @override
  void onWindowResized() => _schedule();

  @override
  void onWindowMove() => _schedule();

  @override
  void onWindowMoved() => _schedule();
}

/// 모니터별 작업 영역 목록.
Future<List<Rect>> displayWorkAreas() async {
  final displays = await screenRetriever.getAllDisplays();
  return [
    for (final d in displays)
      (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size),
  ];
}

/// [bounds]로 창을 옮기거나 키운다. 모니터마다 DPI가 다르면, 창이 아직 이전
/// 모니터의 DPI 컨텍스트에 있는 상태로 한 번에 멀리 떨어진 모니터로 옮겨질 때
/// 요청한 좌표가 DPI 배율만큼 어긋난 자리에 놓이는 걸 실측으로 확인했다(두
/// 모니터 배율 비율만큼 정확히 어긋남). 한 번 더 같은 값으로 맞추면, 그때는
/// 창이 이미 대상 모니터의 DPI 컨텍스트로 넘어가 있어서 정확한 자리에
/// 안착한다. 다만 듀얼 모니터에서 창이 화면 밖으로 빠지던 문제는 FancyZones
/// 같은 창 관리 유틸리티가 별도로 위치를 덮어쓰는 것도 겹쳐 있었다 — 이
/// 함수는 그와 무관하게 "요청한 자리에 정확히 놓는다"를 보장하기 위한
/// 안전장치로 남겨둔다.
Future<void> setBoundsAcrossMonitors(Rect bounds) async {
  await windowManager.setBounds(bounds);
  // 두 호출을 곧바로 이어 붙이면 Windows가 모니터 간 DPI 전환(DPI 변경
  // 메시지 처리)을 미처 끝내기 전이라 두 번째 호출도 여전히 어긋날 때가
  // 있었다(실측으로 확인 — 중간에 플랫폼 채널 왕복 하나만 끼워도 안정됨).
  // getBounds 왕복 한 번으로 그 사이 시간을 확보한다.
  await windowManager.getBounds();
  await windowManager.setBounds(bounds);
}

/// 모든 모니터를 합친 가상 화면 전체 경계(Windows 전용, `GetSystemMetrics`, 물리
/// 픽셀). window_manager의 좌표(배율이 적용된 논리 단위)와 단위가 달라서
/// 정확한 경계가 아니라 "창이 화면 전체 바깥으로 나가지 않게" 하는 느슨한 상한으로만 쓴다.
Rect? virtualScreenBounds() {
  if (!Platform.isWindows) return null;
  final left = GetSystemMetrics(SM_XVIRTUALSCREEN);
  final top = GetSystemMetrics(SM_YVIRTUALSCREEN);
  final width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  final height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if (width <= 0 || height <= 0) return null;
  return Rect.fromLTWH(left.toDouble(), top.toDouble(), width.toDouble(), height.toDouble());
}
