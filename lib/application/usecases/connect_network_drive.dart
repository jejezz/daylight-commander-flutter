import 'dart:io';

/// SMB 서버 연결을 OS 자체 마운트 기능에 위임한다 (ARCHITECTURE.md 4장 — 확정
/// A안). 호스트/공유명만 받고 자격증명은 절대 다루지 않는다 — 비밀번호 입력은
/// OS가 띄우는 신뢰된 다이얼로그(Finder "서버에 연결", Windows 자격 증명 대화상자
/// 등)에서 사용자가 직접 입력한다. 마운트가 끝나면 해당 볼륨은 `/Volumes`(macOS)
/// 등에 나타나 [ListDrives]에 자동으로 포함된다.
class ConnectNetworkDrive {
  const ConnectNetworkDrive();

  Future<void> call({required String host, String? share}) async {
    final trimmedHost = host.trim();
    final trimmedShare = share?.trim() ?? '';
    final path = trimmedShare.isEmpty ? trimmedHost : '$trimmedHost/$trimmedShare';
    final smbUri = 'smb://$path';

    if (Platform.isMacOS) {
      await Process.run('open', [smbUri]);
      return;
    }
    if (Platform.isLinux) {
      try {
        final result = await Process.run('gio', ['mount', smbUri]);
        if (result.exitCode == 0) return;
      } on ProcessException {
        // gio 없음 — 데스크톱 기본 핸들러로 폴백.
      }
      await Process.run('xdg-open', [smbUri]);
      return;
    }
    if (Platform.isWindows) {
      final unc = trimmedShare.isEmpty
          ? '\\\\$trimmedHost'
          : '\\\\$trimmedHost\\$trimmedShare';
      await Process.run('explorer.exe', [unc]);
      return;
    }
  }
}
