import 'dart:io';
import 'dart:typed_data';

import 'package:daylight_commander/application/folder_preview.dart';
import 'package:daylight_commander/application/thumbnail_cache.dart';
import 'package:daylight_commander/application/thumbnail_policy.dart';
import 'package:daylight_commander/domain/entities/file_entry.dart';
import 'package:daylight_commander/presentation/home/pane_controller.dart';
import 'package:daylight_commander/presentation/home/pane_view.dart'
    show breakableName;
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
      expect(policy.kindFor(_file('/a/b.docx')), isNull);
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

  group('ThumbnailPolicy 종류 확장', () {
    final policy = ThumbnailPolicy();
    test('pdf·비디오·오디오·텍스트도 종류를 정한다', () {
      expect(policy.kindFor(_file('/a/doc.PDF')), ThumbnailKind.pdf);
      expect(policy.kindFor(_file('/a/clip.mp4')), ThumbnailKind.video);
      expect(policy.kindFor(_file('/a/song.mp3')), ThumbnailKind.audio);
      expect(policy.kindFor(_file('/a/readme.md')), ThumbnailKind.text);
      expect(
        policy.kindFor(_file('/a/doc.pdf', size: maxPdfThumbnailBytes + 1)),
        isNull,
      );
    });

    test('원격 스킴의 pdf·비디오는 만들지 않는다', () {
      expect(
        policy.kindFor(
          _file(
            'x.pdf',
            source: FileSourceType.webdav,
            location: Uri.parse('webdav://h/x.pdf'),
          ),
        ),
        isNull,
      );
    });
  });

  group('DiskThumbnailCache', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('thumbcache'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('키는 파일이 바뀌면 달라지고 크기는 64px 구간으로 묶인다', () {
      String k({int mtime = 1, int size = 10, int extent = 100}) =>
          DiskThumbnailCache.keyFor(
            path: '/a.pdf',
            modifiedMs: mtime,
            sizeBytes: size,
            extent: extent,
          );
      expect(k(), k());
      expect(k(), isNot(k(mtime: 2)));
      expect(k(), isNot(k(size: 11)));
      expect(k(extent: 100), k(extent: 120)); // 둘 다 128 구간
      expect(k(extent: 100), isNot(k(extent: 130)));
    });

    test('저장한 PNG를 찾고, 만들 수 없음은 빈 기록으로 남는다', () async {
      final cache = DiskThumbnailCache(directory: dir);
      expect(await cache.lookup('abc'), isNull);

      final stored = await cache.store('abc', Uint8List.fromList([1, 2, 3]));
      expect(stored, isNotNull);
      final hit = await cache.lookup('abc');
      expect(hit!.file!.readAsBytesSync(), [1, 2, 3]);

      expect(await cache.store('none', null), isNull);
      final negative = await cache.lookup('none');
      expect(negative, isNotNull);
      expect(negative!.file, isNull);
    });

    test('용량을 넘으면 오래 안 쓴 것부터 지운다', () async {
      final cache = DiskThumbnailCache(directory: dir, maxBytes: 100);
      for (var i = 0; i < 4; i++) {
        final file = await cache.store('k$i', Uint8List(40));
        file!.setLastModifiedSync(DateTime(2026, 1, 1 + i));
      }
      await cache.trim();
      expect(await cache.lookup('k0'), isNull);
      expect(await cache.lookup('k1'), isNull);
      expect(await cache.lookup('k3'), isNotNull);
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
    expect(
      breakableName('dart_defines.local.example.json'),
      'dart_\u200Bdefines.\u200Blocal.\u200Bexample.\u200Bjson',
    );
    expect(breakableName('plain'), 'plain');
  });

  group('폴더 썸네일', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('folderprev'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('안의 이미지 중 이름순 앞 4장을 고르고 숨김·비이미지·하위 폴더는 건너뛴다', () async {
      for (final name in [
        'e.png',
        'b.jpg',
        'a.PNG',
        'd.gif',
        'c.webp',
        '.hidden.png',
        'note.txt',
      ]) {
        File('${dir.path}/$name').writeAsBytesSync([1, 2, 3]);
      }
      Directory('${dir.path}/sub').createSync();
      File('${dir.path}/sub/z.png').writeAsBytesSync([1]);

      final images = await FolderPreviewFinder().find(dir.path, 1);
      expect(images.map((i) => i.path.split('/').last), [
        'a.PNG',
        'b.jpg',
        'c.webp',
        'd.gif',
      ]);
    });

    test('이미지가 없으면 빈 목록이고, 폴더 수정 시각이 같으면 결과를 재사용한다', () async {
      final finder = FolderPreviewFinder();
      expect(await finder.find(dir.path, 1), isEmpty);
      File('${dir.path}/a.png').writeAsBytesSync([1]);
      expect(await finder.find(dir.path, 1), isEmpty); // 같은 수정 시각 → 캐시
      expect(await finder.find(dir.path, 2), hasLength(1)); // 폴더가 바뀜 → 다시 훑음
    });

    test('로컬 폴더만 미리보기하고 원격 폴더와 파일은 제외한다', () {
      final policy = ThumbnailPolicy(networkMounts: {'/Volumes/share'});
      FileEntry folder(
        Uri location, {
        FileSourceType source = FileSourceType.local,
      }) => FileEntry(
        location: location,
        name: 'f',
        isDirectory: true,
        source: source,
      );
      expect(policy.canPreviewFolder(folder(Uri.file('/a/f'))), isTrue);
      expect(
        policy.canPreviewFolder(folder(Uri.file('/Volumes/share/f'))),
        isFalse,
      );
      expect(
        policy.canPreviewFolder(
          folder(Uri.parse('sftp://h/f'), source: FileSourceType.sftp),
        ),
        isFalse,
      );
      expect(policy.canPreviewFolder(_file('/a/f.png')), isFalse);
    });
  });

  test('썸네일 크기 단계 조절은 끝에서 멈추고 저장된다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      paneViewSettingsProvider(PaneSide.left).notifier,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    ThumbnailSize size() =>
        container.read(paneViewSettingsProvider(PaneSide.left)).thumbnailSize;

    expect(size(), ThumbnailSize.medium);
    notifier.stepThumbnailSize(1);
    expect(size(), ThumbnailSize.large);
    notifier.stepThumbnailSize(1);
    expect(size(), ThumbnailSize.large); // 끝에서 더 가지 않는다
    notifier.stepThumbnailSize(-2);
    expect(size(), ThumbnailSize.small);
    notifier.setThumbnailSize(ThumbnailSize.medium);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await SharedPreferences.getInstance()).getString('pane_thumb_size_left'),
      'medium',
    );
  });

  test('캐시 용량 합계를 구하고 비운다', () async {
    final dir = Directory.systemTemp.createTempSync('thumbtotal');
    addTearDown(() => dir.deleteSync(recursive: true));
    final cache = DiskThumbnailCache(directory: dir);
    await cache.store('a', Uint8List(100));
    await cache.store('b', Uint8List(50));
    expect(await cache.totalBytes(), 150);
    await cache.clear();
    expect(await cache.totalBytes(), 0);
  });
}
