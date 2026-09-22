import 'dart:io';

/// OS 파일 관리자(Finder/탐색기/파일 관리자)에서 [path]를 그 부모 폴더 안에
/// 선택된 상태로 연다. 앱 안에서 파일 목록 밖으로 드래그 아웃하는 기능이
/// 아직 없어서, 대신 실제 OS 파일 관리자로 보내 거기서 직접 드래그하게
/// 하기 위한 우회 수단이다.
class RevealInFileManager {
  const RevealInFileManager();

  Future<void> call(String path) async {
    if (Platform.isMacOS) {
      await Process.start('open', ['-R', path]);
      return;
    }
    if (Platform.isWindows) {
      // 콤마와 경로 사이에 공백이 없어야 한다 — 셸을 거치지 않고 인자
      // 배열로 바로 넘기므로 따옴표는 따로 붙이지 않는다.
      await Process.start('explorer.exe', ['/select,$path']);
      return;
    }
    if (Platform.isLinux) {
      // 파일 관리자마다 "선택해서 열기" 플래그가 달라 몇 가지를 순서대로
      // 시도하고, 전부 없으면 최소한 부모 폴더라도 열어준다.
      final candidates = <List<String>>[
        ['nautilus', '--select', path],
        ['dolphin', '--select', path],
        ['nemo', path],
      ];
      for (final args in candidates) {
        try {
          await Process.start(args.first, args.sublist(1));
          return;
        } on ProcessException {
          continue;
        }
      }
      final parent = File(path).parent.path;
      try {
        await Process.start('xdg-open', [parent]);
      } on ProcessException {
        // 사용 가능한 파일 관리자를 찾지 못함 — 조용히 포기.
      }
    }
  }
}
