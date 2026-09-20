import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/locale_provider.dart';
import '../theme/theme_mode_provider.dart';
import '../widgets/about_dialog.dart';
import '../widgets/operation_banner.dart';
import '../widgets/tool_icon.dart';
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
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

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
            icon: const ToolIcon('icons8-terminal.svg'),
            tooltip: activeIsRemote ? l10n.openTerminalDisabledTooltip : l10n.openTerminalTooltip,
            onPressed: activeIsRemote ? null : () => openTerminalHere(ref, activeSide),
          ),
          IconButton(
            icon: ToolIcon('icons8-folder-exchange.svg', active: compareMode),
            tooltip: compareMode ? l10n.compareModeOffTooltip : l10n.compareModeOnTooltip,
            onPressed: () =>
                ref.read(compareModeProvider.notifier).state = !compareMode,
          ),
          IconButton(
            icon: ToolIcon(switch (themeMode) {
              ThemeMode.system => 'icons8-automatic-contrast-64.svg',
              ThemeMode.light => 'icons8-sun-64.svg',
              ThemeMode.dark => 'icons8-moon-symbol-64.svg',
            }),
            tooltip: switch (themeMode) {
              ThemeMode.system => l10n.themeSystemTooltip,
              ThemeMode.light => l10n.themeLightTooltip,
              ThemeMode.dark => l10n.themeDarkTooltip,
            },
            onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
          ),
          IconButton(
            icon: const ToolIcon('icons8-language-64.svg'),
            tooltip: l10n.languageTooltip(
              switch (locale?.languageCode) {
                'ko' => l10n.languageKorean,
                'en' => l10n.languageEnglish,
                _ => l10n.languageSystem,
              },
              switch (locale?.languageCode) {
                'ko' => l10n.languageEnglish,
                'en' => l10n.languageSystem,
                _ => l10n.languageKorean,
              },
            ),
            onPressed: () => ref.read(localeProvider.notifier).cycle(),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.aboutMenuTooltip,
            onPressed: () => showAboutInfoDialog(context),
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
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: leftCount > 0 ? () => syncFolders(context, ref, PaneSide.left) : null,
            icon: const ToolIcon('icons8-folder-exchange.svg', size: 16),
            label: Text(l10n.syncDiffToRight(leftCount), overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: rightCount > 0 ? () => syncFolders(context, ref, PaneSide.right) : null,
            icon: const ToolIcon('icons8-folder-exchange.svg', size: 16),
            label: Text(l10n.syncDiffToLeft(rightCount), overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (leftCount > 0 || rightCount > 0)
                ? () => syncFoldersBidirectional(context, ref)
                : null,
            icon: const ToolIcon('icons8-folder-exchange.svg', size: 16),
            label: Text(l10n.bidirectionalSyncButton, overflow: TextOverflow.ellipsis),
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
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Row(
          children: [
            _FnButton(
              label: l10n.fnView,
              icon: Icons.visibility_outlined,
              onPressed: canView ? () => viewSelected(context, ref, activeSide) : null,
            ),
            _FnButton(
              label: l10n.fnNewFolder,
              icon: Icons.create_new_folder_outlined,
              onPressed: () => createFolder(context, ref, activeSide),
            ),
            _FnButton(
              label: l10n.fnRename,
              icon: Icons.drive_file_rename_outline,
              onPressed: selectionCount == 1
                  ? () => renameSelected(context, ref, activeSide)
                  : null,
            ),
            _FnButton(
              label: l10n.fnCopy,
              icon: Icons.content_copy_outlined,
              onPressed: selectionCount > 0
                  ? () => copySelectionToOtherPane(context, ref, activeSide)
                  : null,
            ),
            _FnButton(
              label: l10n.fnMove,
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
              label: l10n.fnDelete,
              icon: Icons.delete_outline,
              onPressed: selectionCount > 0
                  ? () => deleteSelection(context, ref, activeSide)
                  : null,
            ),
            _FnButton(
              label: l10n.compressLabel,
              icon: Icons.folder_zip_outlined,
              onPressed: selectionCount > 0 && allLocal
                  ? () => compressSelection(context, ref, activeSide)
                  : null,
            ),
            _FnButton(
              label: l10n.extractLabel,
              icon: Icons.unarchive_outlined,
              onPressed: canExtract ? () => extractSelection(context, ref, activeSide) : null,
            ),
            _FnButton(
              label: l10n.propertiesTitle,
              icon: Icons.info_outline,
              onPressed:
                  canShowProperties ? () => showProperties(context, ref, activeSide) : null,
            ),
            _FnButton(
              label: l10n.fnPatternSelect,
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
