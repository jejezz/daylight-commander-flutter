import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'thumbnail_policy.dart';

/// 폴더 썸네일에 쓸 안쪽 이미지 한 장.
class FolderImage {
  const FolderImage({
    required this.path,
    required this.modifiedMs,
    required this.sizeBytes,
  });

  final String path;
  final int modifiedMs;
  final int sizeBytes;
}

/// 폴더 안에서 썸네일로 보여 줄 이미지를 찾는다.
///
/// 폴더를 처음 [maxScan]개 항목까지만 훑고(수만 개짜리 폴더도 한 번에 끝나게), 그중 이름순으로
/// 앞선 래스터 이미지 [maxImages]장을 고른다. 폴더의 수정 시각이 같으면 결과를 재사용한다.
class FolderPreviewFinder {
  FolderPreviewFinder({
    this.maxScan = 300,
    this.maxImages = 4,
    this.maxCached = 500,
  });

  static final FolderPreviewFinder shared = FolderPreviewFinder();

  final int maxScan;
  final int maxImages;
  final int maxCached;
  final LinkedHashMap<String, List<FolderImage>> _cache = LinkedHashMap();

  Future<List<FolderImage>> find(String dirPath, int? modifiedMs) async {
    final key = '$dirPath|${modifiedMs ?? 0}';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // 최근에 쓴 것으로 옮긴다.
      return cached;
    }
    final result = await _scan(dirPath);
    _cache[key] = result;
    while (_cache.length > maxCached) {
      _cache.remove(_cache.keys.first);
    }
    return result;
  }

  Future<List<FolderImage>> _scan(String dirPath) async {
    final names = <String>[];
    try {
      await for (final entity in Directory(dirPath).list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        final dot = name.lastIndexOf('.');
        if (dot > 0 &&
            thumbnailRasterExtensions.contains(
              name.substring(dot + 1).toLowerCase(),
            )) {
          names.add(name);
        }
        if (names.length >= maxScan) break;
      }
    } catch (_) {
      return const [];
    }
    names.sort();
    final images = <FolderImage>[];
    for (final name in names) {
      if (images.length >= maxImages) break;
      try {
        final path = p.join(dirPath, name);
        final stat = await File(path).stat();
        if (stat.size > maxRasterThumbnailBytes) continue;
        images.add(
          FolderImage(
            path: path,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
            sizeBytes: stat.size,
          ),
        );
      } catch (_) {}
    }
    return images;
  }
}
