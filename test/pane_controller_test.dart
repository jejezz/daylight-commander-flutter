import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:daylight_commander/application/ftp_session_manager.dart';
import 'package:daylight_commander/application/sftp_session_manager.dart';
import 'package:daylight_commander/application/webdav_session_manager.dart';
import 'package:daylight_commander/presentation/home/pane_controller.dart';

PaneController _newController(String path) => PaneController(
      path,
      FtpSessionManager(),
      SftpSessionManager(),
      WebdavSessionManager(),
    );

Future<void> _waitLoaded(PaneController controller) async {
  for (var i = 0; i < 100 && controller.state.loading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daylight_commander_pane_test_');
    File(p.join(tempDir.path, 'b.txt')).writeAsStringSync('0123456789'); // 10 bytes
    File(p.join(tempDir.path, 'a.txt')).writeAsStringSync('01234'); // 5 bytes
    File(p.join(tempDir.path, '.hidden.txt')).writeAsStringSync('x');
    Directory(p.join(tempDir.path, 'zz_folder')).createSync();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('기본 정렬은 폴더 우선 + 이름순이고 숨김파일은 제외된다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    final names = controller.state.visibleEntries.map((e) => e.name).toList();
    expect(names, ['zz_folder', 'a.txt', 'b.txt']);
  });

  test('숨김파일 토글을 켜면 .으로 시작하는 파일이 보인다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.toggleShowHidden();

    expect(
      controller.state.visibleEntries.map((e) => e.name),
      containsAll(['.hidden.txt']),
    );
  });

  test('크기순 정렬: 폴더는 여전히 맨 위, 파일은 크기 오름차순', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.setSortField(SortField.size);

    final names = controller.state.visibleEntries.map((e) => e.name).toList();
    expect(names, ['zz_folder', 'a.txt', 'b.txt']); // a.txt(5B) < b.txt(10B)
  });

  test('같은 정렬 필드를 다시 누르면 방향이 반전된다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.setSortField(SortField.size);
    expect(controller.state.sortAscending, isTrue);
    controller.setSortField(SortField.size);
    expect(controller.state.sortAscending, isFalse);

    final fileNames = controller.state.visibleEntries
        .where((e) => !e.isDirectory)
        .map((e) => e.name)
        .toList();
    expect(fileNames, ['b.txt', 'a.txt']);
  });

  test('뒤로/앞으로 히스토리 탐색', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    final subPath = p.join(tempDir.path, 'zz_folder');
    await controller.navigateTo(subPath);
    expect(controller.state.currentPath, subPath);
    expect(controller.state.backHistory, [tempDir.path]);

    await controller.goBack();
    expect(controller.state.currentPath, tempDir.path);
    expect(controller.state.forwardHistory, [subPath]);

    await controller.goForward();
    expect(controller.state.currentPath, subPath);
  });

  test('선택 인덱스는 visibleEntries 기준이다 (숨김파일 제외 후 인덱스)', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.selectOnly(1); // a.txt (index 0=zz_folder, 1=a.txt, 2=b.txt)
    expect(controller.state.selectedEntries.single.name, 'a.txt');
  });

  test('퀵서치: 타이핑한 글자를 포함하는 항목만 남는다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.appendQuickFilterChar('a');
    expect(controller.state.visibleEntries.map((e) => e.name), ['a.txt']);

    controller.backspaceQuickFilter();
    expect(controller.state.visibleEntries.length, 3);

    controller.appendQuickFilterChar('z');
    controller.clearQuickFilter();
    expect(controller.state.quickFilter, isEmpty);
    expect(controller.state.visibleEntries.length, 3);
  });

  test('퀵서치는 폴더로 이동하면 초기화된다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.appendQuickFilterChar('a');
    await controller.navigateTo(p.join(tempDir.path, 'zz_folder'));

    expect(controller.state.quickFilter, isEmpty);
  });

  test('패턴으로 선택: *.txt는 확장자가 txt인 파일만 선택한다 (폴더 제외)', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.selectByPattern('*.txt', add: true);

    final names = controller.state.selectedEntries.map((e) => e.name).toSet();
    expect(names, {'a.txt', 'b.txt'});
  });

  test('패턴으로 선택 해제: 이미 선택된 항목 중 패턴에 맞는 것만 제거한다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.selectByPattern('*.txt', add: true);
    controller.selectByPattern('a.*', add: false);

    final names = controller.state.selectedEntries.map((e) => e.name).toSet();
    expect(names, {'b.txt'});
  });

  test('visibleEntries/selectedEntries는 상태가 바뀔 때 한 번만 계산되고 캐싱된다', () async {
    // 선택 한 번에 여러 곳(컨트롤러/뷰/F-바/상태바)이 반복 접근해도 매번 다시
    // 필터링하지 않아야 한다 — 큰 폴더에서 선택 하이라이트가 느려 보이던
    // 원인이었다. 같은 state에서는 항상 동일한 리스트 인스턴스여야 한다.
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    final state = controller.state;
    expect(identical(state.visibleEntries, state.visibleEntries), isTrue);
    expect(identical(state.selectedEntries, state.selectedEntries), isTrue);

    controller.selectOnly(1);
    final afterSelect = controller.state;
    // 새 상태에서도 마찬가지로, 같은 스냅샷 안에서는 몇 번을 읽든 같은 인스턴스다.
    expect(identical(afterSelect.visibleEntries, afterSelect.visibleEntries), isTrue);
    expect(identical(afterSelect.selectedEntries, afterSelect.selectedEntries), isTrue);
  });

  test('더블클릭 감지: 같은 항목을 빠르게 두 번 누르면 더블클릭으로 판정된다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);
    final location = controller.state.visibleEntries.first.location;

    expect(controller.consumeDoubleClick(location), isFalse, reason: '첫 클릭은 더블클릭이 아니다');
    expect(controller.consumeDoubleClick(location), isTrue, reason: '바로 이어진 같은 항목 클릭은 더블클릭');
  });

  test('더블클릭 감지: 다른 항목을 클릭하면 더블클릭이 아니다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);
    final entries = controller.state.visibleEntries;

    expect(controller.consumeDoubleClick(entries[0].location), isFalse);
    expect(controller.consumeDoubleClick(entries[1].location), isFalse);
  });

  test('더블클릭 감지: 시간 창을 벗어나면 더블클릭이 아니다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);
    final location = controller.state.visibleEntries.first.location;

    expect(controller.consumeDoubleClick(location), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(controller.consumeDoubleClick(location), isFalse, reason: '350ms 창을 넘겼으므로 더블클릭이 아니다');
  });

  test('moveCursor: 화살표는 커서만 옮기고 selection은 건드리지 않는다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);
    // visibleEntries = [zz_folder, a.txt, b.txt]

    controller.moveCursor(1);
    expect(controller.state.cursorIndex, 0);
    expect(controller.state.selection, isEmpty, reason: '화살표만으로는 진짜 선택에 들어가지 않는다');

    controller.moveCursor(1);
    expect(controller.state.cursorIndex, 1);

    controller.moveCursor(-1);
    expect(controller.state.cursorIndex, 0);
  });

  test('moveCursor: 범위를 벗어나지 않도록 clamp된다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.moveCursor(-1); // 맨 위에서 더 위로
    expect(controller.state.cursorIndex, 0);

    controller.moveCursor(1);
    controller.moveCursor(1);
    controller.moveCursor(1); // 맨 아래에서 더 아래로 (총 항목 3개, 마지막 index=2)
    expect(controller.state.cursorIndex, 2);
  });

  test('toggleCursorSelection: 스페이스는 커서 항목을 진짜 선택에 넣거나 뺀다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.moveCursor(1); // zz_folder
    controller.moveCursor(1); // a.txt로 이동
    controller.toggleCursorSelection();
    expect(controller.state.selectedEntries.map((e) => e.name), ['a.txt']);
    expect(controller.state.cursorIndex, 1, reason: '스페이스는 커서를 움직이지 않는다');

    controller.toggleCursorSelection();
    expect(controller.state.selection, isEmpty);
  });

  test('toggleCursorSelection: 커서가 없으면 아무 일도 하지 않는다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.toggleCursorSelection();
    expect(controller.state.selection, isEmpty);
  });

  test('moveCursor + toggleCursorSelection으로 떨어진 항목 여러 개를 다중선택할 수 있다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);

    controller.moveCursor(1); // zz_folder
    controller.moveCursor(1); // a.txt
    controller.toggleCursorSelection();
    controller.moveCursor(1); // b.txt
    controller.toggleCursorSelection();

    expect(
      controller.state.selectedEntries.map((e) => e.name).toSet(),
      {'a.txt', 'b.txt'},
      reason: '커서 이동이 앞서 스페이스로 넣은 항목을 지우면 안 된다',
    );
  });

  test('폴더 이동 시 커서가 초기화된다', () async {
    final controller = _newController(tempDir.path);
    await _waitLoaded(controller);
    controller.moveCursor(1);
    expect(controller.state.cursorIndex, isNotNull);

    await controller.navigateTo(p.join(tempDir.path, 'zz_folder'));

    expect(controller.state.cursorIndex, isNull);
  });
}
