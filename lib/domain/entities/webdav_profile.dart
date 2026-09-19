/// 저장된 WebDAV 서버 정보. [FtpProfile]과 같은 원칙 — 호스트/포트/사용자명/
/// HTTPS 여부만 저장하고 비밀번호는 절대 담지 않는다.
class WebdavProfile {
  const WebdavProfile({
    required this.host,
    required this.port,
    required this.username,
    required this.useHttps,
  });

  final String host;
  final int port;
  final String username;
  final bool useHttps;

  Map<String, dynamic> toJson() =>
      {'host': host, 'port': port, 'username': username, 'useHttps': useHttps};

  factory WebdavProfile.fromJson(Map<String, dynamic> json) => WebdavProfile(
        host: json['host'] as String,
        port: json['port'] as int? ?? 443,
        username: json['username'] as String? ?? '',
        useHttps: json['useHttps'] as bool? ?? true,
      );
}
