import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/presentation/home/recent_folders_provider.dart';

Future<void> _waitTick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('최근 방문한 폴더가 최신순으로 쌓이고 중복은 앞으로 올라온다', () async {
    final controller = RecentFoldersController();
    await _waitTick();

    await controller.record('/a');
    await controller.record('/b');
    await controller.record('/a');

    expect(controller.state, ['/a', '/b']);
  });

  test('최대 개수를 넘으면 오래된 항목부터 잘린다', () async {
    final controller = RecentFoldersController();
    await _waitTick();

    for (var i = 0; i < 20; i++) {
      await controller.record('/path$i');
    }

    expect(controller.state.length, 15);
    expect(controller.state.first, '/path19');
  });
}
