import 'dart:io';

import 'package:flutter/material.dart';

import '../../application/file_attributes_service.dart';
import '../../core/bytes_format.dart';
import '../../core/date_format.dart';
import '../../domain/entities/file_entry.dart';

Future<void> showPropertiesDialog(BuildContext context, FileEntry entry) {
  return showDialog<void>(
    context: context,
    builder: (context) => _PropertiesDialog(entry: entry),
  );
}

class _PropertiesDialog extends StatefulWidget {
  const _PropertiesDialog({required this.entry});

  final FileEntry entry;

  @override
  State<_PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends State<_PropertiesDialog> {
  static const _service = FileAttributesService();
  static const _rowLabels = ['소유자', '그룹', '기타'];
  static const _colLabels = ['읽기', '쓰기', '실행'];

  FileAttributesInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await _service.loadInfo(
      widget.entry.location.toFilePath(),
      isDirectory: widget.entry.isDirectory,
    );
    if (mounted) setState(() => _info = info);
  }

  Future<void> _toggleReadOnly(bool value) async {
    await _service.setReadOnly(widget.entry.location.toFilePath(), value);
    await _load();
  }

  Future<void> _togglePosixBit(int bit) async {
    final info = _info;
    if (info == null) return;
    final nextMode = info.posixMode ^ bit;
    await _service.setPosixMode(widget.entry.location.toFilePath(), nextMode);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final info = _info;
    return AlertDialog(
      title: const Text('속성'),
      content: SizedBox(
        width: 380,
        child: info == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('이름', entry.name),
                  _row('경로', entry.location.toFilePath()),
                  _row('종류', entry.isDirectory ? '폴더' : '파일'),
                  _row('크기', formatBytes(info.sizeBytes)),
                  _row('수정일', formatModified(info.modified)),
                  _row('권한', info.permissionString),
                  const SizedBox(height: 12),
                  if (Platform.isWindows)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: info.isReadOnly,
                      onChanged: (v) => _toggleReadOnly(v ?? false),
                      title: const Text('읽기 전용'),
                    )
                  else
                    _PermissionGrid(
                      mode: info.posixMode,
                      rowLabels: _rowLabels,
                      colLabels: _colLabels,
                      onToggle: _togglePosixBit,
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PermissionGrid extends StatelessWidget {
  const _PermissionGrid({
    required this.mode,
    required this.rowLabels,
    required this.colLabels,
    required this.onToggle,
  });

  final int mode;
  final List<String> rowLabels;
  final List<String> colLabels;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Table(
      columnWidths: const {0: FixedColumnWidth(60)},
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            for (final label in colLabels)
              Center(child: Text(label, style: style)),
          ],
        ),
        for (var r = 0; r < rowLabels.length; r++)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(rowLabels[r], style: style),
              ),
              for (var c = 0; c < colLabels.length; c++)
                Center(
                  child: Checkbox(
                    value: (mode & PosixPermissionBits.grid[r][c]) != 0,
                    onChanged: (_) => onToggle(PosixPermissionBits.grid[r][c]),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
