/// 복사/이동 중 대상 경로에 동일 이름 항목이 이미 있을 때 사용자에게 묻는다.
class FileConflict {
  const FileConflict({
    required this.sourcePath,
    required this.destinationPath,
    required this.sourceSizeBytes,
    required this.destinationSizeBytes,
    required this.sourceModifiedAt,
    required this.destinationModifiedAt,
  });

  final String sourcePath;
  final String destinationPath;
  final int? sourceSizeBytes;
  final int? destinationSizeBytes;
  final DateTime? sourceModifiedAt;
  final DateTime? destinationModifiedAt;
}

enum ConflictAction { overwrite, overwriteAll, skip, skipAll, rename, cancel }
