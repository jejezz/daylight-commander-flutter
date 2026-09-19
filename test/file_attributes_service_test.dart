import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:daylight_commander/application/file_attributes_service.dart';

void main() {
  const service = FileAttributesService();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daylight_commander_attrs_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('읽기전용을 켜고 끌 수 있다', () async {
    final file = File(p.join(tempDir.path, 'a.txt'))..writeAsStringSync('hello');

    expect(await service.isReadOnly(file.path), isFalse);

    await service.setReadOnly(file.path, true);
    expect(await service.isReadOnly(file.path), isTrue);

    await service.setReadOnly(file.path, false);
    expect(await service.isReadOnly(file.path), isFalse);
  }, skip: Platform.isWindows ? 'chmod 기반 검증은 POSIX 전용' : false);

  test('loadInfo는 폴더의 크기를 재귀적으로 합산한다', () async {
    final dir = Directory(p.join(tempDir.path, 'folder'))..createSync();
    File(p.join(dir.path, 'a.txt')).writeAsStringSync('12345'); // 5 bytes
    Directory(p.join(dir.path, 'nested')).createSync();
    File(p.join(dir.path, 'nested', 'b.txt')).writeAsStringSync('1234567890'); // 10 bytes

    final info = await service.loadInfo(dir.path, isDirectory: true);

    expect(info.sizeBytes, 15);
  });

  test('setPosixMode로 권한 비트를 임의로 지정할 수 있다', () async {
    final file = File(p.join(tempDir.path, 'a.txt'))..writeAsStringSync('hello');

    // rw-r--r-- (0o644)
    await service.setPosixMode(file.path, 420);
    var info = await service.loadInfo(file.path, isDirectory: false);
    expect(info.posixMode, 420);

    // rwxr-xr-x (0o755)
    await service.setPosixMode(file.path, 493);
    info = await service.loadInfo(file.path, isDirectory: false);
    expect(info.posixMode, 493);
  }, skip: Platform.isWindows ? 'POSIX 권한은 macOS/Linux 전용' : false);
}
