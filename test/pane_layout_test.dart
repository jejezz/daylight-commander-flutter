import 'package:daylight_commander/presentation/home/pane_controller.dart';
import 'package:daylight_commander/presentation/home/pane_layout_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('swap은 왼쪽에 놓이는 패널을 바꾸고, 1패널 토글은 독립적이다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(paneLayoutProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // 저장값 로드 대기

    expect(container.read(paneLayoutProvider).leftmost, PaneSide.left);
    notifier.swap();
    expect(container.read(paneLayoutProvider).leftmost, PaneSide.right);
    notifier.toggleSinglePane();
    final layout = container.read(paneLayoutProvider);
    expect(layout.singlePane, isTrue);
    expect(layout.swapped, isTrue);
  });
}
