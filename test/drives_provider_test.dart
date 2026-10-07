import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daylight_commander/presentation/home/drives_provider.dart';

void main() {
  test('드라이브 목록은 바뀌지 않으면 폴링 중에도 다시 내보내지 않는다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final values = <int>[];
    final sub = container.listen(drivesProvider, (_, next) {
      final v = next.valueOrNull;
      if (v != null) values.add(v.length);
    }, fireImmediately: true);
    addTearDown(sub.close);

    final first = await container.read(drivesProvider.future);
    expect(first, isNotEmpty);
    // 목록이 같으면 다시 내보내지 않는다 (불필요한 리빌드 방지).
    await Future<void>.delayed(drivesPollInterval + const Duration(seconds: 1));
    expect(values.length, 1);
  }, timeout: const Timeout(Duration(seconds: 15)));
}
