import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:daylight_commander/application/archive_service.dart';
import 'package:daylight_commander/domain/entities/file_entry.dart';
import 'package:daylight_commander/l10n/app_localizations.dart';
import 'package:daylight_commander/presentation/viewer/archive_viewer_screen.dart';

FileEntry _entryFor(String path, {bool isDirectory = false}) {
  return FileEntry(
    location: Uri.file(path),
    name: p.basename(path),
    isDirectory: isDirectory,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

/// `flutter test`는 FakeAsync 존에서 실행되어, 그 존 밖(탭 콜백 등)에서
/// 시작된 dart:io 기반 실제 비동기 작업(파일 읽기/쓰기, 화면 전환 등)은
/// [WidgetTester.pump]만으로는 끝나지 않는다. 탭 자체를 [runAsync] 콜백
/// *안에서* 실행해야 그 뒤에 이어지는 실제 비동기 체인 전체가 진짜 이벤트
/// 루프에서 완료될 시간을 번갈아 얻는다.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });
}

Future<void> _pumpAndSettleReal(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });
}

void main() {
  const service = ArchiveService();
  late Directory tempDir;
  late String zipPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daylight_commander_archive_viewer_test_');
    final aTxt = File(p.join(tempDir.path, 'a.txt'))..writeAsStringSync('hello from a');
    final subDir = Directory(p.join(tempDir.path, 'sub'))..createSync();
    File(p.join(subDir.path, 'b.txt')).writeAsStringSync('hello from nested');

    zipPath = p.join(tempDir.path, 'sample.zip');
    await service.compressToZip(
      sources: [_entryFor(aTxt.path), _entryFor(subDir.path, isDirectory: true)],
      zipPath: zipPath,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  testWidgets('최상위 항목만 보여주고, 하위 폴더로 들어가면 그 안의 파일이 보인다', (tester) async {
    await tester.pumpWidget(_wrap(
      ArchiveViewerScreen(zipPath: zipPath, archiveName: 'sample.zip'),
    ));
    await _pumpAndSettleReal(tester);

    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('sub'), findsOneWidget);
    expect(find.text('b.txt'), findsNothing);

    await _tapAndSettle(tester, find.text('sub'));

    expect(find.text('..'), findsOneWidget);
    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('a.txt'), findsNothing);

    await _tapAndSettle(tester, find.text('..'));

    expect(find.text('a.txt'), findsOneWidget);
  });

  testWidgets('파일을 탭하면 그 파일 하나만 꺼내 뷰어로 연다 (zip 전체는 풀지 않음)', (tester) async {
    await tester.pumpWidget(_wrap(
      ArchiveViewerScreen(zipPath: zipPath, archiveName: 'sample.zip'),
    ));
    await _pumpAndSettleReal(tester);

    await _tapAndSettle(tester, find.text('a.txt'));

    expect(find.text('hello from a'), findsOneWidget);
  });
}
