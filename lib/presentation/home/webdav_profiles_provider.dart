import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/webdav_profile.dart';

const _prefsKey = 'webdav_profiles';

class WebdavProfilesController extends StateNotifier<List<WebdavProfile>> {
  WebdavProfilesController() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    state = list.map(WebdavProfile.fromJson).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> add(WebdavProfile profile) async {
    if (state.any((p) =>
        p.host == profile.host && p.port == profile.port && p.username == profile.username)) {
      return;
    }
    state = [...state, profile];
    await _persist();
  }

  Future<void> remove(WebdavProfile profile) async {
    state = state
        .where((p) =>
            !(p.host == profile.host && p.port == profile.port && p.username == profile.username))
        .toList();
    await _persist();
  }
}

final webdavProfilesProvider =
    StateNotifierProvider<WebdavProfilesController, List<WebdavProfile>>(
  (ref) => WebdavProfilesController(),
);
