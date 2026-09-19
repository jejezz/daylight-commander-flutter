import 'package:flutter_test/flutter_test.dart';

import 'package:daylight_commander/domain/entities/drive_entry.dart';
import 'package:daylight_commander/presentation/home/drive_utils.dart';

void main() {
  const drives = [
    DriveEntry(name: 'Macintosh HD', path: '/'),
    DriveEntry(name: 'USB', path: '/Volumes/USB'),
  ];

  test('같은 루트 아래 두 경로는 같은 드라이브로 판단한다', () {
    expect(
      isSameDrive('/Users/me/a.txt', '/Users/me/Documents', drives),
      isTrue,
    );
  });

  test('외장 볼륨과 루트는 다른 드라이브로 판단한다', () {
    expect(
      isSameDrive('/Users/me/a.txt', '/Volumes/USB/backup', drives),
      isFalse,
    );
  });

  test('같은 외장 볼륨 내부는 같은 드라이브로 판단한다', () {
    expect(
      isSameDrive('/Volumes/USB/a.txt', '/Volumes/USB/sub/dir', drives),
      isTrue,
    );
  });
}
