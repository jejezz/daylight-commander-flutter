import 'dart:io';

import '../domain/entities/file_entry.dart';

const thumbnailRasterExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
const thumbnailSvgExtensions = {'svg'};

/// 썸네일로 읽을 파일의 최대 크기. 이보다 크면 아이콘만 보인다.
const maxRasterThumbnailBytes = 50 * 1024 * 1024;
const maxSvgThumbnailBytes = 2 * 1024 * 1024;

enum ThumbnailKind { raster, svg }

/// 마운트 정보에서 네트워크 파일시스템 마운트 지점을 뽑는다.
/// macOS `mount` 출력(`//u@host/share on /Volumes/share (smbfs, ...)`)과
/// Linux `/proc/mounts`(`//host/share /mnt/x cifs rw 0 0`)를 모두 처리한다.
Set<String> parseNetworkMounts(String text) {
  const networkTypes = {
    'smbfs',
    'cifs',
    'smb3',
    'nfs',
    'nfs4',
    'afpfs',
    'webdav',
    'davfs',
    'fuse.sshfs',
    'fuse.davfs2',
  };
  final result = <String>{};
  for (final line in text.split('\n')) {
    String? mountPoint;
    String? type;
    final macMatch = RegExp(r'^.+ on (.+) \(([^,)]+)').firstMatch(line);
    if (macMatch != null) {
      mountPoint = macMatch.group(1);
      type = macMatch.group(2);
    } else {
      final parts = line.split(' ');
      if (parts.length >= 3) {
        mountPoint = parts[1];
        type = parts[2];
      }
    }
    if (mountPoint != null && type != null && networkTypes.contains(type)) {
      result.add(mountPoint);
    }
  }
  return result;
}

/// 어떤 항목에 썸네일을 만들지 결정하는 한 곳.
///
/// FTP/SFTP/WebDAV 같은 원격 스킴과, OS가 마운트한 SMB/NFS 등 네트워크
/// 드라이브는 썸네일을 만들려면 파일을 내려받아야 하므로 기본적으로 제외한다
/// (PLAN.md "미리보기·썸네일 단계 계획" 4단계에서 옵션으로 연다).
class ThumbnailPolicy {
  // ignore: prefer_initializing_formals
  ThumbnailPolicy({Set<String> networkMounts = const {}}) : _networkMounts = networkMounts;

  Set<String> _networkMounts;

  /// 마운트 목록을 다시 읽는다. 실패하면 이전 값을 유지한다.
  Future<void> refreshNetworkMounts() async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('mount', const []);
        if (result.exitCode == 0) {
          _networkMounts = parseNetworkMounts(result.stdout as String);
        }
      } else if (Platform.isLinux) {
        _networkMounts = parseNetworkMounts(
          await File('/proc/mounts').readAsString(),
        );
      }
    } catch (_) {
      // 감지 실패는 치명적이지 않다 — 로컬로 간주하고 계속한다.
    }
  }

  bool isNetworkLocation(Uri location) {
    if (location.scheme != 'file') return true;
    final path = location.toFilePath();
    if (Platform.isWindows) return path.startsWith(r'\\');
    for (final mount in _networkMounts) {
      if (path == mount || path.startsWith('$mount/')) return true;
    }
    return false;
  }

  /// [entry]에 만들 썸네일 종류. 만들지 않으면 null (아이콘만 표시).
  ThumbnailKind? kindFor(FileEntry entry) {
    if (entry.isDirectory || entry.source != FileSourceType.local) return null;
    if (isNetworkLocation(entry.location)) return null;
    final dot = entry.name.lastIndexOf('.');
    if (dot <= 0) return null;
    final ext = entry.name.substring(dot + 1).toLowerCase();
    final size = entry.sizeBytes;
    if (thumbnailRasterExtensions.contains(ext)) {
      if (size != null && size > maxRasterThumbnailBytes) return null;
      return ThumbnailKind.raster;
    }
    if (thumbnailSvgExtensions.contains(ext)) {
      if (size != null && size > maxSvgThumbnailBytes) return null;
      return ThumbnailKind.svg;
    }
    return null;
  }
}
