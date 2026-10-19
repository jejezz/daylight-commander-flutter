import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pane_controller.dart';

/// 1패널 모드 저장 키. 시작할 때 창 최소 크기와 도킹 복원을 정하려고 main.dart도 읽는다.
const paneSingleModeKey = 'pane_single_mode';
const _swappedKey = 'pane_swapped';

/// 패널 배치. 패널 상태([PaneSide])는 그대로 두고 화면에 놓이는 방식만 바꾼다.
///
/// - [swapped]: 왼쪽/오른쪽 패널의 화면 위치를 맞바꾼다 (경로·선택은 그대로).
/// - [singlePane]: 활성 패널 하나만 크게 보이고, 다른 패널은 가장자리에 도킹된다.
class PaneLayout {
  const PaneLayout({this.singlePane = false, this.swapped = false});

  final bool singlePane;
  final bool swapped;

  /// 화면에서 왼쪽에 놓이는 패널.
  PaneSide get leftmost => swapped ? PaneSide.right : PaneSide.left;

  PaneLayout copyWith({bool? singlePane, bool? swapped}) =>
      PaneLayout(singlePane: singlePane ?? this.singlePane, swapped: swapped ?? this.swapped);
}

class PaneLayoutController extends StateNotifier<PaneLayout> {
  PaneLayoutController() : super(const PaneLayout()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = PaneLayout(
      singlePane: prefs.getBool(paneSingleModeKey) ?? false,
      swapped: prefs.getBool(_swappedKey) ?? false,
    );
  }

  Future<void> _persist() async {
    final saved = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(paneSingleModeKey, saved.singlePane);
    await prefs.setBool(_swappedKey, saved.swapped);
  }

  void swap() {
    state = state.copyWith(swapped: !state.swapped);
    _persist();
  }

  void toggleSinglePane() {
    state = state.copyWith(singlePane: !state.singlePane);
    _persist();
  }
}

final paneLayoutProvider = StateNotifierProvider<PaneLayoutController, PaneLayout>(
  (ref) => PaneLayoutController(),
);
