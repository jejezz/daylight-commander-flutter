import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 에디터가 한 번에 열 수 있는 파일 크기 상한.
const editorMaxBytes = 5 * 1024 * 1024;

enum EditorLoadFailure { tooLarge }

/// 읽어 들인 텍스트 파일. 저장할 때 BOM과 줄바꿈을 그대로 되돌리려고 함께 들고 있다.
class EditorTextFile {
  const EditorTextFile({
    required this.text,
    required this.hasBom,
    required this.lineBreak,
    required this.modified,
    required this.length,
    this.binary = false,
  });

  /// 줄바꿈을 모두 `\n`으로 정규화한 본문이 아니라 읽은 그대로의 본문이다.
  final String text;
  final bool hasBom;

  /// `\n` 또는 `\r\n`. 섞여 있으면 많은 쪽.
  final String lineBreak;
  final DateTime modified;
  final int length;

  /// 바이너리이거나 UTF-8이 아니라서 바이트를 글자 하나씩(Latin-1) 그대로 보여 주는 파일.
  /// 줄바꿈 정규화와 BOM 처리가 바이트를 바꿀 수 있어 읽기 전용으로만 연다.
  final bool binary;
}

class EditorLoadResult {
  const EditorLoadResult.ok(EditorTextFile this.file) : failure = null;
  const EditorLoadResult.failed(EditorLoadFailure this.failure) : file = null;

  final EditorTextFile? file;
  final EditorLoadFailure? failure;
}

/// 앞 8KB 안에 NUL 바이트가 있으면 바이너리로 본다 (읽기 전용으로 연다).
bool looksBinary(Uint8List bytes) {
  final end = bytes.length < 8192 ? bytes.length : 8192;
  for (var i = 0; i < end; i++) {
    if (bytes[i] == 0) return true;
  }
  return false;
}

/// 본문에서 줄바꿈 종류를 센다. CRLF가 LF 단독보다 많으면 `\r\n`.
String detectLineBreak(String text) {
  var crlf = 0;
  var lf = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) != 0x0A) continue;
    if (i > 0 && text.codeUnitAt(i - 1) == 0x0D) {
      crlf++;
    } else {
      lf++;
    }
  }
  return crlf > lf ? '\r\n' : '\n';
}

EditorLoadResult decodeEditorBytes(
  Uint8List bytes, {
  required DateTime modified,
}) {
  if (bytes.length > editorMaxBytes) {
    return const EditorLoadResult.failed(EditorLoadFailure.tooLarge);
  }
  final hasBom =
      bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
  var binary = looksBinary(bytes);
  String text;
  try {
    text = utf8.decode(hasBom ? bytes.sublist(3) : bytes);
  } on FormatException {
    // UTF-8이 아니면 바이트 값 그대로(0x00–0xFF → 글자 하나) 보여 준다.
    text = latin1.decode(bytes);
    binary = true;
  }
  return EditorLoadResult.ok(EditorTextFile(
    text: text,
    hasBom: hasBom && !binary,
    lineBreak: detectLineBreak(text),
    modified: modified,
    length: bytes.length,
    binary: binary,
  ));
}

Future<EditorLoadResult> loadEditorTextFile(String path) async {
  final file = File(path);
  final stat = await file.stat();
  if (stat.size > editorMaxBytes) {
    return const EditorLoadResult.failed(EditorLoadFailure.tooLarge);
  }
  return decodeEditorBytes(await file.readAsBytes(), modified: stat.modified);
}

/// 저장할 바이트. [text]는 이미 원래 줄바꿈으로 이어 붙인 본문이다.
Uint8List encodeEditorText(String text, {required bool hasBom}) {
  final body = utf8.encode(text);
  if (!hasBom) return Uint8List.fromList(body);
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...body]);
}

/// 열었을 때와 디스크의 수정 시각·크기가 달라졌는가.
Future<bool> changedOnDisk(String path, EditorTextFile opened) async {
  final stat = await File(path).stat();
  if (stat.type == FileSystemEntityType.notFound) return false;
  return stat.modified != opened.modified || stat.size != opened.length;
}

/// [path]에 제자리로 쓰고 새 [EditorTextFile] 기준값(수정 시각·크기)을 돌려준다.
Future<EditorTextFile> saveEditorText(
  String path,
  String text, {
  required EditorTextFile opened,
}) async {
  final bytes = encodeEditorText(text, hasBom: opened.hasBom);
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  final stat = await file.stat();
  return EditorTextFile(
    text: text,
    hasBom: opened.hasBom,
    lineBreak: opened.lineBreak,
    modified: stat.modified,
    length: stat.size,
    binary: opened.binary,
  );
}
