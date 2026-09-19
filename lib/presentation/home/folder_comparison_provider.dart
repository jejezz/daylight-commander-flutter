import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/file_entry.dart';
import 'pane_controller.dart';

enum FileDiffStatus { onlyHere, differs }

/// 좌우 패널의 현재 폴더를 이름 기준으로 비교한다. 폴더 비교 모드가 꺼져
/// 있으면 null (PLAN.md P2 — "폴더 비교").
class FolderComparison {
  const FolderComparison({required this.left, required this.right});

  final Map<Uri, FileDiffStatus> left;
  final Map<Uri, FileDiffStatus> right;
}

bool _contentDiffers(FileEntry a, FileEntry b) =>
    !a.isDirectory &&
    !b.isDirectory &&
    (a.sizeBytes != b.sizeBytes ||
        a.modifiedAt?.millisecondsSinceEpoch != b.modifiedAt?.millisecondsSinceEpoch);

/// 이름 기준으로 두 목록을 비교한 순수 함수. 실제 비교 규칙이 여기에 있으므로
/// Riverpod 없이 바로 단위테스트할 수 있다.
FolderComparison compareFolders(List<FileEntry> left, List<FileEntry> right) {
  final leftByName = {for (final e in left) e.name: e};
  final rightByName = {for (final e in right) e.name: e};

  final leftResult = <Uri, FileDiffStatus>{};
  for (final entry in leftByName.values) {
    final other = rightByName[entry.name];
    if (other == null) {
      leftResult[entry.location] = FileDiffStatus.onlyHere;
    } else if (_contentDiffers(entry, other)) {
      leftResult[entry.location] = FileDiffStatus.differs;
    }
  }

  final rightResult = <Uri, FileDiffStatus>{};
  for (final entry in rightByName.values) {
    final other = leftByName[entry.name];
    if (other == null) {
      rightResult[entry.location] = FileDiffStatus.onlyHere;
    } else if (_contentDiffers(entry, other)) {
      rightResult[entry.location] = FileDiffStatus.differs;
    }
  }

  return FolderComparison(left: leftResult, right: rightResult);
}

/// 양쪽에 다 있지만 내용이 다른 파일들을 이름으로 짝지어 돌려준다. 양방향
/// 동기화에서 그 파일 하나하나에 대해 어느 쪽을 쓸지 물어볼 때 쓴다.
List<(FileEntry left, FileEntry right)> diffPairs(List<FileEntry> left, List<FileEntry> right) {
  final leftByName = {for (final e in left) e.name: e};
  final rightByName = {for (final e in right) e.name: e};

  final pairs = <(FileEntry, FileEntry)>[];
  for (final entry in leftByName.values) {
    final other = rightByName[entry.name];
    if (other != null && _contentDiffers(entry, other)) {
      pairs.add((entry, other));
    }
  }
  return pairs;
}

/// 폴더 비교 모드 on/off.
final compareModeProvider = StateProvider<bool>((ref) => false);

final folderComparisonProvider = Provider<FolderComparison?>((ref) {
  final enabled = ref.watch(compareModeProvider);
  if (!enabled) return null;

  final left = ref.watch(paneControllerProvider(PaneSide.left));
  final right = ref.watch(paneControllerProvider(PaneSide.right));
  return compareFolders(left.entries, right.entries);
});
