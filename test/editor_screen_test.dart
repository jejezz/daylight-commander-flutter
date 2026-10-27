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
  setUp(() => dir = Directory.systemTemp.createTempSync('editor_screen_'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('열면 본문·상태 바가 보이고 수정 전에는 저장이 꺼져 있다', (tester) async {
    final path = '${dir.path}/a.dart';
    File(path).writeAsStringSync('void main() {}\r\n');
    final file = (await tester.runAsync(() => loadEditorTextFile(path)))!.file!;

    await tester.pumpWidget(_wrap(EditorScreen(path: path, name: 'a.dart', file: file, autofocus: false)));
    await tester.pump();

    expect(find.text('a.dart'), findsOneWidget);
    expect(find.textContaining('dart  ·  UTF-8  ·  CRLF'), findsOneWidget);
    final save = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.save_outlined));
    expect(save.onPressed, isNull);

    // 편집기 안의 타이머가 남지 않게 화면을 내리고 시간을 흘린다.
  });

  // EditorScreen의 수정됨 표시는 "글자가 바뀌면 codeLines 객체가 바뀐다"는 가정에 기댄다.
  test('글자를 바꾸면 codeLines가 새 객체가 되고 커서만 옮기면 그대로다', () {
    final controller = CodeLineEditingController.fromText('abc\ndef');
    final before = controller.codeLines;
    controller.selection = const CodeLineSelection.collapsed(index: 1, offset: 2);
    expect(identical(controller.codeLines, before), isTrue);
    controller.replaceSelection('X');
    expect(identical(controller.codeLines, before), isFalse);
    expect(controller.text, 'abc\ndeXf');
    controller.dispose();
  });
}
