import 'dart:io';

import 'package:path/path.dart' as p;

/// desktop_drop(macOS)이 Finder 드롭을 파일 프로미스로 받을 때 원본을
/// 복사해 두는 임시 폴더(`NSTemporaryDirectory()/Drops`)를 관리한다.
///
/// 플러그인은 이 폴더를 비우지 않는다. 같은 이름을 다시 드롭하면 이전 사본이
/// 남아 있어 Finder가 "이름 2"로 받고, 그 이름이 그대로 패널에 복사된다.
/// 드롭 처리가 끝날 때마다, 그리고 앱을 시작할 때 비운다.
class DropPromiseCache {
  const DropPromiseCache();

  String get _dir => p.join(Directory.systemTemp.path, 'Drops');

  bool contains(String path) => p.isWithin(_dir, path);

  /// [paths] 중 임시 폴더 안에 받은 사본만 지운다.
  Future<void> discard(Iterable<String> paths) async {
    for (final path in paths.where(contains)) {
      await _delete(path);
    }
  }

  /// 이전 실행에서 남은 사본을 모두 지운다.
  Future<void> clear() async {
    if (!Platform.isMacOS) return;
    final dir = Directory(_dir);
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        await _delete(entity.path);
      }
    } on FileSystemException {
      // 정리는 best-effort — 실패해도 드롭 자체에는 지장이 없다.
    }
  }

  Future<void> _delete(String path) async {
    try {
      if (await FileSystemEntity.type(path, followLinks: false) ==
          FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else {
        await File(path).delete();
      }
    } on FileSystemException {
      // 이미 사라졌거나 지울 수 없으면 그대로 둔다.
    }
  }
}
