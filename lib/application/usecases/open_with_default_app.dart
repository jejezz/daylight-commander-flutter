import 'dart:io';

/// 파일을 OS가 확장자에 연결해 둔 기본 앱으로 연다 (Finder/Explorer의
/// 더블클릭과 동일한 동작).
class OpenWithDefaultApp {
  const OpenWithDefaultApp();

  Future<void> call(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
      return;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }
}
