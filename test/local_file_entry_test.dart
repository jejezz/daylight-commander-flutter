import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:daylight_commander/application/usecases/local_file_entry.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daylight_commander_drop_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('로컬 파일 경로를 FileEntry로 만든다', () async {
    final file = File(p.join(tempDir.path, 'dropped.txt'))..writeAsStringSync('hello');

    final entry = await localFileEntryFor(file.path);

    expect(entry.name, 'dropped.txt');
    expect(entry.isDirectory, isFalse);
    expect(entry.sizeBytes, 5);
    expect(entry.location, Uri.file(file.path));
  });

  test('로컬 디렉터리 경로를 FileEntry로 만든다', () async {
    final dir = Directory(p.join(tempDir.path, 'dropped_dir'))..createSync();

    final entry = await localFileEntryFor(dir.path);

    expect(entry.name, 'dropped_dir');
    expect(entry.isDirectory, isTrue);
    expect(entry.sizeBytes, isNull);
  });

  test('점으로 시작하는 이름은 숨김으로 표시된다', () async {
    final file = File(p.join(tempDir.path, '.hidden'))..writeAsStringSync('x');

    final entry = await localFileEntryFor(file.path);

    expect(entry.isHidden, isTrue);
  });
}
