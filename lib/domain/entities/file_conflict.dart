/// 복사/이동 중 대상 경로에 동일 이름 항목이 이미 있을 때 사용자에게 묻는다.
class FileConflict {
  const FileConflict({
    required this.sourcePath,
    required this.destinationPath,
    required this.sourceSizeBytes,
    required this.destinationSizeBytes,
    required this.sourceModifiedAt,
    required this.destinationModifiedAt,
    this.isDirectory = false,
  });

  final String sourcePath;
  final String destinationPath;
  final int? sourceSizeBytes;
  final int? destinationSizeBytes;
  final DateTime? sourceModifiedAt;
  final DateTime? destinationModifiedAt;

  /// 폴더끼리의 충돌이면 true. 이때 덮어쓰기는 대상 폴더를 통째로 교체하고,
  /// 이름 바꿔서 복사는 폴더 이름 자체를 바꾼다 (내용을 병합하지 않는다).
  final bool isDirectory;
}

enum ConflictAction { overwrite, overwriteAll, skip, skipAll, rename, cancel }
