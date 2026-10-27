import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/editor/text_file.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'editor_find_bar.dart';
import 'editor_languages.dart';
import 'editor_markdown_preview.dart';
import 'editor_shortcuts.dart';

/// 구문 강조가 꺼지는 크기(re_editor 기본값 4MB와 같다). 상태 바에 알린다.
const _highlightLimitBytes = 4 * 1024 * 1024;

/// 내장 텍스트 에디터 (F4). 이미 읽어 둔 [file]을 받아 편집하고 [path]에 저장한다.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.path,
    required this.name,
    required this.file,
    this.autofocus = true,
  });

  final String path;
  final String name;
  final EditorTextFile file;

  /// 테스트에서만 끈다 — 포커스를 받으면 re_editor의 커서 깜박임 타이머가 돌기 시작한다.
  final bool autofocus;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final CodeLineEditingController _controller;
  late final CodeFindController _findController;
  final _editorFocus = FocusNode();
  final _sinceFindClosed = Stopwatch();
  late EditorTextFile _opened;
  late CodeLines _savedLines;
  late String _path;
  late String _name;
  late String _language;
  bool _dirty = false;
  bool _wordWrap = true;
  bool _saving = false;
  bool _showHelp = true;
  bool _canUndo = false;
  bool _canRedo = false;
  late bool _preview;

  @override
  void initState() {
    super.initState();
    _opened = widget.file;
    _path = widget.path;
    _name = widget.name;
    _language = editorLanguageFor(_name);
    _preview = isMarkdownLanguage(_language);
    _controller = CodeLineEditingController.fromText(
      widget.file.text,
      CodeLineOptions(
        lineBreak: widget.file.lineBreak == '\r\n'
            ? TextLineBreak.crlf
            : TextLineBreak.lf,
      ),
    );
    _savedLines = _controller.codeLines;
    _controller.addListener(_onChanged);
    _findController = CodeFindController(_controller);
    _findController.addListener(_onFindChanged);
    _loadHelpState();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _findController.removeListener(_onFindChanged);
    _editorFocus.dispose();
    _findController.dispose();
    _controller.dispose();
    super.dispose();
  }

  static const _helpKey = 'editor_shortcuts_visible';

  // 단축키 안내를 열어 뒀는지 기억한다. 처음에는 열려 있어 기능이 눈에 띄게 한다.
  Future<void> _loadHelpState() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getBool(_helpKey);
      if (saved != null && mounted) setState(() => _showHelp = saved);
    } catch (_) {}
  }

  Future<void> _setHelp(bool visible) async {
    setState(() => _showHelp = visible);
    try {
      await (await SharedPreferences.getInstance()).setBool(_helpKey, visible);
    } catch (_) {}
  }

  void _togglePreview() {
    setState(() => _preview = !_preview);
    _editorFocus.requestFocus();
  }

  // 글자가 바뀌면 codeLines 객체가 새로 만들어진다(커서만 움직이면 그대로).
  // 저장 뒤 되돌려 원래 내용이 돼도 수정됨으로 남는다 — 매번 본문을 비교하지 않으려는 선택.
  void _onChanged() {
    final changed = !identical(_controller.codeLines, _savedLines);
    final canUndo = _controller.canUndo;
    final canRedo = _controller.canRedo;
    if (changed == _dirty && canUndo == _canUndo && canRedo == _canRedo) return;
    void apply() {
      if (!mounted) return;
      setState(() {
        _dirty = changed;
        _canUndo = canUndo;
        _canRedo = canRedo;
      });
    }

    // 편집기가 그리는 도중에 컨트롤러를 알리면 바로 setState할 수 없다.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  // 찾기 바를 닫으면 포커스가 갈 곳을 잃으므로 편집기로 되돌려 바로 타이핑할 수 있게 한다.
  void _onFindChanged() {
    if (_findController.value != null) return;
    _sinceFindClosed
      ..reset()
      ..start();
    if (!_editorFocus.hasFocus) _editorFocus.requestFocus();
  }

  // Esc: 찾기가 열려 있으면 찾기만 닫는다. re_editor가 같은 Esc로 찾기를 먼저 닫고 키를
  // 위로 흘려보내는 경우도 있어, 찾기를 막 닫은 직후의 Esc는 무시한다.
  void _onEscape() {
    if (_findController.value != null) {
      _findController.close();
      return;
    }
    if (_sinceFindClosed.isRunning &&
        _sinceFindClosed.elapsedMilliseconds < 300) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<bool> _save() => _commit(_path);

  /// 다른 이름으로 저장. 저장한 뒤에는 새 파일을 계속 편집한다.
  Future<bool> _saveAs() async {
    final l10n = AppLocalizations.of(context);
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => _TextPromptDialog(
        title: l10n.editorSaveAs,
        hint: l10n.editorSaveAsHint,
        initialText: _path,
        selectFrom: _path.length - p.basename(_path).length,
        confirmLabel: l10n.editorSave,
        width: 520,
      ),
    );
    final text = entered?.trim() ?? '';
    if (text.isEmpty || !mounted) return false;
    final target = p.normalize(
      p.isAbsolute(text) ? text : p.join(p.dirname(_path), text),
    );
    if (target == _path) return _save();
    if (await FileSystemEntity.type(target) != FileSystemEntityType.notFound) {
      if (!mounted) return false;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.editorSaveAs),
          content: Text(l10n.editorOverwriteExistingBody(p.basename(target))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.editorOverwrite),
            ),
          ],
        ),
      );
      if (overwrite != true) return false;
    }
    return _commit(target, checkDisk: false);
  }

  /// [target]에 쓴다. 열어 둔 파일에 저장할 때는 [checkDisk]로 그사이 바뀌었는지 확인한다.
  Future<bool> _commit(String target, {bool checkDisk = true}) async {
    if (_saving) return false;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _saving = true;
    try {
      if (checkDisk && await changedOnDisk(target, _opened)) {
        if (!mounted) return false;
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.editorExternalChangedTitle),
            content: Text(l10n.editorExternalChangedBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.editorOverwrite),
              ),
            ],
          ),
        );
        if (overwrite != true) return false;
      }
      final lines = _controller.codeLines;
      _opened = await saveEditorText(target, _controller.text, opened: _opened);
      _savedLines = lines;
      if (mounted) {
        setState(() {
          if (target != _path) {
            _path = target;
            _name = p.basename(target);
            _language = editorLanguageFor(_name);
          }
          _dirty = !identical(_controller.codeLines, _savedLines);
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.editorSavedMessage),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.editorSaveFailed('$e'))),
      );
      return false;
    } finally {
      _saving = false;
    }
  }

  /// 닫기 전에 저장 여부를 묻는다. 닫아도 되면 true.
  Future<bool> _confirmClose() async {
    if (!_dirty) return true;
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editorUnsavedTitle),
        content: Text(l10n.editorUnsavedBody(_name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(l10n.editorDontSave),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(l10n.editorSave),
          ),
        ],
      ),
    );
    if (choice == 'discard') return true;
    if (choice == 'save') return _save();
    return false;
  }

  Future<void> _goToLine() async {
    final l10n = AppLocalizations.of(context);
    final max = _controller.lineCount;
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _TextPromptDialog(
        title: l10n.editorGoToLine,
        hint: l10n.editorGoToLineHint(max),
        confirmLabel: l10n.confirm,
        digitsOnly: true,
      ),
    );
    final line = int.tryParse(text ?? '');
    if (line == null) return;
    final index = (line.clamp(1, max)) - 1;
    _controller.selection = CodeLineSelection.collapsed(
      index: index,
      offset: 0,
    );
    _controller.makeCursorCenterIfInvisible();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hlTheme = dark ? githubDarkTheme : githubTheme;
    final root = hlTheme['root'];
    final highlight = _opened.length <= _highlightLimitBytes;
    final markdown = isMarkdownLanguage(_language);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          // re_editor는 포커스를 가진 채 사라지면 커서 깜박임 타이머를 끄지 못한다.
          // 화면이 아직 살아 있는 지금 포커스를 풀어 타이머를 멈춘다.
          _editorFocus.unfocus();
          return;
        }
        final nav = Navigator.of(context);
        if (await _confirmClose() && mounted) nav.pop();
      },
      child: CallbackShortcuts(
        bindings: {
          if (!_opened.binary) ...{
            const SingleActivator(
              LogicalKeyboardKey.keyS,
              control: true,
              shift: true,
            ): _saveAs,
            const SingleActivator(
              LogicalKeyboardKey.keyS,
              meta: true,
              shift: true,
            ): _saveAs,
          },
          if (markdown) ...{
            const SingleActivator(
              LogicalKeyboardKey.keyV,
              control: true,
              shift: true,
            ): _togglePreview,
            const SingleActivator(
              LogicalKeyboardKey.keyV,
              meta: true,
              shift: true,
            ): _togglePreview,
          },
          const SingleActivator(LogicalKeyboardKey.keyG, control: true):
              _goToLine,
          const SingleActivator(LogicalKeyboardKey.keyG, meta: true): _goToLine,
          // 찾기 바가 열려 있으면 편집기가 먼저 Esc를 받아 닫는다. 여기까지 온 Esc는 닫기 요청.
          const SingleActivator(LogicalKeyboardKey.escape): _onEscape,
        },
        child: Scaffold(
          appBar: AppBar(title: Text(_dirty ? '$_name ●' : _name)),
          body: Column(
            children: [
              // 툴바 · 단축키 안내 · (읽기 전용 배너)는 편집 영역과 색과 구분선으로 떨어뜨린다.
              _toolbar(context, markdown: markdown),
              const Divider(height: 1, thickness: 1),
              if (_showHelp) ...[
                EditorShortcutsPanel(
                  markdown: markdown,
                  onClose: () => _setHelp(false),
                ),
                const Divider(height: 1, thickness: 1),
              ],
              if (_opened.binary)
                Material(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      l10n.editorReadOnlyBinary,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              Expanded(
                // 편집기는 항상 같은 자리(첫 자식)에 둔다 — 위치가 바뀌면 다시 마운트되며 오류가 난다.
                child: Row(
                  children: [
                    Expanded(child: _codeEditor(hlTheme, root, highlight)),
                    if (markdown && _preview) ...[
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        child: EditorMarkdownPreview(
                          controller: _controller,
                          baseDir: p.dirname(_path),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              _StatusBar(
                controller: _controller,
                language: _language,
                lineBreak: _opened.lineBreak == '\r\n'
                    ? l10n.editorLineBreakCrlf
                    : l10n.editorLineBreakLf,
                bom: _opened.hasBom,
                binary: _opened.binary,
                highlightOff: !highlight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context, {required bool markdown}) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final readOnly = _opened.binary;

    Widget tool(
      IconData icon,
      String tooltip,
      VoidCallback? onPressed, {
      bool active = false,
    }) {
      return IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        isSelected: active,
        style: active
            ? IconButton.styleFrom(
                backgroundColor: scheme.primary.withValues(alpha: 0.22),
              )
            : null,
        onPressed: onPressed,
      );
    }

    Widget gap() => const SizedBox(
      height: 22,
      child: VerticalDivider(width: 14, thickness: 1),
    );
    String keys(String key, {bool shift = false, bool alt = false}) =>
        editorKeys(key, primary: true, shift: shift, alt: alt);

    return Material(
      color: scheme.surfaceContainerHigh,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            const SizedBox(width: 8),
            tool(
              Icons.undo,
              editorTooltip(l10n.editorUndo, keys('Z')),
              !readOnly && _canUndo ? _controller.undo : null,
            ),
            tool(
              Icons.redo,
              editorTooltip(l10n.editorRedo, keys('Z', shift: true)),
              !readOnly && _canRedo ? _controller.redo : null,
            ),
            gap(),
            tool(
              Icons.search,
              editorTooltip(l10n.editorFind, keys('F')),
              _findController.findMode,
            ),
            tool(
              Icons.find_replace,
              editorTooltip(l10n.editorReplace, keys('F', alt: true)),
              readOnly ? null : _findController.replaceMode,
            ),
            tool(
              Icons.format_list_numbered,
              editorTooltip(l10n.editorGoToLine, keys('G')),
              _goToLine,
            ),
            gap(),
            tool(
              _wordWrap ? Icons.wrap_text : Icons.notes,
              l10n.editorWordWrap,
              () {
                setState(() => _wordWrap = !_wordWrap);
                _editorFocus.requestFocus();
              },
              active: _wordWrap,
            ),
            if (markdown)
              tool(
                Icons.chrome_reader_mode_outlined,
                editorTooltip(l10n.editorPreview, keys('V', shift: true)),
                _togglePreview,
                active: _preview,
              ),
            const Spacer(),
            tool(
              Icons.save_as_outlined,
              editorTooltip(l10n.editorSaveAs, keys('S', shift: true)),
              readOnly ? null : _saveAs,
            ),
            tool(
              Icons.save_outlined,
              editorTooltip(l10n.editorSave, keys('S')),
              _dirty
                  ? () async {
                      await _save();
                      if (mounted) _editorFocus.requestFocus();
                    }
                  : null,
            ),
            gap(),
            tool(
              Icons.help_outline,
              l10n.editorShortcuts,
              () => _setHelp(!_showHelp),
              active: _showHelp,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _codeEditor(
    Map<String, TextStyle> hlTheme,
    TextStyle? root,
    bool highlight,
  ) {
    final mono = AppFonts.mono;
    return CodeEditor(
      controller: _controller,
      findController: _findController,
      wordWrap: _wordWrap,
      autofocus: widget.autofocus,
      readOnly: _opened.binary,
      focusNode: _editorFocus,
      commentFormatter: editorCommentFormatterFor(_language),
      style: CodeEditorStyle(
        fontSize: 13,
        fontFamily: mono.fontFamily,
        fontFamilyFallback: [...?mono.fontFamilyFallback, ...AppFonts.fallback],
        fontFeatures: const [
          FontFeature.disable('liga'),
          FontFeature.disable('calt'),
        ],
        textColor: root?.color,
        backgroundColor: root?.backgroundColor,
        codeTheme: highlight
            ? CodeHighlightTheme(
                languages: {_language: editorModeFor(_language).themeMode},
                theme: hlTheme,
              )
            : null,
      ),
      indicatorBuilder: (context, editing, chunk, notifier) => Row(
        children: [
          DefaultCodeLineNumber(controller: editing, notifier: notifier),
          DefaultCodeChunkIndicator(
            width: 20,
            controller: chunk,
            notifier: notifier,
          ),
        ],
      ),
      findBuilder: (context, controller, readOnly) =>
          EditorFindBar(controller: controller),
      shortcutOverrideActions: {
        CodeShortcutSaveIntent: CallbackAction<CodeShortcutSaveIntent>(
          onInvoke: (_) {
            if (_dirty) _save();
            return null;
          },
        ),
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.controller,
    required this.language,
    required this.lineBreak,
    required this.bom,
    required this.binary,
    required this.highlightOff,
  });

  final CodeLineEditingController controller;
  final String language;
  final String lineBreak;
  final bool bom;
  final bool binary;
  final bool highlightOff;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: ValueListenableBuilder<CodeLineEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final sel = value.selection;
            final parts = [
              l10n.editorStatusPosition(
                sel.extentIndex + 1,
                sel.extentOffset + 1,
              ),
              language,
              binary ? 'Latin-1' : (bom ? 'UTF-8 BOM' : 'UTF-8'),
              lineBreak,
              if (highlightOff) l10n.editorHighlightOff,
            ];
            return Text(
              parts.join('  ·  '),
              style: const TextStyle(fontSize: 12),
            );
          },
        ),
      ),
    );
  }
}

/// 한 줄 입력 대화상자. 컨트롤러를 이 대화상자가 갖고 있어야 닫히는 애니메이션이 끝난 뒤에
/// 정리된다 — 대화상자를 연 쪽에서 바로 dispose하면 아직 그려지는 입력창이 오류를 낸다.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    this.initialText = '',
    this.selectFrom,
    this.digitsOnly = false,
    this.width,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String initialText;

  /// 이 위치부터 끝까지 미리 선택해 둔다(다른 이름으로 저장에서 파일명 부분).
  final int? selectFrom;
  final bool digitsOnly;
  final double? width;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    final from = widget.selectFrom;
    if (from != null) {
      _controller.selection = TextSelection(
        baseOffset: from,
        extentOffset: widget.initialText.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: widget.width,
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: widget.digitsOnly ? TextInputType.number : null,
          inputFormatters: widget.digitsOnly
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(hintText: widget.hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
