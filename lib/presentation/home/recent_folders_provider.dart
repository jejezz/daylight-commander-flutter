import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'recent_folders';
const _maxEntries = 15;

/// 뒤로/앞으로 히스토리와 별개로, 최근 방문한 폴더를 최신순으로 모아두는
/// 점프리스트 (PLAN.md P1).
class RecentFoldersController extends StateNotifier<List<String>> {
  RecentFoldersController() : super(const []) {
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

  Future<void> record(String path) async {
    final next = [path, ...state.where((p) => p != path)];
    state = next.length > _maxEntries ? next.sublist(0, _maxEntries) : next;
    await _persist();
  }
}

final recentFoldersProvider =
    StateNotifierProvider<RecentFoldersController, List<String>>(
  (ref) => RecentFoldersController(),
);
