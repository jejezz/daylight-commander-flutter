import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:daylight_commander/application/archive_service.dart';
import 'package:daylight_commander/domain/entities/file_entry.dart';

FileEntry _entryFor(String path, {bool isDirectory = false}) {
  return FileEntry(
    location: Uri.file(path),
    name: p.basename(path),
    isDirectory: isDirectory,
  );
}

void main() {
  const service = ArchiveService();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daylight_commander_archive_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('압축한 zip을 다시 풀면 원본 파일 내용이 그대로 복원된다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    File(p.join(srcDir.path, 'a.txt')).writeAsStringSync('hello world');
    Directory(p.join(srcDir.path, 'nested')).createSync();
    File(p.join(srcDir.path, 'nested', 'b.txt')).writeAsStringSync('nested content');

    final zipPath = p.join(tempDir.path, 'src.zip');
    await service.compressToZip(
      sources: [_entryFor(p.join(srcDir.path, 'a.txt'))],
      zipPath: zipPath,
    );
    expect(File(zipPath).existsSync(), isTrue);

    final extractDir = p.join(tempDir.path, 'extracted');
    await service.extractZip(zipPath: zipPath, destinationDir: extractDir);

    expect(File(p.join(extractDir, 'a.txt')).readAsStringSync(), 'hello world');
  });

  test('폴더를 압축하면 내부 구조가 zip 안에 그대로 보존된다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    Directory(p.join(srcDir.path, 'nested')).createSync();
    File(p.join(srcDir.path, 'nested', 'b.txt')).writeAsStringSync('nested content');

    final zipPath = p.join(tempDir.path, 'folder.zip');
    await service.compressToZip(
      sources: [_entryFor(srcDir.path, isDirectory: true)],
      zipPath: zipPath,
    );

    final extractDir = p.join(tempDir.path, 'extracted');
    await service.extractZip(zipPath: zipPath, destinationDir: extractDir);

    expect(
      File(p.join(extractDir, 'src', 'nested', 'b.txt')).readAsStringSync(),
      'nested content',
    );
  });

  test('listZipEntries: 풀지 않고도 내부 파일/폴더 구조를 읽을 수 있다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    File(p.join(srcDir.path, 'a.txt')).writeAsStringSync('hello world');
    Directory(p.join(srcDir.path, 'nested')).createSync();
    File(p.join(srcDir.path, 'nested', 'b.txt')).writeAsStringSync('nested content');

    final zipPath = p.join(tempDir.path, 'src.zip');
    await service.compressToZip(
      sources: [_entryFor(srcDir.path, isDirectory: true)],
      zipPath: zipPath,
    );

    final entries = await service.listZipEntries(zipPath);
    final names = entries.where((e) => !e.isDirectory).map((e) => e.name).toSet();

    expect(names, containsAll(['src/a.txt', 'src/nested/b.txt']));
  });

  test('extractZipEntry: zip 전체를 풀지 않고 파일 하나만 꺼낼 수 있다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    File(p.join(srcDir.path, 'a.txt')).writeAsStringSync('hello world');
    Directory(p.join(srcDir.path, 'nested')).createSync();
    File(p.join(srcDir.path, 'nested', 'b.txt')).writeAsStringSync('nested content');

    final zipPath = p.join(tempDir.path, 'src.zip');
    await service.compressToZip(
      sources: [_entryFor(srcDir.path, isDirectory: true)],
      zipPath: zipPath,
    );

    final outPath = p.join(tempDir.path, 'only_b.txt');
    await service.extractZipEntry(
      zipPath: zipPath,
      entryName: 'src/nested/b.txt',
      destinationPath: outPath,
    );

    expect(File(outPath).readAsStringSync(), 'nested content');
    expect(File(p.join(tempDir.path, 'a.txt')).existsSync(), isFalse);
  });
}
