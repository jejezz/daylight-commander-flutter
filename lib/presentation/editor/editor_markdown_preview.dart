import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'package:url_launcher/url_launcher.dart';

/// 에디터 오른쪽의 마크다운 미리보기. 글자가 바뀌면 잠깐 기다렸다가 다시 그린다(긴 문서 대비).
class EditorMarkdownPreview extends StatefulWidget {
  const EditorMarkdownPreview({
    super.key,
    required this.controller,
    required this.baseDir,
  });

  final CodeLineEditingController controller;

  /// 상대 경로 이미지를 찾을 폴더(편집 중인 파일이 있는 곳).
  final String baseDir;

  @override
  State<EditorMarkdownPreview> createState() => _EditorMarkdownPreviewState();
}

class _EditorMarkdownPreviewState extends State<EditorMarkdownPreview> {
  Timer? _debounce;
  late String _text;
  late CodeLines _lastLines;

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    _lastLines = widget.controller.codeLines;
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  // 커서만 움직이면 codeLines가 그대로이므로 다시 그리지 않는다.
  void _onChanged() {
    if (identical(widget.controller.codeLines, _lastLines)) return;
    _lastLines = widget.controller.codeLines;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _text = widget.controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: _text,
      selectable: true,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        tableBorder: TableBorder.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
      ),
      onTapLink: (text, href, title) {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null && uri.hasScheme) launchUrl(uri);
      },
      imageBuilder: (uri, title, alt) {
        if (uri.hasScheme && uri.scheme != 'file') {
          return Image.network(
            uri.toString(),
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          );
        }
        final path = uri.scheme == 'file'
            ? uri.toFilePath()
            : p.join(widget.baseDir, Uri.decodeComponent(uri.path));
        return Image.file(
          File(path),
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
