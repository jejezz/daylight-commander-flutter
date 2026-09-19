import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/presentation/theme/theme_mode_provider.dart';

Future<void> _waitTick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('기본값은 시스템 설정 따름이다', () async {
    final controller = ThemeModeController();
    await _waitTick();

    expect(controller.state, ThemeMode.system);
  });

  test('cycle: 시스템 → 라이트 → 다크 → 다시 시스템 순으로 돈다', () async {
    final controller = ThemeModeController();
    await _waitTick();

    await controller.cycle();
    expect(controller.state, ThemeMode.light);

    await controller.cycle();
    expect(controller.state, ThemeMode.dark);

    await controller.cycle();
    expect(controller.state, ThemeMode.system);
  });

  test('선택한 테마는 SharedPreferences에 저장되어 재시작 후에도 남는다', () async {
    final controller = ThemeModeController();
    await _waitTick();
    await controller.cycle(); // light
    await controller.cycle(); // dark

    final reloaded = ThemeModeController();
    await _waitTick();

    expect(reloaded.state, ThemeMode.dark);
  });
}
