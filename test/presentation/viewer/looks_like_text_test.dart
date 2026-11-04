import 'dart:convert';

import 'package:daylight_commander/presentation/viewer/viewer_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('빈 파일과 일반 텍스트는 텍스트', () {
    expect(looksLikeText([]), isTrue);
    expect(looksLikeText(utf8.encode('LOCAL_PATH := \$(call my-dir)\n\tfoo\r\n')), isTrue);
    expect(looksLikeText(utf8.encode('한글 내용입니다\n')), isTrue);
  });

  test('NUL 바이트나 제어 문자가 많으면 바이너리', () {
    expect(looksLikeText([0x7f, 0x45, 0x4c, 0x46, 0, 0, 1]), isFalse);
    expect(looksLikeText(List.filled(100, 0x01)), isFalse);
  });
}
