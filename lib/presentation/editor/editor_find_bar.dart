import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../../l10n/app_localizations.dart';

/// 편집기 위쪽의 찾기/바꾸기 바. re_editor는 찾기 로직만 내장이라 화면은 여기서 만든다.
/// 찾기가 닫혀 있으면(`controller.value == null`) 높이 0으로 접힌다.
class EditorFindBar extends StatelessWidget implements PreferredSizeWidget {
  const EditorFindBar({super.key, required this.controller});

  final CodeFindController controller;

  static const _rowHeight = 40.0;

  @override
  Size get preferredSize {
    final value = controller.value;
    if (value == null) return Size.zero;
    return Size.fromHeight(value.replaceMode ? _rowHeight * 2 : _rowHeight);
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (value == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final result = value.result;
    final total = result?.matches.length ?? 0;
    final String status;
    if (value.option.pattern.isEmpty) {
      status = '';
    } else if (total == 0) {
      status = l10n.editorNoMatches;
    } else {
      status = l10n.editorMatchCount(result!.index + 1, total);
    }

    Widget toggle(String tooltip, String label, bool on, VoidCallback onTap) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: on ? scheme.primary.withValues(alpha: 0.25) : null,
            ),
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
        ),
      );
    }

    Widget field(TextEditingController c, FocusNode node, String hint) {
      return Expanded(
        child: TextField(
          controller: c,
          focusNode: node,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
          ),
          onSubmitted: (_) => controller.nextMatch(),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.editorToggleReplace,
                    icon: Icon(
                      value.replaceMode
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      size: 18,
                    ),
                    onPressed: controller.toggleMode,
                  ),
                  field(
                    controller.findInputController,
                    controller.findInputFocusNode,
                    l10n.editorFindHint,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: Text(
                      status,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  toggle(
                    l10n.editorMatchCase,
                    'Aa',
                    value.option.caseSensitive,
                    controller.toggleCaseSensitive,
                  ),
                  toggle(
                    l10n.editorRegex,
                    '.*',
                    value.option.regex,
                    controller.toggleRegex,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.editorPrevMatch,
                    icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                    onPressed: total == 0 ? null : controller.previousMatch,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.editorNextMatch,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    onPressed: total == 0 ? null : controller.nextMatch,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: AppLocalizations.of(context).close,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: controller.close,
                  ),
                ],
              ),
            ),
          ),
          if (value.replaceMode)
            SizedBox(
              height: _rowHeight,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 44,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                child: Row(
                  children: [
                    field(
                      controller.replaceInputController,
                      controller.replaceInputFocusNode,
                      l10n.editorReplaceHint,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: total == 0 ? null : controller.replaceMatch,
                      child: Text(l10n.editorReplace),
                    ),
                    TextButton(
                      onPressed: total == 0
                          ? null
                          : controller.replaceAllMatches,
                      child: Text(l10n.editorReplaceAll),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
