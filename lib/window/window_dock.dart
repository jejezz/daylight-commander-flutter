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

/// 1패널 모드에서 도킹하지 않았을 때의 최소 창 크기. 도킹 창과 같아서, 창을 좁게
/// 줄인 상태로 도킹/해제를 오가도 크기가 갑자기 바뀌지 않는다.
const _singlePaneMinimumSize = Size(_dockedMinimumWidth, 480);

bool get windowDockSupported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// 앱 창을 화면(작업 영역) 왼쪽/오른쪽 가장자리에 세로로 꽉 차게 붙인다.
/// OS의 AppBar 도킹이 아니라 창 크기와 위치만 바꾸는 방식이라, 해제하면 도킹 전 위치·크기로 돌아간다.
class WindowDockController extends StateNotifier<DockEdge?> {
  WindowDockController() : super(null);

  Rect? _restoreBounds;
  bool _singlePane = false;

  Size get _idleMinimum => _singlePane ? _singlePaneMinimumSize : _normalMinimumSize;

  /// 1패널 모드 여부가 바뀌면 최소 창 크기를 맞춘다. 1패널에서는 도킹 폭까지
  /// 자유롭게 줄일 수 있고, 2패널로 돌아가면 원래 최소 크기(창이 더 작으면
  /// OS가 그 크기까지 키운다)로 되돌린다. 도킹 중에는 도킹 최소 크기를 유지한다.
  Future<void> setSinglePane(bool singlePane) async {
    _singlePane = singlePane;
    if (state != null || !windowDockSupported) return;
    try {
      await windowManager.setMinimumSize(_idleMinimum);
    } catch (_) {}
  }

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
      await windowManager.setMinimumSize(_idleMinimum);
      if (restore != null) await windowManager.setBounds(restore);
    } catch (_) {}
  }
}

final windowDockProvider = StateNotifierProvider<WindowDockController, DockEdge?>(
  (ref) => WindowDockController(),
);
