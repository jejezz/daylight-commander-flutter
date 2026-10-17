import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

enum DockEdge { left, right }

/// 창 도킹 폭 (논리 픽셀). 앱 바와 기능 막대가 겨우 들어가는 최소한의 폭이다.
const dockedWindowWidth = 520.0;
const _normalMinimumSize = Size(960, 600);
const _dockedMinimumWidth = 480.0;

bool get windowDockSupported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// 앱 창을 화면(작업 영역) 왼쪽/오른쪽 가장자리에 세로로 꽉 차게 붙인다.
/// OS의 AppBar 도킹이 아니라 창 크기와 위치만 바꾸는 방식이라, 해제하면 도킹 전 위치·크기로 돌아간다.
class WindowDockController extends StateNotifier<DockEdge?> {
  WindowDockController() : super(null);

  Rect? _restoreBounds;

  Future<void> dock(DockEdge edge) async {
    if (!windowDockSupported) return;
    try {
      final current = await windowManager.getBounds();
      // 이미 도킹된 상태에서 반대편으로 옮길 때는 처음 원래 위치를 유지한다.
      _restoreBounds ??= current;

      final displays = await screenRetriever.getAllDisplays();
      final center = current.center;
      Rect work(Display d) =>
          (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size);
      final area = displays.map(work).firstWhere(
            (r) => r.contains(center),
            orElse: () => displays.isEmpty ? current : work(displays.first),
          );

      final width = dockedWindowWidth.clamp(_dockedMinimumWidth, area.width);
      await windowManager.setMinimumSize(const Size(_dockedMinimumWidth, 480));
      await windowManager.setBounds(Rect.fromLTWH(
        edge == DockEdge.left ? area.left : area.right - width,
        area.top,
        width,
        area.height,
      ));
      state = edge;
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
      await windowManager.setMinimumSize(_normalMinimumSize);
      if (restore != null) await windowManager.setBounds(restore);
    } catch (_) {}
  }
}

final windowDockProvider = StateNotifierProvider<WindowDockController, DockEdge?>(
  (ref) => WindowDockController(),
);
