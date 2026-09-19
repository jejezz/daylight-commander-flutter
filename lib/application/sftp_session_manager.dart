import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 연결된 SFTP 세션(SSH 소켓)을 관리한다. [FtpSessionManager]와 같은 원칙 —
/// 비밀번호는 연결에만 쓰이고 어디에도 저장하지 않는다.
///
/// state는 연결된 세션 키 목록만 노출한다. 실제 [SftpClient]는 내부에서만
/// 들고 있는다. 호스트 키 검증은 하지 않는다(FTP도 평문 전송이라 이 앱의
/// 보안 수준은 이미 그 이하 — MITM 방어는 범위 밖).
class SftpSessionManager extends StateNotifier<List<String>> {
  SftpSessionManager() : super(const []);

  final Map<String, SSHClient> _sshClients = {};
  final Map<String, SftpClient> _sftpClients = {};

  static String keyFor({required String host, required int port, required String username}) =>
      '$username@$host:$port';

  static String keyForUri(Uri uri) => keyFor(
        host: uri.host,
        port: uri.hasPort ? uri.port : 22,
        username: uri.userInfo,
      );

  bool isConnected(String key) => _sftpClients.containsKey(key);

  SftpClient? clientForUri(Uri uri) => _sftpClients[keyForUri(uri)];

  Future<String> connect({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    final key = keyFor(host: host, port: port, username: username);
    if (_sftpClients.containsKey(key)) return key;

    final socket = await SSHSocket.connect(host, port);
    final ssh = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
    );
    final sftp = await ssh.sftp();
    _sshClients[key] = ssh;
    _sftpClients[key] = sftp;
    state = [...state, key];
    return key;
  }

  Future<void> disconnect(String key) async {
    _sftpClients.remove(key);
    final ssh = _sshClients.remove(key);
    ssh?.close();
    state = state.where((k) => k != key).toList();
  }
}

final sftpSessionManagerProvider =
    StateNotifierProvider<SftpSessionManager, List<String>>(
  (ref) => SftpSessionManager(),
);
