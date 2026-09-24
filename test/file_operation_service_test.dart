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

  test('conflict: rename을 선택하면 "2"(macOS)/"(2)" 접미사로 별도 저장된다', () async {
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
    final renamed = Platform.isMacOS ? 'a 2.txt' : 'a (2).txt';
    expect(File(p.join(destDir.path, renamed)).readAsStringSync(), 'new content');
  });

  group('폴더 충돌', () {
    late Directory srcFolder;
    late Directory destDir;

    setUp(() {
      // src/photos: a.txt(new), b.txt   /   dest/photos: a.txt(old), old.txt
      srcFolder = Directory(p.join(tempDir.path, 'src', 'photos'))..createSync(recursive: true);
      File(p.join(srcFolder.path, 'a.txt')).writeAsStringSync('new');
      File(p.join(srcFolder.path, 'b.txt')).writeAsStringSync('b');
      destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
      final existing = Directory(p.join(destDir.path, 'photos'))..createSync();
      File(p.join(existing.path, 'a.txt')).writeAsStringSync('old');
      File(p.join(existing.path, 'old.txt')).writeAsStringSync('old');
    });

    test('폴더 단위로 한 번만 묻고 내용 파일마다 묻지 않는다', () async {
      final conflicts = <FileConflict>[];
      await service.copy(
        sources: [_entryFor(srcFolder.path, isDirectory: true)],
        destinationDir: destDir.path,
        onConflict: (c) async {
          conflicts.add(c);
          return ConflictAction.overwrite;
        },
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.single.isDirectory, isTrue);
      expect(conflicts.single.destinationPath, p.join(destDir.path, 'photos'));
    });

    test('overwrite는 기존 폴더를 통째로 교체한다 (병합하지 않는다)', () async {
      await service.copy(
        sources: [_entryFor(srcFolder.path, isDirectory: true)],
        destinationDir: destDir.path,
        onConflict: (c) async => ConflictAction.overwrite,
      );

      final replaced = p.join(destDir.path, 'photos');
      expect(File(p.join(replaced, 'a.txt')).readAsStringSync(), 'new');
      expect(File(p.join(replaced, 'b.txt')).existsSync(), isTrue);
      expect(File(p.join(replaced, 'old.txt')).existsSync(), isFalse);
    });

    test('rename은 기존 폴더를 두고 새 이름의 폴더로 복사한다', () async {
      await service.copy(
        sources: [_entryFor(srcFolder.path, isDirectory: true)],
        destinationDir: destDir.path,
        onConflict: (c) async => ConflictAction.rename,
      );

      final renamed = p.join(destDir.path, Platform.isMacOS ? 'photos 2' : 'photos (2)');
      expect(File(p.join(destDir.path, 'photos', 'a.txt')).readAsStringSync(), 'old');
      expect(File(p.join(destDir.path, 'photos', 'old.txt')).existsSync(), isTrue);
      expect(File(p.join(renamed, 'a.txt')).readAsStringSync(), 'new');
      expect(File(p.join(renamed, 'b.txt')).existsSync(), isTrue);
    });

    test('rename은 점이 든 폴더 이름을 확장자로 나누지 않는다', () async {
      final dotted = Directory(p.join(tempDir.path, 'src', 'v1.2'))..createSync();
      Directory(p.join(destDir.path, 'v1.2')).createSync();

      await service.copy(
        sources: [_entryFor(dotted.path, isDirectory: true)],
        destinationDir: destDir.path,
        onConflict: (c) async => ConflictAction.rename,
      );

      final renamed = Platform.isMacOS ? 'v1.2 2' : 'v1.2 (2)';
      expect(Directory(p.join(destDir.path, renamed)).existsSync(), isTrue);
    });

    test('skip은 기존 폴더를 건드리지 않는다', () async {
      await service.copy(
        sources: [_entryFor(srcFolder.path, isDirectory: true)],
        destinationDir: destDir.path,
        onConflict: (c) async => ConflictAction.skip,
      );

      final existing = p.join(destDir.path, 'photos');
      expect(File(p.join(existing, 'a.txt')).readAsStringSync(), 'old');
      expect(File(p.join(existing, 'b.txt')).existsSync(), isFalse);
    });

    test('cancel하면 기존 폴더에 아무것도 복사하지 않는다', () async {
      await expectLater(
        service.copy(
          sources: [_entryFor(srcFolder.path, isDirectory: true)],
          destinationDir: destDir.path,
          onConflict: (c) async => ConflictAction.cancel,
        ),
        throwsA(isA<OperationCancelledException>()),
      );

      expect(File(p.join(destDir.path, 'photos', 'b.txt')).existsSync(), isFalse);
    });

    test('move + overwrite는 기존 폴더를 교체하고 원본을 제거한다', () async {
      await service.move(
        sources: [_entryFor(srcFolder.path, isDirectory: true)],
        destinationDir: destDir.path,
        onConflict: (c) async => ConflictAction.overwrite,
      );

      final replaced = p.join(destDir.path, 'photos');
      expect(File(p.join(replaced, 'a.txt')).readAsStringSync(), 'new');
      expect(File(p.join(replaced, 'old.txt')).existsSync(), isFalse);
      expect(srcFolder.existsSync(), isFalse);
    });

    test('원본이 들어 있는 폴더는 덮어쓰지 않는다', () async {
      // dest/photos/photos 를 dest 로 복사 → 덮어쓰면 원본까지 지워진다.
      final inner = Directory(p.join(destDir.path, 'photos', 'photos'))..createSync();
      File(p.join(inner.path, 'x.txt')).writeAsStringSync('x');

      await expectLater(
        service.copy(
          sources: [_entryFor(inner.path, isDirectory: true)],
          destinationDir: destDir.path,
          onConflict: (c) async => ConflictAction.overwrite,
        ),
        throwsA(isA<StateError>()),
      );
      expect(File(p.join(inner.path, 'x.txt')).existsSync(), isTrue);
    });
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

  test('createFile: 빈 파일을 만든다', () async {
    await service.createFile(parentDir: tempDir.path, name: 'new.txt');

    final file = File(p.join(tempDir.path, 'new.txt'));
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), 0);
  });

  test('createFile: 같은 이름이 있으면 예외를 던진다', () async {
    File(p.join(tempDir.path, 'dup.txt')).writeAsStringSync('x');

    expect(
      () => service.createFile(parentDir: tempDir.path, name: 'dup.txt'),
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
