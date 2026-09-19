import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

const _textExtensions = {
  'txt', 'md', 'json', 'xml', 'html', 'htm', 'css', 'java', 'dart', 'py', 'js',
  'ts', 'yaml', 'yml', 'sql', 'sh', 'log', 'ini', 'csv', 'c', 'cpp', 'h', 'kt',
  'swift', 'gradle',
};
const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

String _extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

/// 자체 뷰어 (F3). 텍스트/이미지/Hex를 지원하고, 그 외 형식은 OS 기본 앱으로
/// 열도록 안내한다 (PDF/미디어 뷰어는 P2 범위 밖 — UI_UX.md 참고).
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.path, required this.name});

  final String path;
  final String name;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  bool _showHex = false;

  @override
  Widget build(BuildContext context) {
    final ext = _extensionOf(widget.name);
    final Widget body;
    if (_showHex) {
      body = _HexViewer(path: widget.path);
    } else if (_imageExtensions.contains(ext)) {
      body = _ImageViewer(path: widget.path);
    } else if (_textExtensions.contains(ext)) {
      body = _TextViewer(path: widget.path);
    } else {
      body = _UnsupportedViewer(path: widget.path);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        toolbarHeight: 44,
        actions: [
          IconButton(
            icon: Icon(_showHex ? Icons.description_outlined : Icons.memory),
            tooltip: _showHex ? '일반 보기' : 'Hex로 보기',
            onPressed: () => setState(() => _showHex = !_showHex),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.1,
      maxScale: 8,
      child: Center(
        child: Image.file(
          File(path),
          errorBuilder: (context, error, stack) => Text('이미지를 열 수 없습니다: $error'),
        ),
      ),
    );
  }
}

class _TextViewer extends StatefulWidget {
  const _TextViewer({required this.path});

  final String path;

  @override
  State<_TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<_TextViewer> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        // 인코딩 자동 감지는 아직 없음(P2) — UTF-8 실패 시 Latin-1로 폴백.
        text = latin1.decode(bytes);
      }
      if (mounted) setState(() => _content = text);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (_content == null) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _content!,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}

class _HexViewer extends StatefulWidget {
  const _HexViewer({required this.path});

  final String path;

  @override
  State<_HexViewer> createState() => _HexViewerState();
}

class _HexViewerState extends State<_HexViewer> {
  // 큰 파일 전체를 메모리에 올리지 않도록 미리보기 상한을 둔다 (스트리밍은 P2 후순위).
  static const _maxBytes = 262144;

  Uint8List? _bytes;
  bool _truncated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = File(widget.path);
      final length = await file.length();
      final raf = await file.open();
      final readLen = length > _maxBytes ? _maxBytes : length;
      final bytes = await raf.read(readLen);
      await raf.close();
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _truncated = length > _maxBytes;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    final bytes = _bytes;
    if (bytes == null) return const Center(child: CircularProgressIndicator());

    final rowCount = (bytes.length / 16).ceil();
    return Column(
      children: [
        if (_truncated)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '처음 ${_maxBytes ~/ 1024}KB만 표시합니다.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: rowCount,
            itemBuilder: (context, index) {
              final start = index * 16;
              final end = (start + 16 > bytes.length) ? bytes.length : start + 16;
              final rowBytes = bytes.sublist(start, end);
              final offset = start.toRadixString(16).padLeft(8, '0');
              final hex = rowBytes
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join(' ')
                  .padRight(47);
              final ascii = String.fromCharCodes(
                rowBytes.map((b) => (b >= 0x20 && b < 0x7f) ? b : 0x2e),
              );
              return Text(
                '$offset  $hex  $ascii',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UnsupportedViewer extends StatelessWidget {
  const _UnsupportedViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('미리보기를 지원하지 않는 파일 형식입니다.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openInDefaultApp(path),
            child: const Text('기본 앱으로 열기'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInDefaultApp(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }
}
