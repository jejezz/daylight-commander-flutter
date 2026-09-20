import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'font_scale';

/// 앱바의 글자 크기 토글 버튼이 순환시키는 순서: 보통(1.0) → 크게(1.15) →
/// 작게(0.9) → (다시) 보통. [ThemeModeController]와 같은 패턴.
const _cycleOrder = [1.0, 1.15, 0.9];

class FontScaleController extends StateNotifier<double> {
  FontScaleController() : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKey);
    if (saved != null && _cycleOrder.contains(saved)) {
      state = saved;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, state);
  }

  Future<void> cycle() async {
    final next = _cycleOrder[(_cycleOrder.indexOf(state) + 1) % _cycleOrder.length];
    state = next;
    await _persist();
  }
}

final fontScaleProvider = StateNotifierProvider<FontScaleController, double>(
  (ref) => FontScaleController(),
);
