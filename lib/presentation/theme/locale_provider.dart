import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'app_locale';

/// 앱바의 언어 토글 버튼이 순환시키는 순서: 시스템 따라가기 → 한국어 고정
/// → 영어 고정 → (다시) 시스템 따라가기. [ThemeModeController]와 같은 패턴.
///
/// state가 null이면 시스템 로케일을 따른다(지원하지 않는 언어면
/// MaterialApp의 localeResolutionCallback이 영어로 폴백한다).
class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _load();
  }

  static const _cycleOrder = <Locale?>[null, Locale('ko'), Locale('en')];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    state = saved == null ? null : Locale(saved);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = state;
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }

  Future<void> cycle() async {
    final currentIndex = _cycleOrder.indexWhere((l) => l?.languageCode == state?.languageCode);
    state = _cycleOrder[(currentIndex + 1) % _cycleOrder.length];
    await _persist();
  }
}

final localeProvider = StateNotifierProvider<LocaleController, Locale?>(
  (ref) => LocaleController(),
);
