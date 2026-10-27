import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:daylight_commander/application/editor/text_file.dart';
import 'package:daylight_commander/presentation/editor/editor_languages.dart';

final _now = DateTime(2026, 1, 1);

EditorLoadResult _decode(List<int> bytes) =>
    decodeEditorBytes(Uint8List.fromList(bytes), modified: _now);

void main() {
  group('decodeEditorBytes', () {
    test('UTF-8 본문과 LF를 읽는다', () {
      final file = _decode(utf8.encode('가나\n다라\n')).file!;
      expect(file.text, '가나\n다라\n');
      expect(file.hasBom, isFalse);
      expect(file.lineBreak, '\n');
    });

    test('BOM을 떼어 내고 기억한다', () {
      final file = _decode([0xEF, 0xBB, 0xBF, ...utf8.encode('a')]).file!;
      expect(file.text, 'a');
      expect(file.hasBom, isTrue);
    });

    test('CRLF가 많으면 CRLF, 섞이면 많은 쪽', () {
      expect(detectLineBreak('a\r\nb\r\nc\n'), '\r\n');
      expect(detectLineBreak('a\nb\nc\r\n'), '\n');
      expect(detectLineBreak('한 줄'), '\n');
    });

    test('NUL이 있으면 바이너리로 열되 읽기 전용 표시를 한다', () {
      final file = _decode([0x41, 0x00, 0x42]).file!;
      expect(file.binary, isTrue);
      expect(file.text, 'A\u0000B');
    });

    test('UTF-8이 아니면 바이트 값 그대로(Latin-1) 연다', () {
      final file = _decode([0xB0, 0xA1, 0xB3, 0xAA]).file!;
      expect(file.binary, isTrue);
      expect(file.text.codeUnits, [0xB0, 0xA1, 0xB3, 0xAA]);
    });

    test('일반 텍스트는 바이너리가 아니다', () {
      expect(_decode(utf8.encode('가나다')).file!.binary, isFalse);
    });

    test('5MB를 넘으면 거부한다', () {
      final big = Uint8List(editorMaxBytes + 1)..fillRange(0, editorMaxBytes + 1, 0x61);
      expect(_decode(big).failure, EditorLoadFailure.tooLarge);
    });
  });

  test('encodeEditorText는 BOM을 되돌린다', () {
    expect(encodeEditorText('a', hasBom: false), [0x61]);
    expect(encodeEditorText('a', hasBom: true), [0xEF, 0xBB, 0xBF, 0x61]);
  });

  group('파일 저장', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('editor_text_file_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('저장하면 기준값이 갱신되어 외부 변경으로 보지 않는다', () async {
      final path = '${dir.path}/a.txt';
      File(path).writeAsStringSync('old\r\n');
      final opened = (await loadEditorTextFile(path)).file!;
      expect(await changedOnDisk(path, opened), isFalse);

      final saved = await saveEditorText(path, 'new\r\n', opened: opened);
      expect(File(path).readAsStringSync(), 'new\r\n');
      expect(await changedOnDisk(path, saved), isFalse);
    });

    test('다른 경로로 저장하면 그 파일이 새 기준값이 된다', () async {
      final path = '${dir.path}/a.txt';
      File(path).writeAsStringSync('old\n');
      final opened = (await loadEditorTextFile(path)).file!;
      final other = '${dir.path}/b.txt';

      final saved = await saveEditorText(other, 'copy\n', opened: opened);
      expect(File(other).readAsStringSync(), 'copy\n');
      expect(File(path).readAsStringSync(), 'old\n');
      expect(await changedOnDisk(other, saved), isFalse);
    });

    test('다른 곳에서 바뀌면 외부 변경으로 본다', () async {
      final path = '${dir.path}/a.txt';
      File(path).writeAsStringSync('old');
      final opened = (await loadEditorTextFile(path)).file!;
      File(path).writeAsStringSync('changed elsewhere');
      expect(await changedOnDisk(path, opened), isTrue);
    });
  });

  group('editorLanguageFor', () {
    test('확장자와 대체 문법', () {
      expect(editorLanguageFor('main.dart'), 'dart');
      expect(editorLanguageFor('Config.TOML'), 'ini');
      expect(editorLanguageFor('index.html'), 'xml');
      expect(editorLanguageFor('run.ps1'), 'powershell');
    });

    test('이름으로 정하는 파일과 모르는 형식', () {
      expect(editorLanguageFor('Dockerfile'), 'dockerfile');
      expect(editorLanguageFor('.env'), 'properties');
      expect(editorLanguageFor('data.csv'), 'plaintext');
      expect(editorLanguageFor('README'), 'plaintext');
    });

    test('모든 문법 키에 규칙이 있다', () {
      for (final name in ['a.dart', 'a.json', 'a.sql', 'a.md', 'a.yaml', 'a.rs', 'a.go']) {
        expect(editorModeFor(editorLanguageFor(name)), isNotNull);
      }
    });
  });
}
