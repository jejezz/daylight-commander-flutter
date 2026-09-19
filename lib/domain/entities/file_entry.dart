enum FileSourceType { local, smb, ftp, sftp, webdav }

/// 패널에 표시되는 파일/폴더 한 항목 (ARCHITECTURE.md 3장).
class FileEntry {
  const FileEntry({
    required this.location,
    required this.name,
    required this.isDirectory,
    this.sizeBytes,
    this.modifiedAt,
    this.isHidden = false,
    this.source = FileSourceType.local,
  });

  final Uri location;
  final String name;
  final bool isDirectory;
  final int? sizeBytes;
  final DateTime? modifiedAt;
  final bool isHidden;
  final FileSourceType source;
}
