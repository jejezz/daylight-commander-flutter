import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'thumbnail_policy.dart';

/// 앱 전체에서 하나. 마운트 목록은 만들 때 한 번 읽고, 이후 폴더를 열 때마다
/// 호출자가 [ThumbnailPolicy.refreshNetworkMounts]로 갱신할 수 있다.
final thumbnailPolicyProvider = Provider<ThumbnailPolicy>((ref) {
  final policy = ThumbnailPolicy();
  policy.refreshNetworkMounts();
  return policy;
});
