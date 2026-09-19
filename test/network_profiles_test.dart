import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/presentation/home/network_profiles_provider.dart';

Future<void> _waitTick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SMB 프로필 추가/중복 방지/영속화', () async {
    final controller = NetworkProfilesController();
    await _waitTick();

    await controller.add('192.168.0.10', 'share');
    await controller.add('192.168.0.10', 'share'); // 중복
    expect(controller.state.length, 1);

    final reloaded = NetworkProfilesController();
    await _waitTick();
    expect(reloaded.state.single.host, '192.168.0.10');
    expect(reloaded.state.single.share, 'share');
  });

  test('SMB 프로필 삭제', () async {
    final controller = NetworkProfilesController();
    await _waitTick();

    await controller.add('a', '');
    await controller.add('b', '');
    await controller.remove(const NetworkProfile(host: 'a', share: ''));

    expect(controller.state.map((p) => p.host), ['b']);
  });
}
