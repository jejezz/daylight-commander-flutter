import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'package:daylight_commander/application/editor/text_file.dart';
import 'package:daylight_commander/l10n/app_localizations.dart';
import 'package:daylight_commander/presentation/editor/editor_screen.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('editor_save_as_'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('다른 이름으로 저장하면 새 파일에 쓰고 원본은 그대로 둔다', (tester) async {
    final path = '${dir.path}/a.dart';
    File(path).writeAsStringSync('void main() {}\n');
    final file = (await tester.runAsync(() => loadEditorTextFile(path)))!.file!;
    await tester.pumpWidget(_wrap(EditorScreen(path: path, name: 'a.dart', file: file, autofocus: false)));
    await tester.pump();
    tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.replaceSelection('X');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.save_as_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 파일명 부분만 바꿔 입력하면 같은 폴더에 저장된다.
    await tester.enterText(find.byType(TextField).last, 'copy.py');
    // 저장은 실제 파일 I/O다. flutter test의 FakeAsync 안에서 시작된 I/O 뒤처리는 pump만으로는
    // 끝나지 않으므로 탭 자체를 runAsync 안에서 하고 진짜 시간을 흘리며 pump한다.
    final copy = File('${dir.path}/copy.py');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save').last);
      for (var i = 0; i < 40 && !(copy.existsSync() && copy.lengthSync() > 0); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      // 쓰기 뒤의 stat·setState까지 끝나도록 한 번 더 흘린다.
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pump(const Duration(milliseconds: 400));

    expect(File('${dir.path}/copy.py').readAsStringSync(), 'Xvoid main() {}\n');
    expect(File(path).readAsStringSync(), 'void main() {}\n');
    expect(tester.takeException(), isNull);
  });

  testWidgets('바이너리는 읽기 전용이라 저장 버튼이 모두 꺼진다', (tester) async {
    final path = '${dir.path}/b.dat';
    File(path).writeAsBytesSync([0x41, 0x00, 0xff, 0x42]);
    final file = (await tester.runAsync(() => loadEditorTextFile(path)))!.file!;
    expect(file.binary, isTrue);
    await tester.pumpWidget(_wrap(EditorScreen(path: path, name: 'b.dat', file: file, autofocus: false)));
    await tester.pump();

    for (final icon in [Icons.save_as_outlined, Icons.save_outlined]) {
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon)).onPressed, isNull);
    }
    expect(find.textContaining('read-only'), findsOneWidget);
  });
}
