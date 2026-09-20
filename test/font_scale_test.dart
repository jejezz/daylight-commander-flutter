import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_commander/presentation/theme/font_scale_provider.dart';

Future<void> _waitTick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('기본값은 보통(1.0)이다', () async {
    final controller = FontScaleController();
    await _waitTick();

    expect(controller.state, 1.0);
  });

  test('cycle: 보통 → 크게 → 작게 → 다시 보통 순으로 돈다', () async {
    final controller = FontScaleController();
    await _waitTick();

    await controller.cycle();
    expect(controller.state, 1.15);

    await controller.cycle();
    expect(controller.state, 0.9);

    await controller.cycle();
    expect(controller.state, 1.0);
  });

  test('선택한 글자 크기는 SharedPreferences에 저장되어 재시작 후에도 남는다', () async {
    final controller = FontScaleController();
    await _waitTick();
    await controller.cycle(); // 크게

    final reloaded = FontScaleController();
    await _waitTick();

    expect(reloaded.state, 1.15);
  });
}
