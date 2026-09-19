import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/presentation/home/bookmarks_provider.dart';

Future<void> _waitTick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('북마크 토글: 추가했다가 다시 누르면 제거된다', () async {
    final controller = BookmarksController();
    await _waitTick();

    await controller.toggle('/Users/me/Documents');
    expect(controller.state, ['/Users/me/Documents']);
    expect(controller.contains('/Users/me/Documents'), isTrue);

    await controller.toggle('/Users/me/Documents');
    expect(controller.state, isEmpty);
  });

  test('북마크는 SharedPreferences에 저장되어 재시작 후에도 남는다', () async {
    final controller = BookmarksController();
    await _waitTick();
    await controller.toggle('/Users/me/Projects');

    final reloaded = BookmarksController();
    await _waitTick();

    expect(reloaded.state, ['/Users/me/Projects']);
  });

  test('remove로 특정 북마크만 지울 수 있다', () async {
    final controller = BookmarksController();
    await _waitTick();
    await controller.toggle('/a');
    await controller.toggle('/b');

    await controller.remove('/a');

    expect(controller.state, ['/b']);
  });
}
