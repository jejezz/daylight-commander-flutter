import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/domain/entities/drive_entry.dart';
import 'package:daylight_commander/presentation/home/directory_tree.dart';
import 'package:daylight_commander/presentation/home/drives_provider.dart';
import 'package:daylight_commander/presentation/home/pane_controller.dart';

void main() {
  testWidgets('트리에서 폴더를 누르면 패널이 이동하고 그 패널이 활성 패널이 된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory.systemTemp.createTempSync('daylight_tree_');
    addTearDown(() => root.deleteSync(recursive: true));
    final sub = Directory(p.join(root.path, 'alpha'))..createSync();
    Directory(p.join(root.path, 'beta')).createSync();

    final container = ProviderContainer(overrides: [
      drivesProvider.overrideWith(
        (ref) => Stream.value([DriveEntry(name: 'ROOT', path: root.path)]),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: DirectoryTree(side: PaneSide.right)),
      ),
    ));

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump();
    expect(find.text('ROOT'), findsOneWidget);

    // 루트를 펼쳐 하위 폴더를 보이게 한다.
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('alpha'), findsOneWidget);

    await tester.tap(find.text('alpha'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(container.read(paneControllerProvider(PaneSide.right)).currentPath, sub.path);
    expect(container.read(activePaneProvider), PaneSide.right);
  });
}
