import '../../domain/entities/file_entry.dart';
import 'pane_controller.dart';

/// 패널 간/패널 내부 드래그앤드롭으로 옮기는 항목들. 로컬 파일을 단일
/// 선택으로 끌 때는 [DragItem.localData]로도 실려서, 같은 세션이 앱 내부로
/// 돌아왔을 때(다른 패널/폴더로 드롭)와 OS 밖으로 나갔을 때를 구분하는 데
/// 쓰인다.
class DragPayload {
  const DragPayload({required this.fromSide, required this.entries});

  final PaneSide fromSide;
  final List<FileEntry> entries;
}
