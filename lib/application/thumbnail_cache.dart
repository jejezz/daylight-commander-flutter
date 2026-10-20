import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 디스크 캐시에서 찾은 결과. [file]이 null이면 "썸네일을 만들 수 없는 파일"이라는 기록이라,
/// 다시 시도하지 않고 아이콘만 보인다(예: 앨범 아트가 없는 mp3).
class CachedThumbnail {
  const CachedThumbnail(this.file);

  final File? file;
}

/// 생성한 썸네일(PNG)을 파일로 저장해 두는 디스크 캐시.
///
/// 키는 경로·수정 시각·크기·썸네일 크기로 만든다 — 파일이 바뀌면 키도 바뀌어 옛 캐시는
/// 저절로 쓰이지 않게 되고, 용량 상한을 넘으면 오래 안 쓴 것부터 지운다.
class DiskThumbnailCache {
  // ignore: prefer_initializing_formals
  DiskThumbnailCache({Directory? directory, this.maxBytes = 200 * 1024 * 1024}) : _directory = directory;

  final int maxBytes;
  Directory? _directory;
  int _writesSinceTrim = 0;

  /// 앱 캐시 폴더 밑 `thumbnails`. OS가 공간이 부족할 때 지울 수 있는 위치다.
  Future<Directory> _dir() async {
    final existing = _directory;
    if (existing != null) return existing;
    final base = await getApplicationCacheDirectory();
    final dir = Directory(p.join(base.path, 'thumbnails'));
    await dir.create(recursive: true);
    return _directory = dir;
  }

  /// 같은 파일·같은 크기 구간이면 같은 키. 크기는 64px 단위로 올려 잡아, 창 크기를 조금
  /// 바꿔도 캐시를 다시 만들지 않는다.
  static String keyFor({
    required String path,
    required int? modifiedMs,
    required int? sizeBytes,
    required int extent,
  }) {
    final bucket = ((extent + 63) ~/ 64) * 64;
    final raw = '$path|${modifiedMs ?? 0}|${sizeBytes ?? 0}|$bucket';
    return sha1.convert(raw.codeUnits).toString();
  }

  Future<File> _fileFor(String key) async => File(p.join((await _dir()).path, '$key.png'));

  Future<CachedThumbnail?> lookup(String key) async {
    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;
      if (await file.length() == 0) return const CachedThumbnail(null);
      // 최근에 쓴 것으로 표시해 용량 정리에서 늦게 지워지게 한다.
      file.setLastModified(DateTime.now());
      return CachedThumbnail(file);
    } catch (_) {
      return null;
    }
  }

  /// 결과를 저장한다. [bytes]가 null이면 "만들 수 없음" 기록(빈 파일)을 남긴다.
  Future<File?> store(String key, Uint8List? bytes) async {
    try {
      final file = await _fileFor(key);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes ?? Uint8List(0), flush: true);
      await tmp.rename(file.path);
      if (++_writesSinceTrim >= 50) {
        _writesSinceTrim = 0;
        trim();
      }
      return bytes == null ? null : file;
    } catch (_) {
      return null;
    }
  }

  /// 용량 상한을 넘으면 오래 안 쓴 파일부터 상한의 80%가 될 때까지 지운다.
  Future<void> trim() async {
    try {
      final dir = await _dir();
      final files = <File, FileStat>{};
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        files[entity] = stat;
        total += stat.size;
      }
      if (total <= maxBytes) return;
      final ordered = files.entries.toList()
        ..sort((a, b) => a.value.modified.compareTo(b.value.modified));
      final target = (maxBytes * 0.8).round();
      for (final entry in ordered) {
        if (total <= target) break;
        await entry.key.delete();
        total -= entry.value.size;
      }
    } catch (_) {}
  }

  /// 캐시가 차지하는 용량(바이트).
  Future<int> totalBytes() async {
    var total = 0;
    try {
      await for (final entity in (await _dir()).list()) {
        if (entity is File) total += await entity.length();
      }
    } catch (_) {}
    return total;
  }

  /// 캐시를 모두 지운다.
  Future<void> clear() async {
    try {
      final dir = await _dir();
      await for (final entity in dir.list()) {
        if (entity is File) await entity.delete();
      }
    } catch (_) {}
  }
}
