import 'package:daylight_commander/application/thumbnail_policy.dart';
import 'package:daylight_commander/domain/entities/file_entry.dart';
import 'package:daylight_commander/presentation/home/pane_controller.dart';
import 'package:daylight_commander/presentation/home/pane_view.dart' show breakableName;
import 'package:daylight_commander/presentation/home/pane_view_mode_provider.dart';
import 'package:daylight_commander/presentation/widgets/thumbnail_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FileEntry _file(
  String path, {
  int size = 1000,
  FileSourceType source = FileSourceType.local,
  Uri? location,
}) => FileEntry(
  location: location ?? Uri.file(path),
  name: path.split('/').last,
  isDirectory: false,
  sizeBytes: size,
  source: source,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThumbnailPolicy', () {
    final policy = ThumbnailPolicy(networkMounts: {'/Volumes/share'});

    test('로컬 이미지는 raster, svg는 svg, 그 외는 null', () {
      expect(policy.kindFor(_file('/a/b.JPG')), ThumbnailKind.raster);
      expect(policy.kindFor(_file('/a/b.png')), ThumbnailKind.raster);
      expect(policy.kindFor(_file('/a/b.svg')), ThumbnailKind.svg);
      expect(policy.kindFor(_file('/a/b.txt')), isNull);
      expect(policy.kindFor(_file('/a/noext')), isNull);
    });

    test('너무 큰 파일은 썸네일을 만들지 않는다', () {
      expect(
        policy.kindFor(_file('/a/b.png', size: maxRasterThumbnailBytes + 1)),
        isNull,
      );
      expect(
        policy.kindFor(_file('/a/b.svg', size: maxSvgThumbnailBytes + 1)),
        isNull,
      );
    });

    test('폴더와 원격 스킴, 네트워크 마운트는 제외한다', () {
      expect(
        policy.kindFor(
          FileEntry(
            location: Uri.file('/a/dir.png'),
            name: 'dir.png',
            isDirectory: true,
          ),
        ),
        isNull,
      );
      expect(
        policy.kindFor(
          _file(
            'x.png',
            source: FileSourceType.sftp,
            location: Uri.parse('sftp://h/x.png'),
          ),
        ),
        isNull,
      );
      expect(policy.kindFor(_file('/Volumes/share/pic.png')), isNull);
      expect(
        policy.kindFor(_file('/Volumes/shared2/pic.png')),
        ThumbnailKind.raster,
      );
    });

    test('mount 출력에서 네트워크 마운트만 뽑는다', () {
      const mac = '''
/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)
//user@nas/share on /Volumes/share (smbfs, nodev, nosuid, mounted by user)
nas:/export on /Volumes/nfs (nfs, nodev)
''';
      expect(parseNetworkMounts(mac), {'/Volumes/share', '/Volumes/nfs'});
      const linux = '''
/dev/sda1 / ext4 rw 0 0
//nas/share /mnt/x cifs rw 0 0
''';
      expect(parseNetworkMounts(linux), {'/mnt/x'});
    });
  });

  group('ThumbnailQueue', () {
    test('동시 실행 수를 제한하고 release하면 다음을 시작한다', () async {
      final queue = ThumbnailQueue(maxConcurrent: 2);
      final t1 = queue.acquire();
      final t2 = queue.acquire();
      final t3 = queue.acquire();
      var third = false;
      t3.granted.then((_) => third = true);
      await Future<void>.delayed(Duration.zero);
      expect(third, isFalse);
      queue.release(t1);
      await Future<void>.delayed(Duration.zero);
      expect(third, isTrue);
      queue.release(t2);
      queue.release(t3);
    });

    test('대기 중 취소하면 슬롯을 쓰지 않는다', () async {
      final queue = ThumbnailQueue(maxConcurrent: 1);
      final t1 = queue.acquire();
      final t2 = queue.acquire();
      var granted = false;
      t2.granted.then((_) => granted = true);
      queue.cancel(t2);
      queue.release(t1);
      await Future<void>.delayed(Duration.zero);
      expect(granted, isFalse);
    });
  });

  group('PaneViewSettings', () {
    test('모드 전환과 크기 순환이 패널별로 저장된다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final left = container.read(
        paneViewSettingsProvider(PaneSide.left).notifier,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(paneViewSettingsProvider(PaneSide.left)).isThumbnails,
        isFalse,
      );
      left.toggleMode();
      left.cycleThumbnailSize();
      expect(
        container.read(paneViewSettingsProvider(PaneSide.left)).isThumbnails,
        isTrue,
      );
      expect(
        container.read(paneViewSettingsProvider(PaneSide.right)).isThumbnails,
        isFalse,
      );
      expect(
        container.read(paneViewSettingsProvider(PaneSide.left)).thumbnailSize,
        ThumbnailSize.large,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pane_view_mode_left'), 'thumbnails');
      expect(prefs.getString('pane_thumb_size_left'), 'large');
    });
  });

  test('긴 이름은 구분 문자 뒤에 줄바꿈 후보를 넣는다', () {
    expect(breakableName('dart_defines.local.example.json'),
        'dart_\u200Bdefines.\u200Blocal.\u200Bexample.\u200Bjson');
    expect(breakableName('plain'), 'plain');
  });
}
