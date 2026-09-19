/// 저장된 FTP 서버 정보. 호스트/포트/사용자명만 저장하고 비밀번호는 절대
/// 담지 않는다 (SMB의 [NetworkProfile]과 같은 원칙 — ARCHITECTURE.md 4장).
class FtpProfile {
  const FtpProfile({required this.host, required this.port, required this.username});

  final String host;
  final int port;
  final String username;

  Map<String, dynamic> toJson() => {'host': host, 'port': port, 'username': username};

  factory FtpProfile.fromJson(Map<String, dynamic> json) => FtpProfile(
        host: json['host'] as String,
        port: json['port'] as int? ?? 21,
        username: json['username'] as String? ?? 'anonymous',
      );
}
