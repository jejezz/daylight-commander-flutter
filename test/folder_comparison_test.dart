import 'package:flutter_test/flutter_test.dart';

import 'package:daylight_commander/domain/entities/file_entry.dart';
import 'package:daylight_commander/presentation/home/folder_comparison_provider.dart';

FileEntry _file(String name, {int? size, DateTime? modified}) {
  return FileEntry(
    location: Uri.file('/left/$name'),
    name: name,
    isDirectory: false,
    sizeBytes: size,
    modifiedAt: modified,
  );
}

FileEntry _dir(String name) {
  return FileEntry(location: Uri.file('/left/$name'), name: name, isDirectory: true);
}

void main() {
  test('한쪽에만 있는 항목은 onlyHere로 표시된다', () {
    final left = [_file('a.txt', size: 10)];
    final right = <FileEntry>[];

    final result = compareFolders(left, right);

    expect(result.left.values.single, FileDiffStatus.onlyHere);
    expect(result.right, isEmpty);
  });

  test('크기가 다르면 differs로 표시된다', () {
    final left = [_file('a.txt', size: 10)];
    final right = [_file('a.txt', size: 20)];

    final result = compareFolders(left, right);

    expect(result.left.values.single, FileDiffStatus.differs);
    expect(result.right.values.single, FileDiffStatus.differs);
  });

  test('크기와 수정일이 같으면 표시되지 않는다 (동일 파일)', () {
    final modified = DateTime(2026, 1, 1);
    final left = [_file('a.txt', size: 10, modified: modified)];
    final right = [_file('a.txt', size: 10, modified: modified)];

    final result = compareFolders(left, right);

    expect(result.left, isEmpty);
    expect(result.right, isEmpty);
  });

  test('폴더는 이름이 같으면 내용 비교 없이 동일하다고 본다', () {
    final left = [_dir('sub')];
    final right = [_dir('sub')];

    final result = compareFolders(left, right);

    expect(result.left, isEmpty);
    expect(result.right, isEmpty);
  });
}
