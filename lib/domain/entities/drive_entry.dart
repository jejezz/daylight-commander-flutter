/// Windows의 `GetDriveType`으로 구분한 드라이브 종류. macOS/Linux는 아직
/// 구분할 방법이 없어 전부 [unknown]이다.
enum DriveKind { unknown, fixed, removable, network }

/// 드라이브/볼륨 전환 메뉴에 표시되는 항목 (로컬 디스크, 외장 디스크, 마운트된
/// 네트워크 드라이브 등 — SMB는 OS 마운트 방식이라 `/Volumes` 등에 그대로 잡힌다).
class DriveEntry {
  const DriveEntry({required this.name, required this.path, this.kind = DriveKind.unknown});

  final String name;
  final String path;
  final DriveKind kind;
}
