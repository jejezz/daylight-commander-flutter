import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/drive_entry.dart';

/// 현재 OS에서 전환 가능한 드라이브/볼륨 목록을 찾는다.
///
/// macOS는 `/Volumes` 아래에 외장 디스크와 OS 마운트된 SMB 공유가 함께 잡히므로
/// 별도의 SMB 전용 처리 없이도 드라이브 목록에 자연스럽게 나타난다
/// (ARCHITECTURE.md 4장 — SMB는 OS 마운트 방식으로 확정).
class ListDrives {
  const ListDrives();

  Future<List<DriveEntry>> call() async {
    if (Platform.isWindows) return _windowsDrives();
    if (Platform.isMacOS) return _macDrives();
    return _linuxDrives();
  }

  Future<List<DriveEntry>> _windowsDrives() async {
    final drives = <DriveEntry>[];
    for (final letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      final path = '$letter:\\';
      try {
        if (await Directory(path).exists()) {
          drives.add(DriveEntry(name: path, path: path));
        }
      } catch (_) {
        // 연결이 끊긴 네트워크 드라이브 등 접근할 수 없는 드라이브는 건너뛴다.
        // 여기서 예외를 던지면 이후 드라이브까지 전부 목록에서 사라진다.
      }
    }
    return drives;
  }

  Future<List<DriveEntry>> _macDrives() async {
    final drives = <DriveEntry>[const DriveEntry(name: 'Macintosh HD', path: '/')];
    final volumes = Directory('/Volumes');
    if (await volumes.exists()) {
      await for (final entity in volumes.list(followLinks: false)) {
        if (entity is Directory) {
          drives.add(DriveEntry(name: p.basename(entity.path), path: entity.path));
        }
      }
    }
    return drives;
  }

  Future<List<DriveEntry>> _linuxDrives() async {
    final drives = <DriveEntry>[const DriveEntry(name: '/ (루트)', path: '/')];
    final user = Platform.environment['USER'] ?? '';
    for (final base in ['/media/$user', '/mnt', '/run/media/$user']) {
      final dir = Directory(base);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          drives.add(DriveEntry(name: p.basename(entity.path), path: entity.path));
        }
      }
    }
    return drives;
  }
}
