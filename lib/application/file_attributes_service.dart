import 'dart:io';

class FileAttributesInfo {
  const FileAttributesInfo({
    required this.sizeBytes,
    required this.modified,
    required this.permissionString,
    required this.isReadOnly,
    required this.posixMode,
  });

  final int sizeBytes;
  final DateTime? modified;
  final String permissionString;
  final bool isReadOnly;

  /// 하위 9비트(owner/group/other × rwx) POSIX 권한. Windows에서는 항상 0.
  final int posixMode;
}

/// POSIX 권한 그리드에 쓰이는 비트 상수. 행=owner/group/other, 열=read/write/execute.
class PosixPermissionBits {
  const PosixPermissionBits._();

  static const grid = [
    [256, 128, 64], // owner: r,w,x (0o400, 0o200, 0o100)
    [32, 16, 8], // group: r,w,x (0o040, 0o020, 0o010)
    [4, 2, 1], // other: r,w,x (0o004, 0o002, 0o001)
  ];
}

/// 파일/폴더 속성 조회 및 권한 변경.
///
/// macOS/Linux는 POSIX 권한 그리드(owner/group/other × rwx)를 전부 편집할 수
/// 있고, Windows는 POSIX 권한이 없으므로 "읽기 전용" 속성만 지원한다.
class FileAttributesService {
  const FileAttributesService();

  static const _ownerWriteBit = 0x80; // POSIX 0o200
  static const _posixMask = 0x1FF; // 하위 9비트 (rwxrwxrwx)

  Future<FileAttributesInfo> loadInfo(String path, {required bool isDirectory}) async {
    final stat = await FileStat.stat(path);
    final size = isDirectory ? await _folderSizeRecursive(Directory(path)) : stat.size;
    final readOnly = await isReadOnly(path, stat: stat);
    return FileAttributesInfo(
      sizeBytes: size,
      modified: stat.modified,
      permissionString: stat.modeString(),
      isReadOnly: readOnly,
      posixMode: Platform.isWindows ? 0 : (stat.mode & _posixMask),
    );
  }

  Future<bool> isReadOnly(String path, {FileStat? stat}) async {
    if (Platform.isWindows) {
      final result = await Process.run('attrib', [path]);
      return result.stdout.toString().contains('R');
    }
    final s = stat ?? await FileStat.stat(path);
    return (s.mode & _ownerWriteBit) == 0;
  }

  Future<void> setReadOnly(String path, bool readOnly) async {
    if (Platform.isWindows) {
      await Process.run('attrib', [readOnly ? '+r' : '-r', path]);
      return;
    }
    await Process.run('chmod', [readOnly ? 'a-w' : 'u+w', path]);
  }

  /// [mode]는 하위 9비트(owner/group/other × rwx)만 사용한다. Windows에서는 호출하지 않는다.
  Future<void> setPosixMode(String path, int mode) async {
    final octal = (mode & _posixMask).toRadixString(8).padLeft(3, '0');
    await Process.run('chmod', [octal, path]);
  }

  Future<int> _folderSizeRecursive(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // 권한 문제 등으로 크기를 못 읽는 항목은 건너뛴다.
        }
      }
    }
    return total;
  }
}
