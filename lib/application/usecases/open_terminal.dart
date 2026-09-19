import 'dart:io';

/// 현재 패널 경로에서 터미널을 연다.
///
/// 모두 `Process.start`(비동기 fork, 종료를 기다리지 않음)를 쓴다 — 터미널
/// 창은 사용자가 닫을 때까지 떠 있으므로 `Process.run`으로 기다리면 앱이
/// 멈춘 것처럼 보인다.
class OpenTerminal {
  const OpenTerminal();

  Future<void> call(String path) async {
    if (Platform.isMacOS) {
      await Process.start('open', ['-a', 'Terminal', path]);
      return;
    }
    if (Platform.isWindows) {
      try {
        await Process.start('wt.exe', ['-d', path]);
        return;
      } on ProcessException {
        // Windows Terminal 없음 — cmd로 폴백.
      }
      await Process.start('cmd.exe', ['/c', 'start', 'cmd.exe', '/K', 'cd /d "$path"']);
      return;
    }
    if (Platform.isLinux) {
      final candidates = <List<String>>[
        ['gnome-terminal', '--working-directory=$path'],
        ['konsole', '--workdir', path],
        ['xfce4-terminal', '--working-directory=$path'],
      ];
      for (final args in candidates) {
        try {
          await Process.start(args.first, args.sublist(1));
          return;
        } on ProcessException {
          continue;
        }
      }
      try {
        await Process.start('xterm', ['-e', 'cd "$path" && exec \$SHELL']);
      } on ProcessException {
        // 사용 가능한 터미널 에뮬레이터를 찾지 못함 — 조용히 포기.
      }
    }
  }
}
