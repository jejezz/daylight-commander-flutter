import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 저장된 SMB 서버 정보. 호스트/공유 이름만 저장하고 자격증명은 절대 담지
/// 않는다 (ARCHITECTURE.md 4장 — 비밀번호는 OS 다이얼로그가 전담).
class NetworkProfile {
  const NetworkProfile({required this.host, required this.share});

  final String host;
  final String share;

  Map<String, String> toJson() => {'host': host, 'share': share};

  factory NetworkProfile.fromJson(Map<String, dynamic> json) => NetworkProfile(
        host: json['host'] as String,
        share: json['share'] as String? ?? '',
      );
}

const _prefsKey = 'network_profiles';

class NetworkProfilesController extends StateNotifier<List<NetworkProfile>> {
  NetworkProfilesController() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    state = list.map(NetworkProfile.fromJson).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> add(String host, String share) async {
    if (state.any((p) => p.host == host && p.share == share)) return;
    state = [...state, NetworkProfile(host: host, share: share)];
    await _persist();
  }

  Future<void> remove(NetworkProfile profile) async {
    state = state
        .where((p) => !(p.host == profile.host && p.share == profile.share))
        .toList();
    await _persist();
  }
}

final networkProfilesProvider =
    StateNotifierProvider<NetworkProfilesController, List<NetworkProfile>>(
  (ref) => NetworkProfilesController(),
);
