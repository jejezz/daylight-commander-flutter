import 'package:daylight_commander/presentation/home/tree_dock_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('toggle은 열림 상태를 뒤집고, 폭은 최소/최대 범위로 잘린다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(treeDockProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // 저장값 로드 대기

    expect(container.read(treeDockProvider).open, isFalse);
    notifier.toggle();
    expect(container.read(treeDockProvider).open, isTrue);

    notifier.setWidth(10000);
    expect(container.read(treeDockProvider).width, treeDockMaxWidth);
    notifier.setWidth(-10000);
    expect(container.read(treeDockProvider).width, treeDockMinWidth);
  });
}
