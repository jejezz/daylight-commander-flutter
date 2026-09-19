import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// 연결된 WebDAV 세션(HTTP 클라이언트)을 관리한다. [FtpSessionManager]와 같은
/// 원칙 — 비밀번호는 연결에만 쓰이고 어디에도 저장하지 않는다.
///
/// 패널 경로는 `webdav://`(HTTP)/`webdavs://`(HTTPS) 두 스킴으로 구분하므로
/// 세션 키에도 보안 여부를 포함한다 — 같은 호스트라도 http/https는 다른
/// 세션으로 취급.
class WebdavSessionManager extends StateNotifier<List<String>> {
  WebdavSessionManager() : super(const []);

  final Map<String, webdav.Client> _clients = {};

  static String keyFor({
    required bool secure,
    required String host,
    required int port,
    required String username,
  }) =>
      '$username@$host:$port${secure ? '(https)' : '(http)'}';

  static String keyForUri(Uri uri) {
    final secure = uri.scheme == 'webdavs';
    return keyFor(
      secure: secure,
      host: uri.host,
      port: uri.hasPort ? uri.port : (secure ? 443 : 80),
      username: uri.userInfo,
    );
  }

  bool isConnected(String key) => _clients.containsKey(key);

  webdav.Client? clientForUri(Uri uri) => _clients[keyForUri(uri)];

  Future<String> connect({
    required String host,
    required int port,
    required String username,
    required String password,
    required bool secure,
  }) async {
    final key = keyFor(secure: secure, host: host, port: port, username: username);
    if (_clients.containsKey(key)) return key;

    final baseUrl = '${secure ? 'https' : 'http'}://$host:$port';
    final client = webdav.newClient(baseUrl, user: username, password: password);
    await client.ping();
    _clients[key] = client;
    state = [...state, key];
    return key;
  }

  Future<void> disconnect(String key) async {
    _clients.remove(key);
    state = state.where((k) => k != key).toList();
  }
}

final webdavSessionManagerProvider =
    StateNotifierProvider<WebdavSessionManager, List<String>>(
  (ref) => WebdavSessionManager(),
);
