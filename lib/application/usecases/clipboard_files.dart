import 'dart:io';

/// 로컬 파일 목록을 OS 클립보드에 "복사한 파일"로 올리고, 반대로 OS
/// 클립보드에 있는 파일 목록을 읽어온다. Finder/탐색기의 Ctrl+C/Ctrl+V와
/// 상호 호환되도록 각 OS의 네이티브 파일 클립보드 포맷을 쓴다 — 추가
/// 네이티브 플러그인 없이 이미 설치돼 있는 OS 도구(PowerShell/osascript/
/// xclip)를 셸로 호출하는 방식이라, 드래그 아웃 PoC가 일으켰던 것과 같은
/// 네이티브 플러그인 회귀 위험이 없다.
class ClipboardFiles {
  const ClipboardFiles();

  Future<void> writeFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    if (Platform.isWindows) {
      await _writeWindows(paths);
    } else if (Platform.isMacOS) {
      await _writeMacOS(paths);
    } else if (Platform.isLinux) {
      await _writeLinux(paths);
    }
  }

  /// 읽어올 수 없으면(클립보드가 비었거나, 파일이 아니거나, 도구가 없으면)
  /// 빈 리스트를 돌려준다.
  Future<List<String>> readFiles() async {
    if (Platform.isWindows) return _readWindows();
    if (Platform.isMacOS) return _readMacOS();
    if (Platform.isLinux) return _readLinux();
    return const [];
  }

  // --- Windows: PowerShell의 Set-Clipboard/Get-Clipboard -Format FileDropList
  // 는 탐색기가 이해하는 진짜 CF_HDROP 형식으로 읽고 쓴다. ---

  static String _psSingleQuote(String path) => "'${path.replaceAll("'", "''")}'";

  Future<void> _writeWindows(List<String> paths) async {
    final list = paths.map(_psSingleQuote).join(',');
    await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      'Set-Clipboard -Path $list',
    ]);
  }

  Future<List<String>> _readWindows() async {
    const script = r'''
$items = Get-Clipboard -Format FileDropList
if ($items) {
  foreach ($item in $items) {
    if ($item -is [System.IO.FileSystemInfo]) { $item.FullName } else { $item }
  }
}
''';
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
    );
    if (result.exitCode != 0) return const [];
    final out = result.stdout;
    if (out is! String) return const [];
    return out
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  // --- macOS: osascript의 JavaScript(JXA) ObjC 브리지로 NSPasteboard에
  // 파일 URL을 직접 읽고 쓴다. AppleScript의 `set the clipboard to {...}`는
  // 여러 개를 올리면 Finder가 붙여넣지 못하는 AppleScript list 형식이 되고,
  // 읽기도 첫 항목만 돌려줘서 다중 파일이 깨졌다. 경로는 스크립트에 끼워
  // 넣지 않고 argv로 넘겨 이스케이프 문제를 없앤다. ---

  static const _macWriteScript = r"""
ObjC.import('AppKit');
function run(argv) {
  const pb = $.NSPasteboard.generalPasteboard;
  pb.clearContents;
  pb.writeObjects($(argv.map(p => $.NSURL.fileURLWithPath(p))));
  // 바로 종료하면 pasteboard 서버에 마지막 항목이 전달되기 전에 연결이
  // 끊겨 여러 개 중 끝의 하나가 빠지는 일이 재현됐다 — 잠깐 기다린다.
  delay(0.2);
}
""";

  static const _macReadScript = r"""
ObjC.import('AppKit');
function run() {
  const options = $.NSDictionary.dictionaryWithObjectForKey(
    $.NSNumber.numberWithBool(true), $.NSPasteboardURLReadingFileURLsOnlyKey);
  const urls = $.NSPasteboard.generalPasteboard.readObjectsForClassesOptions(
    $.NSArray.arrayWithObject($.NSURL), options);
  if (!urls || urls.isNil()) return '';
  const paths = [];
  for (let i = 0; i < urls.count; i++) paths.push(urls.objectAtIndex(i).path.js);
  return paths.join('\n');
}
""";

  Future<void> _writeMacOS(List<String> paths) async {
    await Process.run('osascript', ['-l', 'JavaScript', '-e', _macWriteScript, ...paths]);
  }

  Future<List<String>> _readMacOS() async {
    final result = await Process.run('osascript', ['-l', 'JavaScript', '-e', _macReadScript]);
    if (result.exitCode != 0) return const [];
    final out = result.stdout;
    if (out is! String) return const [];
    return out.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  }

  // --- Linux: 데스크톱 환경마다 클립보드 파일 규약이 달라(GNOME은
  // x-special/gnome-copied-files, 그 외엔 대체로 text/uri-list) xclip이
  // 있을 때만 두 포맷을 순서대로 시도한다. ---

  Future<void> _writeLinux(List<String> paths) async {
    final payload = StringBuffer('copy\n');
    for (final path in paths) {
      payload.writeln(Uri.file(path).toString());
    }
    try {
      final process = await Process.start(
        'xclip',
        ['-selection', 'clipboard', '-t', 'x-special/gnome-copied-files'],
      );
      process.stdin.write(payload.toString());
      await process.stdin.close();
      await process.exitCode;
    } on ProcessException {
      // xclip 없음 — 조용히 포기.
    }
  }

  Future<List<String>> _readLinux() async {
    for (final mimeType in ['x-special/gnome-copied-files', 'text/uri-list']) {
      try {
        final result = await Process.run(
          'xclip',
          ['-selection', 'clipboard', '-t', mimeType, '-o'],
        );
        if (result.exitCode != 0) continue;
        final out = result.stdout;
        if (out is! String) continue;
        final paths = out
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.startsWith('file://'))
            .map((line) => Uri.parse(line).toFilePath())
            .toList();
        if (paths.isNotEmpty) return paths;
      } on ProcessException {
        continue;
      }
    }
    return const [];
  }
}
