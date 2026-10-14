import 'dart:io';

import 'package:daylight_commander/application/ftp_session_manager.dart';
import 'package:daylight_commander/application/sftp_session_manager.dart';
import 'package:daylight_commander/application/webdav_session_manager.dart';
import 'package:daylight_commander/presentation/home/folder_auto_refresh.dart';
import 'package:daylight_commander/presentation/home/pane_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('앱이 활성화된 동안만 두 패널을 다시 읽는다', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dc_auto_');
    addTearDown(() => dir.deleteSync(recursive: true));
    // 처음부터 임시 폴더를 열어 둔다 (기본은 홈 폴더라 읽는 데 오래 걸리고 결과가 섞인다).
    final container = ProviderContainer(overrides: [
      paneControllerProvider.overrideWith(
        (ref, side) => PaneController(
          dir.path,
          ref.read(ftpSessionManagerProvider.notifier),
          ref.read(sftpSessionManagerProvider.notifier),
          ref.read(webdavSessionManagerProvider.notifier),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: FolderAutoRefresh(interval: Duration(milliseconds: 100), child: SizedBox()),
        ),
      ),
    );
    for (final side in PaneSide.values) {
      container.read(paneControllerProvider(side)); // 패널을 만들어 처음 읽기를 시작시킨다
    }

    // 실제 파일 읽기는 진짜 시간이 흘러야 끝나고, 그 뒤 이어지는 코드는 pump로 마이크로태스크를 비워야 돈다.
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump();
      }
    }

    // 가짜 시계를 흘려 타이머를 울리고 읽기가 끝나길 기다린다.
    Future<void> wait() async {
      await tester.pump(const Duration(milliseconds: 150));
      await settle();
    }

    await settle(); // 처음 읽기

    List<String> names(PaneSide s) =>
        container.read(paneControllerProvider(s)).entries.map((e) => e.name).toList();

    File(p.join(dir.path, 'one.txt')).writeAsStringSync('1');
    await wait();
    expect(names(PaneSide.left), ['one.txt']);
    expect(names(PaneSide.right), ['one.txt']);

    // 포커스를 잃으면 멈춘다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    File(p.join(dir.path, 'two.txt')).writeAsStringSync('2');
    await wait();
    expect(names(PaneSide.left), ['one.txt']);

    // 되찾으면 바로 읽는다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await wait();
    expect(names(PaneSide.left), ['one.txt', 'two.txt']);
    expect(names(PaneSide.right), ['one.txt', 'two.txt']);

    await tester.pumpWidget(const SizedBox()); // 타이머 정리
  });
}
