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

  test('setScale: 작게·보통·크게를 고르면 그대로 바뀌고, 목록에 없는 값은 무시한다', () async {
    final controller = FontScaleController();
    await _waitTick();

    await controller.setScale(1.15);
    expect(controller.state, 1.15);

    await controller.setScale(0.9);
    expect(controller.state, 0.9);

    await controller.setScale(1.0);
    expect(controller.state, 1.0);

    await controller.setScale(2.0); // 목록에 없는 값
    expect(controller.state, 1.0);
  });

  test('선택한 글자 크기는 SharedPreferences에 저장되어 재시작 후에도 남는다', () async {
    final controller = FontScaleController();
    await _waitTick();
    await controller.setScale(1.15); // 크게

    final reloaded = FontScaleController();
    await _waitTick();

    expect(reloaded.state, 1.15);
  });
}
