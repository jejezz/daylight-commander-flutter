import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/sftp_profile.dart';

const _prefsKey = 'sftp_profiles';

class SftpProfilesController extends StateNotifier<List<SftpProfile>> {
  SftpProfilesController() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    state = list.map(SftpProfile.fromJson).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> add(SftpProfile profile) async {
    if (state.any((p) => p.host == profile.host && p.port == profile.port && p.username == profile.username)) {
      return;
    }
    state = [...state, profile];
    await _persist();
  }

  Future<void> remove(SftpProfile profile) async {
    state = state
        .where((p) => !(p.host == profile.host && p.port == profile.port && p.username == profile.username))
        .toList();
    await _persist();
  }
}

final sftpProfilesProvider = StateNotifierProvider<SftpProfilesController, List<SftpProfile>>(
  (ref) => SftpProfilesController(),
);
