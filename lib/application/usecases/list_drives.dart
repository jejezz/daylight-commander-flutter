import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:win32/win32.dart' show GetLogicalDrives;

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

  // GetLogicalDrives()는 OS에 등록된 드라이브 문자를 커널 정보에서 바로
  // 읽어오는 방식이라(비트마스크) 실제 드라이브에 접근하지 않는다. 연결이
  // 끊긴 네트워크 드라이브가 있어도 Directory.exists()처럼 네트워크
  // 타임아웃(수 초~수십 초)만큼 멈추지 않고 즉시 반환된다. 실제 접근
  // 가능 여부는 사용자가 그 드라이브를 선택해 이동을 시도할 때
  // PaneController.navigateTo에서 확인하고 실패하면 에러를 보여준다.
  Future<List<DriveEntry>> _windowsDrives() async {
    final drives = <DriveEntry>[];
    final mask = GetLogicalDrives();
    for (var i = 0; i < 26; i++) {
      if (mask & (1 << i) == 0) continue;
      final letter = String.fromCharCode('A'.codeUnitAt(0) + i);
      final path = '$letter:\\';
      drives.add(DriveEntry(name: path, path: path));
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
