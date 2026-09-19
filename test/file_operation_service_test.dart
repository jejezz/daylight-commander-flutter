import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:daylight_commander/application/cancel_token.dart';
import 'package:daylight_commander/application/file_operation_service.dart';
import 'package:daylight_commander/domain/entities/file_conflict.dart';
import 'package:daylight_commander/domain/entities/file_entry.dart';

FileEntry _entryFor(String path, {bool isDirectory = false}) {
  return FileEntry(
    location: Uri.file(path),
    name: p.basename(path),
    isDirectory: isDirectory,
  );
}

Future<ConflictAction> _neverAsk(FileConflict c) async =>
    throw StateError('충돌이 예상되지 않았는데 발생함: ${c.destinationPath}');

void main() {
  const service = FileOperationService();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daylight_commander_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('copy: 파일을 대상 폴더로 복사하고 원본은 남긴다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
    final file = File(p.join(srcDir.path, 'a.txt'))..writeAsStringSync('hello');

    await service.copy(
      sources: [_entryFor(file.path)],
      destinationDir: destDir.path,
      onConflict: _neverAsk,
    );

    expect(File(p.join(destDir.path, 'a.txt')).existsSync(), isTrue);
    expect(file.existsSync(), isTrue, reason: '복사는 원본을 남겨야 한다');
  });

  test('copy: 하위 폴더를 재귀적으로 복사한다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    Directory(p.join(srcDir.path, 'nested')).createSync();
    File(p.join(srcDir.path, 'nested', 'b.txt')).writeAsStringSync('nested');
    final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();

    await service.copy(
      sources: [_entryFor(srcDir.path, isDirectory: true)],
      destinationDir: destDir.path,
      onConflict: _neverAsk,
    );

    expect(
      File(p.join(destDir.path, 'src', 'nested', 'b.txt')).existsSync(),
      isTrue,
    );
  });

  test('move: 같은 파일시스템에서는 rename으로 원본을 제거한다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
    final file = File(p.join(srcDir.path, 'a.txt'))..writeAsStringSync('hello');

    await service.move(
      sources: [_entryFor(file.path)],
      destinationDir: destDir.path,
      onConflict: _neverAsk,
    );

    expect(File(p.join(destDir.path, 'a.txt')).existsSync(), isTrue);
    expect(file.existsSync(), isFalse, reason: '이동은 원본을 제거해야 한다');
  });

  test('conflict: skip을 선택하면 대상 파일이 바뀌지 않는다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
    File(p.join(srcDir.path, 'a.txt')).writeAsStringSync('new content');
    File(p.join(destDir.path, 'a.txt')).writeAsStringSync('old content');

    await service.copy(
      sources: [_entryFor(p.join(srcDir.path, 'a.txt'))],
      destinationDir: destDir.path,
      onConflict: (c) async => ConflictAction.skip,
    );

    expect(File(p.join(destDir.path, 'a.txt')).readAsStringSync(), 'old content');
  });

  test('conflict: overwrite를 선택하면 대상 파일이 교체된다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
    File(p.join(srcDir.path, 'a.txt')).writeAsStringSync('new content');
    File(p.join(destDir.path, 'a.txt')).writeAsStringSync('old content');

    await service.copy(
      sources: [_entryFor(p.join(srcDir.path, 'a.txt'))],
      destinationDir: destDir.path,
      onConflict: (c) async => ConflictAction.overwrite,
    );

    expect(File(p.join(destDir.path, 'a.txt')).readAsStringSync(), 'new content');
  });

  test('conflict: rename을 선택하면 "(2)" 접미사로 별도 저장된다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
    File(p.join(srcDir.path, 'a.txt')).writeAsStringSync('new content');
    File(p.join(destDir.path, 'a.txt')).writeAsStringSync('old content');

    await service.copy(
      sources: [_entryFor(p.join(srcDir.path, 'a.txt'))],
      destinationDir: destDir.path,
      onConflict: (c) async => ConflictAction.rename,
    );

    expect(File(p.join(destDir.path, 'a.txt')).readAsStringSync(), 'old content');
    expect(File(p.join(destDir.path, 'a (2).txt')).readAsStringSync(), 'new content');
  });

  test('conflict: skipAll을 선택하면 이후 충돌에도 다시 묻지 않고 건너뛴다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
    for (final name in ['a.txt', 'b.txt']) {
      File(p.join(srcDir.path, name)).writeAsStringSync('new');
      File(p.join(destDir.path, name)).writeAsStringSync('old');
    }

    var askCount = 0;
    await service.copy(
      sources: [
        _entryFor(p.join(srcDir.path, 'a.txt')),
        _entryFor(p.join(srcDir.path, 'b.txt')),
      ],
      destinationDir: destDir.path,
      onConflict: (c) async {
        askCount++;
        return ConflictAction.skipAll;
      },
    );

    expect(askCount, 1, reason: '한 번만 묻고 이후엔 자동 적용되어야 한다');
    expect(File(p.join(destDir.path, 'a.txt')).readAsStringSync(), 'old');
    expect(File(p.join(destDir.path, 'b.txt')).readAsStringSync(), 'old');
  });

  test('취소 토큰을 취소하면 OperationCancelledException이 던져진다', () async {
    final srcDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
    File(p.join(srcDir.path, 'a.txt')).writeAsStringSync('hello');
    final token = CancelToken()..cancel();

    expect(
      () => service.copy(
        sources: [_entryFor(p.join(srcDir.path, 'a.txt'))],
        destinationDir: destDir.path,
        onConflict: _neverAsk,
        cancelToken: token,
      ),
      throwsA(isA<OperationCancelledException>()),
    );
  });

  test('delete: toTrash=false면 영구 삭제된다', () async {
    final file = File(p.join(tempDir.path, 'a.txt'))..writeAsStringSync('x');

    await service.delete(entries: [_entryFor(file.path)], toTrash: false);

    expect(file.existsSync(), isFalse);
  });

  test('createFolder: 같은 이름이 있으면 예외를 던진다', () async {
    Directory(p.join(tempDir.path, 'dup')).createSync();

    expect(
      () => service.createFolder(parentDir: tempDir.path, name: 'dup'),
      throwsA(isA<StateError>()),
    );
  });

  test('rename: 파일 이름을 바꾼다', () async {
    final file = File(p.join(tempDir.path, 'old.txt'))..writeAsStringSync('x');

    await service.rename(path: file.path, newName: 'new.txt');

    expect(file.existsSync(), isFalse);
    expect(File(p.join(tempDir.path, 'new.txt')).existsSync(), isTrue);
  });
}
