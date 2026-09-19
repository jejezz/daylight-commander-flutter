import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'bookmarks';

/// 즐겨찾기 경로 목록. 경로 문자열만 저장한다 (자격증명 아님 — `flutter_secure_storage`가
/// 필요 없는 이유).
class BookmarksController extends StateNotifier<List<String>> {
  BookmarksController() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefsKey) ?? const [];
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state);
  }

  bool contains(String path) => state.contains(path);

  Future<void> toggle(String path) async {
    if (state.contains(path)) {
      state = state.where((p) => p != path).toList();
    } else {
      state = [...state, path];
    }
    await _persist();
  }

  Future<void> remove(String path) async {
    state = state.where((p) => p != path).toList();
    await _persist();
  }
}

final bookmarksProvider = StateNotifierProvider<BookmarksController, List<String>>(
  (ref) => BookmarksController(),
);
