import 'dart:io';

import 'package:flutter/painting.dart';

import 'thumbnail_cache.dart';
import 'thumbnail_generator.dart';
import 'thumbnail_policy.dart';

/// [kind] 파일의 썸네일을 그릴 [ImageProvider]를 얻는다. 만들 수 없으면 null.
///
/// 작은 래스터 이미지는 디코딩이 싸서 원본을 줄여 바로 읽고, 큰 이미지와 PDF·비디오·오디오는
/// 디스크 캐시를 거친다(있으면 재사용, 없으면 만들어 저장). svg와 text는 위젯이 직접 그린다.
Future<ImageProvider?> resolveThumbnailProvider({
  required ThumbnailKind kind,
  required String path,
  required int? modifiedMs,
  required int? sizeBytes,
  required int px,
  required DiskThumbnailCache cache,
  required ThumbnailGenerator generator,
}) async {
  final viaCache =
      kind.usesDiskCache ||
      (kind == ThumbnailKind.raster &&
          (sizeBytes ?? 0) >= diskCachedRasterBytes);
  if (!viaCache) {
    return ResizeImage(FileImage(File(path)), width: px, allowUpscaling: false);
  }
  try {
    final key = DiskThumbnailCache.keyFor(
      path: path,
      modifiedMs: modifiedMs,
      sizeBytes: sizeBytes,
      extent: px,
    );
    final hit = await cache.lookup(key);
    final file = hit != null
        ? hit.file
        : await cache.store(key, await generator.generate(kind, path, px));
    return file == null ? null : FileImage(file);
  } catch (_) {
    return null;
  }
}
