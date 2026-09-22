import '../../domain/entities/file_entry.dart';
import 'pane_controller.dart';

/// 패널 간/패널 내부 드래그앤드롭으로 옮기는 항목들.
class DragPayload {
  const DragPayload({required this.fromSide, required this.entries});

  final PaneSide fromSide;
  final List<FileEntry> entries;
}
