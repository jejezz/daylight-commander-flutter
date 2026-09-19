import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../widgets/operation_banner.dart';
import 'folder_comparison_provider.dart';
import 'pane_actions.dart';
import 'pane_controller.dart';
import 'pane_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  KeyEventResult _handleQuickSearchKey(WidgetRef ref, PaneSide activeSide, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final controller = ref.read(paneControllerProvider(activeSide).notifier);

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      controller.backspaceQuickFilter();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      controller.clearQuickFilter();
      return KeyEventResult.handled;
    }

    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed || keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final char = event.character;
    if (char != null && char.trim().isNotEmpty) {
      controller.appendQuickFilterChar(char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSide = ref.watch(activePaneProvider);
    final compareMode = ref.watch(compareModeProvider);
    final activeIsRemote = isRemotePath(ref.watch(paneControllerProvider(activeSide)).currentPath);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.view_column_outlined,
              size: 18,
              color: isDark ? AppColors.primary : AppColors.primaryDeep,
            ),
            const SizedBox(width: 8),
            const Text('Daylight Commander'),
          ],
        ),
        toolbarHeight: 44,
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal),
            tooltip: activeIsRemote ? '터미널 열기 (네트워크 위치에서는 사용 불가)' : '터미널 열기 (활성 패널 경로)',
            onPressed: activeIsRemote ? null : () => openTerminalHere(ref, activeSide),
          ),
          IconButton(
            icon: Icon(
              Icons.compare_arrows,
              color: compareMode ? (isDark ? AppColors.primary : AppColors.primaryDeep) : null,
            ),
            tooltip: compareMode ? '폴더 비교 끄기' : '폴더 비교 (좌우 패널)',
            onPressed: () =>
                ref.read(compareModeProvider.notifier).state = !compareMode,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f3): () =>
              viewSelected(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f5): () =>
              copySelectionToOtherPane(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f6): () =>
              moveSelectionToOtherPane(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f7): () =>
              createFolder(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f8): () =>
              deleteSelection(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.delete): () =>
              deleteSelection(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f2): () =>
              renameSelected(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
              ref.read(paneControllerProvider(activeSide).notifier).selectAll(),
          const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
              ref.read(paneControllerProvider(activeSide).notifier).selectAll(),
          const SingleActivator(LogicalKeyboardKey.tab): () =>
              ref.read(activePaneProvider.notifier).state = otherSide(activeSide),
          const SingleActivator(LogicalKeyboardKey.backquote, control: true): () =>
              openTerminalHere(ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.backquote, meta: true): () =>
              openTerminalHere(ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              ref.read(paneControllerProvider(activeSide).notifier).moveCursor(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              ref.read(paneControllerProvider(activeSide).notifier).moveCursor(-1),
          const SingleActivator(LogicalKeyboardKey.space): () =>
              ref.read(paneControllerProvider(activeSide).notifier).toggleCursorSelection(),
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) => _handleQuickSearchKey(ref, activeSide, event),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: const [
                      Expanded(child: PaneView(side: PaneSide.left)),
                      SizedBox(width: 10),
                      Expanded(child: PaneView(side: PaneSide.right)),
                    ],
                  ),
                ),
                if (compareMode) ...[
                  const SizedBox(height: 8),
                  const _SyncBar(),
                ],
                const OperationBanner(),
                const SizedBox(height: 8),
                _FunctionBar(activeSide: activeSide),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncBar extends ConsumerWidget {
  const _SyncBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparison = ref.watch(folderComparisonProvider);
    final leftCount = comparison?.left.length ?? 0;
    final rightCount = comparison?.right.length ?? 0;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: leftCount > 0 ? () => syncFolders(context, ref, PaneSide.left) : null,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text('차이 $leftCount개 → 복사', overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: rightCount > 0 ? () => syncFolders(context, ref, PaneSide.right) : null,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text('← 차이 $rightCount개 복사', overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class _FunctionBar extends ConsumerWidget {
  const _FunctionBar({required this.activeSide});

  final PaneSide activeSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pane = ref.watch(paneControllerProvider(activeSide));
    final selectionCount = pane.selection.length;
    final selected = pane.selectedEntries;
    final canView = selected.length == 1 && !selected.first.isDirectory;
    final allLocal = selected.every((e) => e.location.scheme == 'file');
    final canExtract = selected.length == 1 &&
        allLocal &&
        !selected.first.isDirectory &&
        selected.first.name.toLowerCase().endsWith('.zip');
    final canShowProperties = selected.length == 1 && selected.first.location.scheme == 'file';

    return Column(
      children: [
        Row(
          children: [
            _FnButton(
              label: 'F3 보기',
              icon: Icons.visibility_outlined,
              onPressed: canView ? () => viewSelected(context, ref, activeSide) : null,
            ),
            _FnButton(
              label: 'F7 새 폴더',
              icon: Icons.create_new_folder_outlined,
              onPressed: () => createFolder(context, ref, activeSide),
            ),
            _FnButton(
              label: 'F2 이름변경',
              icon: Icons.drive_file_rename_outline,
              onPressed: selectionCount == 1
                  ? () => renameSelected(context, ref, activeSide)
                  : null,
            ),
            _FnButton(
              label: 'F5 복사',
              icon: Icons.content_copy_outlined,
              onPressed: selectionCount > 0
                  ? () => copySelectionToOtherPane(context, ref, activeSide)
                  : null,
            ),
            _FnButton(
              label: 'F6 이동',
              icon: Icons.drive_file_move_outline,
              onPressed: selectionCount > 0
                  ? () => moveSelectionToOtherPane(context, ref, activeSide)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _FnButton(
              label: 'F8 삭제',
              icon: Icons.delete_outline,
              onPressed: selectionCount > 0
                  ? () => deleteSelection(context, ref, activeSide)
                  : null,
            ),
            _FnButton(
              label: '압축',
              icon: Icons.folder_zip_outlined,
              onPressed: selectionCount > 0 && allLocal
                  ? () => compressSelection(context, ref, activeSide)
                  : null,
            ),
            _FnButton(
              label: '압축풀기',
              icon: Icons.unarchive_outlined,
              onPressed: canExtract ? () => extractSelection(context, ref, activeSide) : null,
            ),
            _FnButton(
              label: '속성',
              icon: Icons.info_outline,
              onPressed:
                  canShowProperties ? () => showProperties(context, ref, activeSide) : null,
            ),
            _FnButton(
              label: '패턴선택',
              icon: Icons.filter_alt_outlined,
              onPressed: () => selectByPattern(context, ref, activeSide),
            ),
          ],
        ),
      ],
    );
  }
}

class _FnButton extends StatelessWidget {
  const _FnButton({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
