import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
