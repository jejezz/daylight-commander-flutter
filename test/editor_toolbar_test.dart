import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/application/editor/text_file.dart';
import 'package:daylight_commander/l10n/app_localizations.dart';
import 'package:daylight_commander/presentation/editor/editor_languages.dart';
import 'package:daylight_commander/presentation/editor/editor_screen.dart';
import 'package:daylight_commander/presentation/editor/editor_shortcuts.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: child,
);

void main() {
  late Directory dir;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('editor_toolbar_');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<EditorTextFile> load(WidgetTester tester, String path) async =>
      (await tester.runAsync(() => loadEditorTextFile(path)))!.file!;

  testWidgets('툴바에 도구 아이콘이 모두 있고 단축키 안내가 처음에는 열려 있다', (tester) async {
    final path = '${dir.path}/a.dart';
    File(path).writeAsStringSync('void main() {}\n');
    final file = await load(tester, path);
    await tester.pumpWidget(
      _wrap(
        EditorScreen(path: path, name: 'a.dart', file: file, autofocus: false),
      ),
    );
    await tester.pump();

    for (final icon in [
      Icons.undo,
      Icons.redo,
      Icons.search,
      Icons.find_replace,
      Icons.format_list_numbered,
      Icons.wrap_text,
      Icons.save_as_outlined,
      Icons.save_outlined,
      Icons.help_outline,
    ]) {
      expect(find.byIcon(icon), findsOneWidget, reason: '$icon');
    }
    // 마크다운이 아니면 미리보기 버튼이 없다.
    expect(find.byIcon(Icons.chrome_reader_mode_outlined), findsNothing);
    expect(find.text('Keyboard shortcuts'), findsNothing); // 제목 문구가 아니라 툴팁이다
    expect(find.text('Undo'), findsOneWidget); // 안내 패널의 항목
    expect(find.text('Toggle line comment'), findsOneWidget);
  });

  testWidgets('X로 단축키 안내를 닫으면 기억되고, ? 버튼으로 다시 연다', (tester) async {
    final path = '${dir.path}/a.dart';
    File(path).writeAsStringSync('x\n');
    final file = await load(tester, path);
    await tester.pumpWidget(
      _wrap(
        EditorScreen(path: path, name: 'a.dart', file: file, autofocus: false),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('editor-shortcuts-close')));
    await tester.pump();
    expect(find.text('Toggle line comment'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'editor_shortcuts_visible',
      ),
      isFalse,
    );

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pump();
    expect(find.text('Toggle line comment'), findsOneWidget);
  });

  testWidgets('마크다운이면 미리보기 버튼이 있고 기본으로 렌더링된 글이 보인다', (tester) async {
    final path = '${dir.path}/a.md';
    File(path).writeAsStringSync('# 제목\n\n본문 **굵게**\n');
    final file = await load(tester, path);
    await tester.pumpWidget(
      _wrap(
        EditorScreen(path: path, name: 'a.md', file: file, autofocus: false),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.chrome_reader_mode_outlined), findsOneWidget);
    expect(find.text('Markdown preview'), findsOneWidget); // 안내 패널 항목(마크다운에서만)
    expect(find.textContaining('제목', findRichText: true), findsWidgets);

    // 미리보기는 렌더링된 마크다운(SelectableText)이다. 켜고 끄는 버튼은 포커스를 편집기로 옮기는데,
    // 포커스를 가진 채 사라지는 re_editor가 커서 깜박임 타이머를 남겨 테스트에서는 누르지 않는다.
    expect(find.byType(SelectableText), findsWidgets);
  });

  test('주석 토글 규칙: 언어별로 있고 없는 형식은 null', () {
    expect(editorCommentFormatterFor('dart'), isNotNull);
    expect(editorCommentFormatterFor('python'), isNotNull);
    expect(editorCommentFormatterFor('xml'), isNotNull);
    expect(editorCommentFormatterFor('json'), isNull);
    expect(editorCommentFormatterFor('plaintext'), isNull);
  });

  test('단축키 표기는 플랫폼에 맞는다', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(editorKeys('S', primary: true, shift: true), '⇧⌘S');
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(editorKeys('S', primary: true, shift: true), 'Ctrl+Shift+S');
    expect(editorKeys('F', primary: true, alt: true), 'Ctrl+Alt+F');
    debugDefaultTargetPlatformOverride = null;
  });
}
