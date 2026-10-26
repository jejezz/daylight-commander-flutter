import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _treeDockOpenKey = 'tree_dock_open';
const _treeDockWidthKey = 'tree_dock_width';

const double treeDockMinWidth = 160;
const double treeDockMaxWidth = 420;
const double treeDockDefaultWidth = 220;

/// 도킹된 디렉토리 트리 패널의 열림 상태와 폭.
class TreeDockState {
  const TreeDockState({this.open = false, this.width = treeDockDefaultWidth});

  final bool open;
  final double width;

  TreeDockState copyWith({bool? open, double? width}) =>
      TreeDockState(open: open ?? this.open, width: width ?? this.width);
}

class TreeDockController extends StateNotifier<TreeDockState> {
  TreeDockController() : super(const TreeDockState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = TreeDockState(
      open: prefs.getBool(_treeDockOpenKey) ?? false,
      width: prefs.getDouble(_treeDockWidthKey) ?? treeDockDefaultWidth,
    );
  }

  Future<void> _persist() async {
    final saved = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_treeDockOpenKey, saved.open);
    await prefs.setDouble(_treeDockWidthKey, saved.width);
  }

  void toggle() {
    state = state.copyWith(open: !state.open);
    _persist();
  }

  void setWidth(double width) {
    state = state.copyWith(width: width.clamp(treeDockMinWidth, treeDockMaxWidth));
    _persist();
  }
}

final treeDockProvider = StateNotifierProvider<TreeDockController, TreeDockState>(
  (ref) => TreeDockController(),
);
