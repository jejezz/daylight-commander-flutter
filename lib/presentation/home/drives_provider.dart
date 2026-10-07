import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/usecases/list_drives.dart';
import '../../domain/entities/drive_entry.dart';

/// 드라이브/볼륨 목록. 앱 시작 때 한 번만 읽으면 실행 중에 마운트한 SMB 공유나
/// 외장 디스크가 메뉴/트리에 영영 나타나지 않고, `open smb://`는 마운트가
/// 끝나기 전에 반환되어 연결 직후 한 번 다시 읽는 것으로도 부족하다. 그래서
/// 주기적으로 다시 읽되 목록이 실제로 바뀔 때만 값을 내보내 불필요한 리빌드를
/// 만들지 않는다.
const drivesPollInterval = Duration(seconds: 3);

final drivesProvider = StreamProvider<List<DriveEntry>>((ref) async* {
  var disposed = false;
  ref.onDispose(() => disposed = true);

  List<DriveEntry>? last;
  while (!disposed) {
    final current = await const ListDrives()();
    if (disposed) return;
    if (last == null || !_sameDrives(last, current)) {
      last = current;
      yield current;
    }
    await Future<void>.delayed(drivesPollInterval);
  }
});

bool _sameDrives(List<DriveEntry> a, List<DriveEntry> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].path != b[i].path || a[i].name != b[i].name) return false;
  }
  return true;
}
