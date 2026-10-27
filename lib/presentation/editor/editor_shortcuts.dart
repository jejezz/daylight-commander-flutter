import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// 단축키 표기. macOS는 ⌘⌥⇧, 그 밖에는 Ctrl+Alt+Shift+ 로 적는다.
/// [primary]는 macOS의 ⌘ / 그 밖의 Ctrl이다.
String editorKeys(
  String key, {
  bool primary = false,
  bool shift = false,
  bool alt = false,
}) {
  if (_isMac) {
    return '${alt ? '⌥' : ''}${shift ? '⇧' : ''}${primary ? '⌘' : ''}$key';
  }
  return [
    if (primary) 'Ctrl',
    if (alt) 'Alt',
    if (shift) 'Shift',
    key,
  ].join('+');
}

/// 툴바 툴팁용: `찾기 (⌘F)`.
String editorTooltip(String label, String keys) => '$label ($keys)';

class EditorShortcut {
  const EditorShortcut(this.description, this.keys);

  final String description;
  final String keys;
}

class EditorShortcutGroup {
  const EditorShortcutGroup(this.title, this.entries);

  final String title;
  final List<EditorShortcut> entries;
}

/// 에디터가 지원하는 단축키 전체. re_editor 기본 키 + 이 화면이 더한 키.
List<EditorShortcutGroup> editorShortcutGroups(
  AppLocalizations l10n, {
  required bool markdown,
}) {
  String k(String key, {bool p = false, bool s = false, bool a = false}) =>
      editorKeys(key, primary: p, shift: s, alt: a);
  final mac = _isMac;
  return [
    EditorShortcutGroup(l10n.editorGroupFile, [
      EditorShortcut(l10n.editorSave, k('S', p: true)),
      EditorShortcut(l10n.editorSaveAs, k('S', p: true, s: true)),
      EditorShortcut(l10n.editorScClose, 'Esc'),
      EditorShortcut(l10n.editorScBlockSelect, mac ? '⌥ + drag' : 'Alt + drag'),
      EditorShortcut(l10n.editorScFold, '▾'),
      if (markdown)
        EditorShortcut(l10n.editorPreview, k('V', p: true, s: true)),
    ]),
    EditorShortcutGroup(l10n.editorGroupEdit, [
      EditorShortcut(l10n.editorUndo, k('Z', p: true)),
      EditorShortcut(l10n.editorRedo, k('Z', p: true, s: true)),
      EditorShortcut(
        l10n.editorScCutCopyPaste,
        '${k('X', p: true)} / ${k('C', p: true)} / ${k('V', p: true)}',
      ),
      EditorShortcut(l10n.editorScSelectAll, k('A', p: true)),
      EditorShortcut(l10n.editorScSelectLine, k('L', p: true)),
      EditorShortcut(l10n.editorScDeleteLine, k('D', p: true)),
      EditorShortcut(l10n.editorScDeleteWord, mac ? '⌥⌫' : 'Ctrl+Backspace'),
    ]),
    EditorShortcutGroup(l10n.editorGroupMove, [
      EditorShortcut(
        l10n.editorScMoveLine,
        '${k('↑', a: true)} / ${k('↓', a: true)}',
      ),
      EditorShortcut(l10n.editorScIndent, mac ? '⇥ / ⇧⇥' : 'Tab / Shift+Tab'),
      EditorShortcut(l10n.editorScComment, k('/', p: true)),
      EditorShortcut(l10n.editorScBlockComment, k('/', p: true, s: true)),
      EditorShortcut(l10n.editorScLineStartEnd, 'Home / End'),
      EditorShortcut(
        l10n.editorScDocStartEnd,
        mac ? '⌘↑ / ⌘↓' : 'Ctrl+Home / Ctrl+End',
      ),
      EditorShortcut(
        l10n.editorScWordMove,
        '${k('←', a: true)} / ${k('→', a: true)}',
      ),
      EditorShortcut(l10n.editorScExtendSelection, 'Shift'),
    ]),
    EditorShortcutGroup(l10n.editorGroupFind, [
      EditorShortcut(l10n.editorFind, k('F', p: true)),
      EditorShortcut(l10n.editorReplace, k('F', p: true, a: true)),
      EditorShortcut(l10n.editorGoToLine, k('G', p: true)),
      EditorShortcut(l10n.editorMatchCase, k('C', p: true, a: true)),
      EditorShortcut(l10n.editorRegex, k('R', p: true, a: true)),
      EditorShortcut(l10n.editorScNextMatch, 'Enter'),
    ]),
  ];
}

/// 툴바 아래에 고정되는 단축키 안내. 오른쪽 위 X로 닫는다.
class EditorShortcutsPanel extends StatelessWidget {
  const EditorShortcutsPanel({
    super.key,
    required this.markdown,
    required this.onClose,
  });

  final bool markdown;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final groups = editorShortcutGroups(l10n, markdown: markdown);
    return Material(
      color: scheme.surfaceContainerLow,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 250),
        child: Stack(
          children: [
            Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 44, 10),
                // 폭을 가득 채워야 패널이 내용 폭으로 쪼그라들지 않는다.
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [for (final g in groups) _Group(group: g)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 4,
              child: IconButton(
                key: const ValueKey('editor-shortcuts-close'),
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n.close,
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group});

  final EditorShortcutGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 258),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            group.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          for (final e in group.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      e.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 키 칩은 줄이지 않고(너무 길 때만 말줄임) 설명이 남는 폭에서 줄바꿈한다.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        e.keys,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.mono.copyWith(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
