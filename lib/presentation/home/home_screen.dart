import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../about/daylight_about.dart';
import '../../l10n/app_localizations.dart';
import '../../window/window_dock.dart';
import '../../settings/settings_menus.dart';
import '../widgets/font_scale_menu.dart';
import '../theme/app_theme.dart';
import '../widgets/operation_banner.dart';
import '../widgets/tool_icon.dart';
import '../../domain/entities/drive_entry.dart';
import 'directory_tree.dart';
import 'drag_payload.dart';
import 'drive_utils.dart';
import 'drives_provider.dart';
import 'folder_comparison_provider.dart';
import 'pane_actions.dart';
import 'pane_controller.dart';
import 'pane_view_mode_provider.dart';
import 'pane_layout_provider.dart';
import 'pane_view.dart';
import 'tree_dock_provider.dart';
import '../../window/focus_tint.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  KeyEventResult _handleQuickSearchKey(
    BuildContext context,
    WidgetRef ref,
    PaneSide activeSide,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // A TextField (e.g. the path bar) has focus: let it handle typing itself.
    // Otherwise this handler would swallow the key event before the platform
    // can deliver the typed character to the text field.
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null &&
        primaryFocus.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }

    final controller = ref.read(paneControllerProvider(activeSide).notifier);

    final keys = HardwareKeyboard.instance;

    // Delete / Backspace(macOS의 delete 키)는 삭제, Shift를 함께 누르면 영구
    // 삭제를 기본으로 한 확인 다이얼로그를 띄운다. 퀵서치 입력 중이면
    // Backspace는 필터 글자를 지우는 데 쓴다. 이 핸들러가 CallbackShortcuts보다
    // 먼저 키를 받고, Delete는 event.character가 비어 있지 않아 퀵서치로
    // 새어 들어가므로 여기서 처리해야 한다.
    final isDelete = event.logicalKey == LogicalKeyboardKey.delete;
    final isBackspace = event.logicalKey == LogicalKeyboardKey.backspace;
    if (isDelete || isBackspace) {
      if (keys.isControlPressed || keys.isMetaPressed || keys.isAltPressed) {
        return KeyEventResult.ignored;
      }
      final shift = keys.isShiftPressed;
      final filtering = ref.read(paneControllerProvider(activeSide)).quickFilter.isNotEmpty;
      if (isBackspace && !shift && filtering) {
        controller.backspaceQuickFilter();
      } else {
        deleteSelection(context, ref, activeSide, preferPermanent: shift);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      controller.clearQuickFilter();
      return KeyEventResult.handled;
    }

    // Ctrl/Cmd+A/C/V live here rather than in CallbackShortcuts: this handler
    // already bails out above when a TextField has focus, so those keys keep
    // their normal select-all/copy/paste meaning inside the path bar.
    final shortcutModifier = (keys.isControlPressed || keys.isMetaPressed) &&
        !keys.isAltPressed &&
        !keys.isShiftPressed;
    if (shortcutModifier) {
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        controller.selectAll();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        copySelectionToOsClipboard(context, ref, activeSide);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        pasteFromOsClipboard(context, ref, activeSide);
        return KeyEventResult.handled;
      }
    }
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
    final layout = ref.watch(paneLayoutProvider);
    final dockEdge = ref.watch(windowDockProvider);
    final treeDockOpen = ref.watch(treeDockProvider.select((s) => s.open));
    final activeIsRemote = isRemotePath(ref.watch(paneControllerProvider(activeSide)).currentPath);
    final l10n = AppLocalizations.of(context);

    // 1패널 모드에서는 창을 자유롭게 줄일 수 있게 최소 크기를 낮추고, 2패널 모드로
    // 돌아가면 창 도킹도 풀어 원래 크기로 되돌린다.
    ref.listen<PaneLayout>(paneLayoutProvider, (previous, next) {
      ref.read(windowDockProvider.notifier).setSinglePane(next.singlePane);
      if (!next.singlePane && ref.read(windowDockProvider) != null) {
        ref.read(windowDockProvider.notifier).undock();
      }
    });
    // 디렉토리 트리를 도킹하면 2패널 모드의 최소 창 폭도 그만큼 늘려서, 트리 열
    // 때문에 패널 경로 바 아이콘이 넘치지 않게 한다.
    ref.listen<TreeDockState>(treeDockProvider, (previous, next) {
      if (previous?.open != next.open) {
        ref.read(windowDockProvider.notifier).setTreeDockOpen(next.open);
      }
    });

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Row(
          children: [
            Icon(
              Icons.view_column_outlined,
              size: 18,
              color: isDark ? AppColors.primary : AppColors.primaryDeep,
            ),
            const SizedBox(width: 8),
            const Flexible(child: Text('Daylight Commander', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            icon: ToolIcon('icons8-folder-tree.svg', active: !treeDockOpen),
            tooltip: l10n.directoryTreeTooltip,
            onPressed: () => ref.read(treeDockProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const ToolIcon('icons8-terminal.svg'),
            tooltip: activeIsRemote ? l10n.openTerminalDisabledTooltip : l10n.openTerminalTooltip,
            onPressed: activeIsRemote ? null : () => openTerminalHere(ref, activeSide),
          ),
          IconButton(
            icon: ToolIcon('icons8-compare.svg', active: compareMode),
            tooltip: compareMode ? l10n.compareModeOffTooltip : l10n.compareModeOnTooltip,
            onPressed: () =>
                ref.read(compareModeProvider.notifier).state = !compareMode,
          ),
          IconButton(
            icon: const ToolIcon('icons8-exchange.svg'),
            tooltip: l10n.swapPanesTooltip,
            onPressed: () => ref.read(paneLayoutProvider.notifier).swap(),
          ),
          IconButton(
            icon: ToolIcon(layout.singlePane ? 'icons8-dual-panel.svg' : 'icons8-single-panel.svg'),
            tooltip: layout.singlePane ? l10n.dualPaneTooltip : l10n.singlePaneTooltip,
            onPressed: () => ref.read(paneLayoutProvider.notifier).toggleSinglePane(),
          ),
          if (layout.singlePane && windowDockSupported)
            PopupMenuButton<DockEdge>(
              icon: ToolIcon('icons8-docking.svg', active: dockEdge != null),
              tooltip: l10n.windowDockTooltip,
              onSelected: (edge) => ref.read(windowDockProvider.notifier).dock(edge),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: DockEdge.left,
                  checked: dockEdge == DockEdge.left,
                  child: Text(l10n.windowDockLeft),
                ),
                CheckedPopupMenuItem(
                  value: DockEdge.right,
                  checked: dockEdge == DockEdge.right,
                  child: Text(l10n.windowDockRight),
                ),
                if (dockEdge != null)
                  PopupMenuItem<DockEdge>(
                    onTap: () => ref.read(windowDockProvider.notifier).undock(),
                    child: Text(l10n.windowUndock),
                  ),
              ],
            ),
          const FontScaleMenuButton(),
          const ThemeMenuButton(),
          const LanguageMenuButton(),
          IconButton(
            icon: const ToolIcon('icons8-about.svg'),
            tooltip: l10n.aboutTooltip,
            onPressed: () => showDaylightAbout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _GlobalShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f3): () =>
              viewSelected(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f4): () =>
              editSelected(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f5): () =>
              copySelectionToOtherPane(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () =>
              duplicateSelection(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.keyD, meta: true): () =>
              duplicateSelection(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f6): () =>
              moveSelectionToOtherPane(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f7): () =>
              createFolder(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.keyT, control: true): () =>
              ref.read(treeDockProvider.notifier).toggle(),
          const SingleActivator(LogicalKeyboardKey.keyT, meta: true): () =>
              ref.read(treeDockProvider.notifier).toggle(),
          const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
              ref.read(paneControllerProvider(activeSide).notifier).refresh(),
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
              ref.read(paneControllerProvider(activeSide).notifier).refresh(),
          const SingleActivator(LogicalKeyboardKey.f8): () =>
              deleteSelection(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.f2): () =>
              renameSelected(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.tab): () =>
              ref.read(activePaneProvider.notifier).state = otherSide(activeSide),
          const SingleActivator(LogicalKeyboardKey.keyU, control: true): () =>
              ref.read(paneLayoutProvider.notifier).swap(),
          const SingleActivator(LogicalKeyboardKey.keyU, meta: true): () =>
              ref.read(paneLayoutProvider.notifier).swap(),
          const SingleActivator(LogicalKeyboardKey.backslash, control: true): () =>
              ref.read(paneLayoutProvider.notifier).toggleSinglePane(),
          const SingleActivator(LogicalKeyboardKey.backslash, meta: true): () =>
              ref.read(paneLayoutProvider.notifier).toggleSinglePane(),
          const SingleActivator(LogicalKeyboardKey.backquote, control: true): () =>
              openTerminalHere(ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.backquote, meta: true): () =>
              openTerminalHere(ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _moveCursor(ref, activeSide, _CursorMove.down),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _moveCursor(ref, activeSide, _CursorMove.up),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _moveCursor(ref, activeSide, _CursorMove.right),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _moveCursor(ref, activeSide, _CursorMove.left),
          const SingleActivator(LogicalKeyboardKey.home): () =>
              _moveCursor(ref, activeSide, _CursorMove.home),
          const SingleActivator(LogicalKeyboardKey.end): () =>
              _moveCursor(ref, activeSide, _CursorMove.end),
          const SingleActivator(LogicalKeyboardKey.pageUp): () =>
              _moveCursor(ref, activeSide, _CursorMove.pageUp),
          const SingleActivator(LogicalKeyboardKey.pageDown): () =>
              _moveCursor(ref, activeSide, _CursorMove.pageDown),
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              _openCursorEntry(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
              _openCursorEntry(context, ref, activeSide),
          const SingleActivator(LogicalKeyboardKey.space): () =>
              ref.read(paneControllerProvider(activeSide).notifier).toggleCursorSelection(),
          const SingleActivator(LogicalKeyboardKey.arrowRight, control: true, shift: true): () =>
              _syncPanePath(ref, from: layout.leftmost, to: otherSide(layout.leftmost)),
          const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true, shift: true): () =>
              _syncPanePath(ref, from: otherSide(layout.leftmost), to: layout.leftmost),
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) => _handleQuickSearchKey(context, ref, activeSide, event),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: _PaneArea(layout: layout, activeSide: activeSide),
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

void _syncPanePath(WidgetRef ref, {required PaneSide from, required PaneSide to}) {
  final path = ref.read(paneControllerProvider(from)).currentPath;
  ref.read(paneControllerProvider(to).notifier).navigateTo(path);
}

/// [CallbackShortcuts]와 같지만, 포커스가 텍스트 입력 칸(주소 입력창 등) 안에 있으면
/// 전역 단축키를 무시한다. 그렇지 않으면 화살표/Enter/F2/Tab 등이 CallbackShortcuts의
/// Focus 노드까지 올라와, 입력칸 안에서 커서를 움직이거나 경로를 입력하는 동작과 충돌한다.
class _GlobalShortcuts extends StatelessWidget {
  const _GlobalShortcuts({required this.bindings, required this.child});

  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final primaryFocus = FocusManager.instance.primaryFocus;
        if (primaryFocus != null &&
            primaryFocus.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
          return KeyEventResult.ignored;
        }
        for (final entry in bindings.entries) {
          if (entry.key.accepts(event, HardwareKeyboard.instance)) {
            entry.value();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// 패널 영역. 2패널 모드는 [PaneLayout.leftmost] 순서로 나란히 놓고, 1패널
/// 모드는 활성 패널만 펼치고 나머지는 원래 놓일 가장자리에 [_DockedRail]로 도킹한다.
/// 디렉토리 트리가 열려 있으면 활성 패널을 따라가는 트리 열을 왼쪽에 덧붙인다.
class _PaneArea extends ConsumerWidget {
  const _PaneArea({required this.layout, required this.activeSide});

  final PaneLayout layout;
  final PaneSide activeSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = layout.leftmost;
    final second = otherSide(first);
    final Widget panes;
    if (!layout.singlePane) {
      panes = Row(
        children: [
          Expanded(child: PaneView(key: ValueKey(first), side: first)),
          _PaneSyncGap(leftSide: first, rightSide: second),
          Expanded(child: PaneView(key: ValueKey(second), side: second)),
        ],
      );
    } else {
      final docked = otherSide(activeSide);
      final dockedFirst = docked == first;
      final rail = _DockedRail(side: docked);
      panes = Row(
        children: [
          if (dockedFirst) ...[rail, const SizedBox(width: 10)],
          Expanded(child: PaneView(key: ValueKey(activeSide), side: activeSide)),
          if (!dockedFirst) ...[const SizedBox(width: 10), rail],
        ],
      );
    }

    final treeDock = ref.watch(treeDockProvider);
    if (!treeDock.open) return panes;

    const handleWidth = 10.0;
    // 패널이 자기 경로 바 아이콘을 다 그릴 수 있는 최소 폭. 트리가 이보다 더
    // 넓어지려 하면, 패널 아이콘이 넘치는 대신 트리 폭을 줄이거나 트리를 숨긴다.
    const minPaneContentWidth = 400.0;
    final minPanesWidth = layout.singlePane
        ? minPaneContentWidth + 46 // 도킹 레일(36) + 간격(10)
        : minPaneContentWidth * 2 + 28; // 패널 두 개 + 동기화 간격

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTreeWidth = constraints.maxWidth - handleWidth - minPanesWidth;
        if (maxTreeWidth < treeDockMinWidth) return panes;
        final width = treeDock.width.clamp(treeDockMinWidth, maxTreeWidth);
        return Row(
          children: [
            SizedBox(
              width: width,
              child: DirectoryTree(key: ValueKey(activeSide), side: activeSide),
            ),
            _TreeDockHandle(currentWidth: width),
            Expanded(child: panes),
          ],
        );
      },
    );
  }
}

/// 디렉토리 트리 열의 폭을 드래그로 조절하는 분할선.
class _TreeDockHandle extends ConsumerWidget {
  const _TreeDockHandle({required this.currentWidth});

  final double currentWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          ref.read(treeDockProvider.notifier).setWidth(currentWidth + details.delta.dx);
        },
        child: SizedBox(
          width: 10,
          child: Center(
            child: Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 24),
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// 두 패널 사이에서 한쪽의 현재 경로를 다른 쪽으로 보내는 동기화 버튼.
/// [leftSide]/[rightSide]는 활성 패널이 아니라 화면에 놓인 위치 기준이라,
/// Ctrl+Shift+화살표 단축키와 화살표 방향이 그대로 맞는다.
class _PaneSyncGap extends ConsumerWidget {
  const _PaneSyncGap({required this.leftSide, required this.rightSide});

  final PaneSide leftSide;
  final PaneSide rightSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const ToolIcon('icons8-right.svg', size: 16),
            tooltip: l10n.syncPathRightTooltip,
            onPressed: () => _syncPanePath(ref, from: leftSide, to: rightSide),
          ),
          const SizedBox(height: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const ToolIcon('icons8-left.svg', size: 16),
            tooltip: l10n.syncPathLeftTooltip,
            onPressed: () => _syncPanePath(ref, from: rightSide, to: leftSide),
          ),
        ],
      ),
    );
  }
}

/// 1패널 모드에서 숨겨진 패널을 가장자리에 접어 둔 좁은 막대. 누르면 그 패널이
/// 펼쳐지고, 파일을 끌어다 놓으면 그 패널의 현재 폴더로 복사/이동한다.
class _DockedRail extends ConsumerWidget {
  const _DockedRail({required this.side});

  final PaneSide side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(paneControllerProvider(side).select((s) => s.currentPath));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primary : AppColors.primaryDeep;
    final l10n = AppLocalizations.of(context);
    final name = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).lastOrNull ?? path;

    return DragTarget<DragPayload>(
      onAcceptWithDetails: (details) {
        final drives = ref.read(drivesProvider).valueOrNull ?? const <DriveEntry>[];
        final payload = details.data;
        final srcPath = locationToPathString(payload.entries.first.location);
        transferEntries(
          context,
          ref,
          fromSide: payload.fromSide,
          entries: payload.entries,
          destinationDir: path,
          isMove: isSameDrive(srcPath, path, drives),
        );
      },
      builder: (context, candidate, rejected) => Tooltip(
        message: l10n.dockedPaneTooltip(path),
        child: Material(
          color: candidate.isNotEmpty
              ? accent.withValues(alpha: 0.18)
              : (isDark ? AppColors.surface : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(AppRadius.tile),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => ref.read(activePaneProvider.notifier).state = side,
            child: Container(
              width: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(
                  color: candidate.isNotEmpty
                      ? accent
                      : (isDark ? AppColors.stroke : AppColors.strokeLight),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Icon(Icons.folder_open, size: 18, color: accent),
                  const SizedBox(height: 8),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ],
              ),
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
          child: Tooltip(
            message: l10n.syncDiffToRight(leftCount),
            child: OutlinedButton.icon(
            onPressed: leftCount > 0 ? () => syncFolders(context, ref, PaneSide.left) : null,
            icon: const ToolIcon('icons8-folder-exchange.svg', size: 16),
            label: Text(l10n.syncDiffToRight(leftCount), overflow: TextOverflow.ellipsis),
          ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Tooltip(
            message: l10n.syncDiffToLeft(rightCount),
            child: OutlinedButton.icon(
            onPressed: rightCount > 0 ? () => syncFolders(context, ref, PaneSide.right) : null,
            icon: const ToolIcon('icons8-folder-exchange.svg', size: 16),
            label: Text(l10n.syncDiffToLeft(rightCount), overflow: TextOverflow.ellipsis),
          ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Tooltip(
            message: l10n.bidirectionalSyncButton,
            child: OutlinedButton.icon(
            onPressed: (leftCount > 0 || rightCount > 0)
                ? () => syncFoldersBidirectional(context, ref)
                : null,
            icon: const ToolIcon('icons8-folder-exchange.svg', size: 16),
            label: Text(l10n.bidirectionalSyncButton, overflow: TextOverflow.ellipsis),
          ),
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
              label: l10n.fnEdit,
              icon: Icons.edit_outlined,
              onPressed: canView ? () => editSelected(context, ref, activeSide) : null,
            ),
            _FnButton(
              label: l10n.fnNewFolder,
              icon: Icons.create_new_folder_outlined,
              onPressed: () => createFolder(context, ref, activeSide),
            ),
            _FnButton(
              label: l10n.newFileButtonLabel,
              icon: Icons.note_add_outlined,
              onPressed: () => createFile(context, ref, activeSide),
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
        // 창이 좁아 글자가 잘려도 버튼의 역할을 알 수 있게 툴팁으로 보인다.
        child: Tooltip(
          message: label,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

enum _CursorMove { up, down, left, right, home, end, pageUp, pageDown }

/// 방향키 등으로 커서를 옮긴다. 자세히 보기는 위/아래 한 줄씩만 쓰고(기존
/// 동작 유지), 썸네일 보기는 좌/우 한 칸, 위/아래 한 행(열 수), PageUp/Down은
/// 한 화면에 보이는 행 수만큼 움직인다.
void _moveCursor(WidgetRef ref, PaneSide side, _CursorMove move) {
  final controller = ref.read(paneControllerProvider(side).notifier);
  final thumbnails = ref.read(paneViewSettingsProvider(side)).isThumbnails;
  final columns = thumbnails ? ref.read(paneGridColumnsProvider(side)) : 1;
  final pageRows = thumbnails ? ref.read(paneGridPageRowsProvider(side)) : 1;
  switch (move) {
    case _CursorMove.down:
      controller.moveCursor(columns);
    case _CursorMove.up:
      controller.moveCursor(-columns);
    case _CursorMove.right:
      if (thumbnails) controller.moveCursor(1);
    case _CursorMove.left:
      if (thumbnails) controller.moveCursor(-1);
    case _CursorMove.home:
      if (thumbnails) controller.moveCursorTo(0);
    case _CursorMove.end:
      if (thumbnails) controller.moveCursorTo(1 << 30);
    case _CursorMove.pageUp:
      if (thumbnails) controller.moveCursor(-columns * pageRows);
    case _CursorMove.pageDown:
      if (thumbnails) controller.moveCursor(columns * pageRows);
  }
}

/// Enter. 커서가 가리키는 항목을 연다(폴더는 들어가고, 파일은 기본 앱으로).
/// 경로 입력창처럼 텍스트 입력 중일 때는 입력창이 Enter를 쓰도록 건드리지 않는다.
void _openCursorEntry(BuildContext context, WidgetRef ref, PaneSide side) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused != null &&
      (focused.widget is EditableText ||
          focused.findAncestorWidgetOfExactType<EditableText>() != null)) {
    return;
  }
  final state = ref.read(paneControllerProvider(side));
  final index = state.cursorIndex;
  if (index == null || index >= state.visibleEntries.length) return;
  final entry = state.visibleEntries[index];
  if (entry.isDirectory) {
    ref.read(paneControllerProvider(side).notifier).openEntry(entry);
  } else {
    openEntryWithDefaultApp(context, ref, entry);
  }
}
