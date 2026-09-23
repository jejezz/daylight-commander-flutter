import 'dart:io';

import 'package:daylight_commander/application/usecases/clipboard_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// 실제 OS 클립보드를 건드리는 왕복 테스트라 macOS에서만 돈다(CI의 Linux에는
// xclip/디스플레이가 없을 수 있다).
void main() {
  test(
    'macOS: 여러 파일(공백·한글 경로 포함)을 클립보드에 올리고 그대로 읽어온다',
    () async {
      final dir = await Directory.systemTemp.createTemp('clipboard_files_test');
      addTearDown(() => dir.delete(recursive: true));
      final paths = [
        for (final name in ['a.txt', 'b 한글 "따옴표".txt'])
          (await File(p.join(dir.path, name)).writeAsString('x')).path,
      ];

      const clipboard = ClipboardFiles();
      await clipboard.writeFiles(paths);
      final read = await clipboard.readFiles();

      expect(read.map((e) => File(e).resolveSymbolicLinksSync()),
          paths.map((e) => File(e).resolveSymbolicLinksSync()));
    },
    skip: !Platform.isMacOS,
  );
}
