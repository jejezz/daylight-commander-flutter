import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'font_scale';

/// 고를 수 있는 글자 크기 배율: 작게 · 보통 · 크게. 앱 바의 체크 팝업 메뉴가 쓴다.
const fontScaleChoices = [0.9, 1.0, 1.15];

class FontScaleController extends StateNotifier<double> {
  FontScaleController() : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKey);
    if (saved != null && fontScaleChoices.contains(saved)) {
      state = saved;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, state);
  }

  Future<void> setScale(double scale) async {
    if (!fontScaleChoices.contains(scale)) return;
    state = scale;
    await _persist();
  }
}

final fontScaleProvider = StateNotifierProvider<FontScaleController, double>(
  (ref) => FontScaleController(),
);
