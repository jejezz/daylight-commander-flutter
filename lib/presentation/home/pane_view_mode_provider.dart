import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pane_controller.dart';

/// 패널의 파일 목록 표시 방식.
enum PaneViewMode { details, thumbnails }

/// 썸네일 보기의 셀 크기.
enum ThumbnailSize {
  small(88),
  medium(120),
  large(168);

  const ThumbnailSize(this.extent);

  /// 셀 한 변의 최대 폭(논리 픽셀). 패널 폭에 맞춰 열 수가 정해진다.
  final double extent;

  ThumbnailSize get next => values[(index + 1) % values.length];
}

class PaneViewSettings {
  const PaneViewSettings({
    this.mode = PaneViewMode.details,
    this.thumbnailSize = ThumbnailSize.medium,
  });

  final PaneViewMode mode;
  final ThumbnailSize thumbnailSize;

  bool get isThumbnails => mode == PaneViewMode.thumbnails;

  PaneViewSettings copyWith({
    PaneViewMode? mode,
    ThumbnailSize? thumbnailSize,
  }) => PaneViewSettings(
    mode: mode ?? this.mode,
    thumbnailSize: thumbnailSize ?? this.thumbnailSize,
  );
}

/// 패널별 보기 모드. 저장 키는 `pane_view_mode_<side>`, `pane_thumb_size_<side>`.
class PaneViewSettingsController extends StateNotifier<PaneViewSettings> {
  PaneViewSettingsController(this._side) : super(const PaneViewSettings()) {
    _load();
  }

  final PaneSide _side;

  String get _modeKey => 'pane_view_mode_${_side.name}';
  String get _sizeKey => 'pane_thumb_size_${_side.name}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = PaneViewMode.values.asNameMap()[prefs.getString(_modeKey)];
    final size = ThumbnailSize.values.asNameMap()[prefs.getString(_sizeKey)];
    state = PaneViewSettings(
      mode: mode ?? state.mode,
      thumbnailSize: size ?? state.thumbnailSize,
    );
  }

  Future<void> _persist() async {
    final saved = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, saved.mode.name);
    await prefs.setString(_sizeKey, saved.thumbnailSize.name);
  }

  void toggleMode() {
    state = state.copyWith(
      mode: state.isThumbnails ? PaneViewMode.details : PaneViewMode.thumbnails,
    );
    _persist();
  }

  void cycleThumbnailSize() {
    state = state.copyWith(thumbnailSize: state.thumbnailSize.next);
    _persist();
  }
}

final paneViewSettingsProvider =
    StateNotifierProvider.family<
      PaneViewSettingsController,
      PaneViewSettings,
      PaneSide
    >((ref, side) => PaneViewSettingsController(side));

/// 썸네일 그리드가 현재 배치한 열 수. 그리드가 레이아웃 후 기록하고, 키보드
/// 상하 이동(열 수만큼 건너뛰기)이 읽는다.
/// 썸네일 그리드가 한 화면에 보여 주는 행 수. PageUp/PageDown 이동량에 쓴다.
final paneGridPageRowsProvider = StateProvider.family<int, PaneSide>(
  (ref, side) => 5,
);

final paneGridColumnsProvider = StateProvider.family<int, PaneSide>(
  (ref, side) => 1,
);
