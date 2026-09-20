import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bytes_format.dart';
import '../../core/date_format.dart';
import '../../domain/entities/drive_entry.dart';
import '../../domain/entities/file_entry.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/file_icon.dart';
import '../widgets/tool_icon.dart';
import 'bookmarks_provider.dart';
import 'drag_payload.dart';
import 'drive_utils.dart';
import 'drives_provider.dart';
import 'folder_comparison_provider.dart';
import 'pane_actions.dart';
import 'pane_controller.dart';
import 'recent_folders_provider.dart';

class PaneView extends ConsumerWidget {
  const PaneView({super.key, required this.side});

  final PaneSide side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paneControllerProvider(side));
    final controller = ref.read(paneControllerProvider(side).notifier);
    final isActive = ref.watch(activePaneProvider) == side;
    final drives =
        ref.watch(drivesProvider).valueOrNull ?? const <DriveEntry>[];
    final bookmarks = ref.watch(bookmarksProvider);
    final recentFolders = ref.watch(recentFoldersProvider);
    final comparison = ref.watch(folderComparisonProvider);
    final diffMap = comparison == null
        ? const <Uri, FileDiffStatus>{}
        : (side == PaneSide.left ? comparison.left : comparison.right);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visibleEntries = state.visibleEntries;

    ref.listen<PaneState>(paneControllerProvider(side), (previous, next) {
      if (!next.loading &&
          next.error == null &&
          previous?.currentPath != next.currentPath) {
        ref.read(recentFoldersProvider.notifier).record(next.currentPath);
      }
    });

    Future<void> handleDrop(DragPayload payload, String destinationDir) {
      final srcPath = locationToPathString(payload.entries.first.location);
      final isMove = isSameDrive(srcPath, destinationDir, drives);
      return transferEntries(
        context,
        ref,
        fromSide: payload.fromSide,
        entries: payload.entries,
        destinationDir: destinationDir,
        isMove: isMove,
      );
    }

    return _ExternalDropOverlay(
      onFilesDropped: (paths) => dropExternalFiles(context, ref, side, paths),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: isActive
                ? (isDark ? AppColors.primary : AppColors.primaryDeep)
                : (isDark ? AppColors.stroke : AppColors.strokeLight),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => ref.read(activePaneProvider.notifier).state = side,
            child: Column(
              children: [
                _PathBar(
                  path: state.currentPath,
                  canGoBack: state.backHistory.isNotEmpty,
                  canGoForward: state.forwardHistory.isNotEmpty,
                  showHidden: state.showHidden,
                  drives: drives,
                  bookmarks: bookmarks,
                  recentFolders: recentFolders,
                  isBookmarked: bookmarks.contains(state.currentPath),
                  onUp: controller.goUp,
                  onBack: controller.goBack,
                  onForward: controller.goForward,
                  onRefresh: controller.refresh,
                  onSubmitPath: controller.navigateTo,
                  onSelectDrive: controller.navigateTo,
                  onToggleHidden: controller.toggleShowHidden,
                  onToggleBookmark: () => toggleBookmark(ref, side),
                  onSelectBookmark: controller.navigateTo,
                  onRemoveBookmark: (path) =>
                      ref.read(bookmarksProvider.notifier).remove(path),
                  onConnectSmb: () => connectSmbServer(context, ref),
                  onConnectFtp: () => connectFtpServer(context, ref, side),
                  onConnectSftp: () => connectSftpServer(context, ref, side),
                  onConnectWebdav: () => connectWebdavServer(context, ref, side),
                  onDisconnectRemote: () => disconnectRemote(ref, side),
                  isRemote: isRemotePath(state.currentPath),
                ),
                const Divider(height: 1),
                _ColumnHeader(
                  sortField: state.sortField,
                  ascending: state.sortAscending,
                  onSort: controller.setSortField,
                ),
                const Divider(height: 1),
                Expanded(
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null
                      ? Center(
                          child: Text(
                            state.error!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : DragTarget<DragPayload>(
                          onAcceptWithDetails: (details) =>
                              handleDrop(details.data, state.currentPath),
                          builder: (context, candidateData, rejectedData) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: candidateData.isNotEmpty
                                    ? (isDark
                                          ? AppColors.primary.withValues(
                                              alpha: 0.06,
                                            )
                                          : AppColors.primaryDeep.withValues(
                                              alpha: 0.05,
                                            ))
                                    : null,
                              ),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                itemCount: visibleEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = visibleEntries[index];
                                  final selected = state.selection.contains(
                                    entry.location,
                                  );
                                  final payload =
                                      (selected && state.selection.length > 1)
                                      ? DragPayload(
                                          fromSide: side,
                                          entries: state.selectedEntries,
                                        )
                                      : DragPayload(
                                          fromSide: side,
                                          entries: [entry],
                                        );
                                  return _FileRow(
                                    entry: entry,
                                    selected: selected,
                                    isCursor: index == state.cursorIndex,
                                    dragPayload: payload,
                                    diffStatus: diffMap[entry.location],
                                    onSelect: () {
                                      ref
                                              .read(activePaneProvider.notifier)
                                              .state =
                                          side;
                                      final keys = HardwareKeyboard.instance;
                                      final hasModifier =
                                          keys.isShiftPressed ||
                                          keys.isControlPressed ||
                                          keys.isMetaPressed;
                                      final isDoubleClick = controller
                                          .consumeDoubleClick(entry.location);
                                      if (isDoubleClick && !hasModifier) {
                                        if (entry.isDirectory) {
                                          controller.openEntry(entry);
                                        } else {
                                          openEntryWithDefaultApp(
                                            context,
                                            ref,
                                            entry,
                                          );
                                        }
                                        return;
                                      }
                                      if (keys.isShiftPressed) {
                                        controller.selectRange(index);
                                      } else if (keys.isControlPressed ||
                                          keys.isMetaPressed) {
                                        controller.toggleSelection(index);
                                      } else {
                                        controller.selectOnly(index);
                                      }
                                    },
                                    onSecondaryTap: (globalPosition) =>
                                        showRowContextMenu(
                                          context,
                                          ref,
                                          side: side,
                                          entry: entry,
                                          index: index,
                                          globalPosition: globalPosition,
                                        ),
                                    onFolderDrop: (payload) => handleDrop(
                                      payload,
                                      locationToPathString(entry.location),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                _PaneStatusBar(
                  count: visibleEntries.length,
                  selectedCount: state.selection.length,
                  selectedBytes: state.selectedTotalBytes,
                  quickFilter: state.quickFilter,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PathBar extends StatefulWidget {
  const _PathBar({
    required this.path,
    required this.canGoBack,
    required this.canGoForward,
    required this.showHidden,
    required this.drives,
    required this.bookmarks,
    required this.recentFolders,
    required this.isBookmarked,
    required this.onUp,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onSubmitPath,
    required this.onSelectDrive,
    required this.onToggleHidden,
    required this.onToggleBookmark,
    required this.onSelectBookmark,
    required this.onRemoveBookmark,
    required this.onConnectSmb,
    required this.onConnectFtp,
    required this.onConnectSftp,
    required this.onConnectWebdav,
    required this.onDisconnectRemote,
    required this.isRemote,
  });

  final String path;
  final bool canGoBack;
  final bool canGoForward;
  final bool showHidden;
  final List<DriveEntry> drives;
  final List<String> bookmarks;
  final List<String> recentFolders;
  final bool isBookmarked;
  final VoidCallback onUp;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSubmitPath;
  final ValueChanged<String> onSelectDrive;
  final VoidCallback onToggleHidden;
  final VoidCallback onToggleBookmark;
  final ValueChanged<String> onSelectBookmark;
  final ValueChanged<String> onRemoveBookmark;
  final VoidCallback onConnectSmb;
  final VoidCallback onConnectFtp;
  final VoidCallback onConnectSftp;
  final VoidCallback onConnectWebdav;
  final VoidCallback onDisconnectRemote;
  final bool isRemote;

  @override
  State<_PathBar> createState() => _PathBarState();
}

class _PathBarState extends State<_PathBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.path,
  );
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant _PathBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path && !_focusNode.hasFocus) {
      _controller.text = widget.path;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const ToolIcon('icons8-left.svg', size: 15),
            tooltip: l10n.goBackTooltip,
            onPressed: widget.canGoBack ? widget.onBack : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const ToolIcon('icons8-right.svg', size: 15),
            tooltip: l10n.goForwardTooltip,
            onPressed: widget.canGoForward ? widget.onForward : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const ToolIcon('icons8-up.svg', size: 15),
            tooltip: l10n.goUpTooltip,
            onPressed: widget.onUp,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const ToolIcon('icons8-refresh.svg', size: 15),
            tooltip: l10n.refreshTooltip,
            onPressed: widget.onRefresh,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.switchDriveTooltip,
            icon: const ToolIcon('icons8-hdd-64.svg', size: 15),
            onSelected: widget.onSelectDrive,
            itemBuilder: (context) => [
              for (final drive in widget.drives)
                PopupMenuItem(value: drive.path, child: Text(drive.name)),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: l10n.networkConnectTooltip,
            icon: ToolIcon('icons8-cloud-storage-64.svg', size: 15, active: widget.isRemote),
            onSelected: (value) {
              switch (value) {
                case 'smb':
                  widget.onConnectSmb();
                case 'ftp':
                  widget.onConnectFtp();
                case 'sftp':
                  widget.onConnectSftp();
                case 'webdav':
                  widget.onConnectWebdav();
                case 'disconnect':
                  widget.onDisconnectRemote();
              }
            },
            itemBuilder: (context) => [
              if (widget.isRemote) ...[
                PopupMenuItem(value: 'disconnect', child: Text(l10n.disconnectMenuItem)),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(value: 'smb', child: Text(l10n.smbConnectMenuItem)),
              PopupMenuItem(value: 'ftp', child: Text(l10n.ftpConnectTitle)),
              PopupMenuItem(value: 'sftp', child: Text(l10n.sftpConnectTitle)),
              PopupMenuItem(value: 'webdav', child: Text(l10n.webdavConnectTitle)),
            ],
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: ToolIcon('icons8-heart-64.svg', size: 15, active: widget.isBookmarked),
            tooltip: widget.isBookmarked ? l10n.removeBookmarkTooltip : l10n.addBookmarkTooltip,
            onPressed: widget.onToggleBookmark,
          ),
          if (widget.bookmarks.isNotEmpty || widget.recentFolders.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: l10n.bookmarksAndRecentTooltip,
              icon: const ToolIcon('icons8-favorite-folder-64.svg', size: 15),
              onSelected: widget.onSelectBookmark,
              itemBuilder: (context) => [
                if (widget.bookmarks.isNotEmpty) ...[
                  PopupMenuItem<String>(
                    enabled: false,
                    height: 26,
                    child: Text(
                      l10n.bookmarksSectionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  for (final path in widget.bookmarks)
                    PopupMenuItem(
                      value: path,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(path, overflow: TextOverflow.ellipsis),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onRemoveBookmark(path);
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.close, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (widget.recentFolders.isNotEmpty) ...[
                  if (widget.bookmarks.isNotEmpty) const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    enabled: false,
                    height: 26,
                    child: Text(
                      l10n.recentSectionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  for (final path in widget.recentFolders)
                    PopupMenuItem(
                      value: path,
                      child: Text(path, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ],
            ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 6),
              ),
              onSubmitted: widget.onSubmitPath,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: ToolIcon('icons8-hide-64.svg', size: 15, active: widget.showHidden),
            tooltip: l10n.showHiddenTooltip,
            onPressed: widget.onToggleHidden,
          ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.sortField,
    required this.ascending,
    required this.onSort,
  });

  final SortField sortField;
  final bool ascending;
  final ValueChanged<SortField> onSort;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    Widget label(String text, SortField field) {
      final isActive = sortField == field;
      return InkWell(
        onTap: () => onSort(field),
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // 글자 크기를 키웠을 때 컬럼 고정폭(SizedBox)을 넘으면 잘라내고
              // 말줄임표를 붙인다 — 넘치는 대신 우아하게 줄어들게.
              Flexible(child: Text(text, style: style, overflow: TextOverflow.ellipsis)),
              if (isActive) ...[
                const SizedBox(width: 2),
                ToolIcon('icons8-sorting-arrows-64.svg', size: 14, flipVertical: !ascending),
              ],
            ],
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const SizedBox(width: 30),
          Expanded(child: label(l10n.nameLabel, SortField.name)),
          SizedBox(width: 60, child: label(l10n.sizeLabel, SortField.size)),
          SizedBox(width: 105, child: label(l10n.modifiedLabel, SortField.modified)),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.entry,
    required this.selected,
    required this.isCursor,
    required this.dragPayload,
    required this.diffStatus,
    required this.onSelect,
    required this.onSecondaryTap,
    required this.onFolderDrop,
  });

  final FileEntry entry;
  final bool selected;

  /// 키보드 커서(화살표로 이동한 위치)가 이 행인지. [selected]와 독립적이다 —
  /// 화살표만으로는 다중선택에 들어가지 않고(스페이스가 필요) 커서 표시만 된다.
  final bool isCursor;
  final DragPayload dragPayload;
  final FileDiffStatus? diffStatus;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onSecondaryTap;
  final ValueChanged<DragPayload> onFolderDrop;

  Widget _row(BuildContext context, {bool dragHighlight = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = dragHighlight
        ? (isDark
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.primaryDeep.withValues(alpha: 0.18))
        : selected
        ? (isDark
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.primaryDeep.withValues(alpha: 0.10))
        : switch (diffStatus) {
            FileDiffStatus.onlyHere =>
              (isDark ? AppColors.accent : AppColors.accent).withValues(
                alpha: isDark ? 0.16 : 0.10,
              ),
            FileDiffStatus.differs => AppColors.warning.withValues(
              alpha: isDark ? 0.16 : 0.14,
            ),
            null => Colors.transparent,
          };
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: isCursor
            ? Border.all(
                color: isDark ? AppColors.primary : AppColors.primaryDeep,
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          FileIcon(name: entry.name, isDirectory: entry.isDirectory),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              entry.isDirectory ? '--' : formatBytes(entry.sizeBytes),
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              formatModified(entry.modifiedAt),
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tappable({bool dragHighlight = false}) {
      return InkWell(
        onTap: onSelect,
        onSecondaryTapDown: (details) => onSecondaryTap(details.globalPosition),
        // onDoubleTap을 일부러 안 쓴다 — InkWell에 onTap과 onDoubleTap을 같이
        // 달면 Flutter가 더블탭 여부를 가리려고 ~300ms를 기다린 뒤에야 onTap을
        // 실행해서 선택 자체가 늦게 반응한다. 더블클릭 감지는
        // PaneController.consumeDoubleClick이 타임스탬프로 직접 한다.
        //
        // 선택 하이라이트는 배경색 전환만으로 즉시 반영되어야 한다 — 기본
        // InkSparkle 스플래시는 셰이더 애니메이션 때문에 체감 지연을 만든다.
        splashFactory: NoSplash.splashFactory,
        highlightColor: isDark ? Colors.white10 : Colors.black12,
        child: _row(context, dragHighlight: dragHighlight),
      );
    }

    Widget content = entry.isDirectory
        ? DragTarget<DragPayload>(
            onWillAcceptWithDetails: (details) =>
                !details.data.entries.any((e) => e.location == entry.location),
            onAcceptWithDetails: (details) => onFolderDrop(details.data),
            builder: (context, candidateData, rejectedData) =>
                tappable(dragHighlight: candidateData.isNotEmpty),
          )
        : tappable();

    return Draggable<DragPayload>(
      data: dragPayload,
      feedback: _DragFeedback(payload: dragPayload),
      childWhenDragging: Opacity(opacity: 0.35, child: _row(context)),
      child: content,
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.payload});

  final DragPayload payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final multi = payload.entries.length > 1;
    final first = payload.entries.first;
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.9,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceHi : AppColors.surfaceHiLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.primary : AppColors.primaryDeep,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FileIcon(
                    name: first.name,
                    isDirectory: first.isDirectory,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      multi
                          ? AppLocalizations.of(context).itemCountLabel(payload.entries.length)
                          : first.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
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

class _PaneStatusBar extends StatelessWidget {
  const _PaneStatusBar({
    required this.count,
    required this.selectedCount,
    required this.selectedBytes,
    required this.quickFilter,
  });

  final int count;
  final int selectedCount;
  final int selectedBytes;
  final String quickFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = selectedCount > 0
        ? l10n.selectedCountLabel(selectedCount, formatBytes(selectedBytes))
        : l10n.itemCountLabel(count);
    final label = quickFilter.isEmpty ? base : l10n.searchStatusLabel(quickFilter, base);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

/// Finder/탐색기 등 OS에서 이 패널로 드래그해온 파일을 받는다. `desktop_drop`은
/// 네이티브 OS 드래그 이벤트를 쓰므로, 패널 내부의 Flutter `Draggable`/
/// `DragTarget`(패널 간 이동)과는 완전히 다른 경로라 서로 간섭하지 않는다.
class _ExternalDropOverlay extends StatefulWidget {
  const _ExternalDropOverlay({
    required this.onFilesDropped,
    required this.child,
  });

  final ValueChanged<List<String>> onFilesDropped;
  final Widget child;

  @override
  State<_ExternalDropOverlay> createState() => _ExternalDropOverlayState();
}

class _ExternalDropOverlayState extends State<_ExternalDropOverlay> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (details) {
        setState(() => _hovering = false);
        widget.onFilesDropped(details.files.map((f) => f.path).toList());
      },
      child: Stack(
        children: [
          widget.child,
          if (_hovering)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.primary : AppColors.primaryDeep)
                        .withValues(alpha: 0.10),
                    border: Border.all(
                      color: isDark ? AppColors.primary : AppColors.primaryDeep,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
