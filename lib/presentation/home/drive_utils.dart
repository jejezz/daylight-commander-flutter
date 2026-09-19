import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/drive_entry.dart';

/// [path]가 속한 드라이브의 루트 경로를 찾는다 (드래그앤드롭 시 같은 드라이브인지
/// 판단하는 데 쓰인다). Windows는 드라이브 문자, macOS/Linux는 [drives] 목록 중
/// 가장 길게 일치하는 마운트 경로(예: `/Volumes/USB`)를 루트로 본다. FTP는
/// 항상 로컬과 다른 드라이브로 보고, 같은 서버·같은 사용자 세션끼리만 같은
/// 드라이브로 취급한다 (그래야 드래그 기본 동작이 "같은 서버 안=이동,
/// 그 외=복사"가 된다).
String driveRootFor(String path, List<DriveEntry> drives) {
  if (path.startsWith('ftp://')) {
    final uri = Uri.parse(path);
    return 'ftp://${uri.userInfo}@${uri.host}:${uri.hasPort ? uri.port : 21}';
  }
  if (Platform.isWindows) return p.rootPrefix(path);
  var best = '/';
  for (final drive in drives) {
    final root = drive.path;
    if (root == '/') continue;
    if (path == root || path.startsWith('$root/')) {
      if (root.length > best.length) best = root;
    }
  }
  return best;
}

bool isSameDrive(String pathA, String pathB, List<DriveEntry> drives) =>
    driveRootFor(pathA, drives) == driveRootFor(pathB, drives);
