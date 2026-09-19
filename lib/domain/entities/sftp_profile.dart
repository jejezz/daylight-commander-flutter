/// 저장된 SFTP 서버 정보. [FtpProfile]과 같은 원칙 — 호스트/포트/사용자명만
/// 저장하고 비밀번호는 절대 담지 않는다.
class SftpProfile {
  const SftpProfile({required this.host, required this.port, required this.username});

  final String host;
  final int port;
  final String username;

  Map<String, dynamic> toJson() => {'host': host, 'port': port, 'username': username};

  factory SftpProfile.fromJson(Map<String, dynamic> json) => SftpProfile(
        host: json['host'] as String,
        port: json['port'] as int? ?? 22,
        username: json['username'] as String? ?? '',
      );
}
