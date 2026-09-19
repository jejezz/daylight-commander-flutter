import 'package:ftpconnect/ftpconnect.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 연결된 FTP 세션(소켓)을 관리한다. 비밀번호는 연결에만 쓰이고 어디에도
/// 저장하지 않는다 — 연결이 끊기면 다시 물어봐야 한다 (ARCHITECTURE.md 4장).
///
/// state는 연결된 세션 키 목록만 노출한다(UI가 "연결됨" 표시를 반응형으로
/// 그릴 수 있게). 실제 [FTPConnect] 인스턴스는 내부에서만 들고 있는다.
class FtpSessionManager extends StateNotifier<List<String>> {
  FtpSessionManager() : super(const []);

  final Map<String, FTPConnect> _clients = {};

  static String keyFor({required String host, required int port, required String username}) =>
      '${username.isEmpty ? 'anonymous' : username}@$host:$port';

  static String keyForUri(Uri uri) => keyFor(
        host: uri.host,
        port: uri.hasPort ? uri.port : 21,
        username: uri.userInfo,
      );

  bool isConnected(String key) => _clients.containsKey(key);

  FTPConnect? clientForUri(Uri uri) => _clients[keyForUri(uri)];

  Future<String> connect({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    final key = keyFor(host: host, port: port, username: username);
    if (_clients.containsKey(key)) return key;

    final client = FTPConnect(
      host,
      port: port,
      user: username.isEmpty ? 'anonymous' : username,
      pass: password,
    );
    final ok = await client.connect();
    if (!ok) {
      throw StateError('FTP 서버에 연결할 수 없습니다: $host:$port');
    }
    _clients[key] = client;
    state = [...state, key];
    return key;
  }

  Future<void> disconnect(String key) async {
    final client = _clients.remove(key);
    if (client != null) {
      try {
        await client.disconnect();
      } catch (_) {
        // 이미 끊긴 연결일 수 있음 — 무시.
      }
    }
    state = state.where((k) => k != key).toList();
  }
}

final ftpSessionManagerProvider =
    StateNotifierProvider<FtpSessionManager, List<String>>(
  (ref) => FtpSessionManager(),
);
