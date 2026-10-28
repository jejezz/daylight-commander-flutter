import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_drag_out/flutter_drag_out.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/thumbnail_policy.dart';
import '../../application/thumbnail_providers.dart';
import '../../core/bytes_format.dart';
import '../../core/date_format.dart';
import '../../domain/entities/drive_entry.dart';
import '../../domain/entities/file_entry.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/file_icon.dart';
import '../widgets/thumbnail_image.dart';
import '../widgets/tool_icon.dart';
import 'bookmarks_provider.dart';
import 'drag_payload.dart';
import 'drive_icon.dart';
import 'drive_utils.dart';
import 'drives_provider.dart';
import 'folder_comparison_provider.dart';
import 'pane_actions.dart';
import 'pane_controller.dart';
import 'pane_view_mode_provider.dart';
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
    final viewSettings = ref.watch(paneViewSettingsProvider(side));
    final thumbnailPolicy = ref.read(thumbnailPolicyProvider);
    final diffMap = comparison == null
        ? const <Uri, FileDiffStatus>{}
        : (side == PaneSide.left ? comparison.left : comparison.right);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visibleEntries = state.visibleEntries;
    final l10n = AppLocalizations.of(context);

    ref.listen<PaneState>(paneControllerProvider(side), (previous, next) {
      if (!next.loading &&
          next.error == null &&
          previous?.currentPath != next.currentPath) {
        ref.read(recentFoldersProvider.notifier).record(next.currentPath);
      }
      // 이동 실패(권한 없음 등)는 목록을 지우지 않고 그대로 둔 채(._load가 currentPath/
      // entries를 안 건드린다) 팝업으로만 알린다.
      if (next.error != null && previous?.error != next.error) {
        final message = next.error!;
        controller.clearError();
        showErrorDialog(context, title: l10n.folderOpenErrorTitle, message: message);
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

    Widget buildItem(
      BuildContext context,
      int index, {
      required bool grid,
      double thumbExtent = 0,
    }) {
      final entry = visibleEntries[index];
      final selected = state.selection.contains(entry.location);
      final payload = (selected && state.selection.length > 1)
          ? DragPayload(fromSide: side, entries: state.selectedEntries)
          : DragPayload(fromSide: side, entries: [entry]);
      return _FileRow(
        entry: entry,
        gridMode: grid,
        thumbExtent: thumbExtent,
        thumbKind: grid ? thumbnailPolicy.kindFor(entry) : null,
        folderPreview: grid && thumbnailPolicy.canPreviewFolder(entry),
        selected: selected,
        isCursor: index == state.cursorIndex,
        dragPayload: payload,
        dragOutItems: () => dragOutItemsFor(ref, payload.entries),
        diffStatus: diffMap[entry.location],
        onSelect: () {
          ref.read(activePaneProvider.notifier).state = side;
          final keys = HardwareKeyboard.instance;
          final hasModifier =
              keys.isShiftPressed ||
              keys.isControlPressed ||
              keys.isMetaPressed;
          final isDoubleClick = controller.consumeDoubleClick(entry.location);
          if (isDoubleClick && !hasModifier) {
            if (entry.isDirectory) {
              controller.openEntry(entry);
            } else {
              openEntryWithDefaultApp(context, ref, entry);
            }
            return;
          }
          if (keys.isShiftPressed) {
            controller.selectRange(index);
          } else if (keys.isControlPressed || keys.isMetaPressed) {
            controller.toggleSelection(index);
          } else {
            controller.selectOnly(index);
          }
        },
        onSecondaryTap: (globalPosition) => showRowContextMenu(
          context,
          ref,
          side: side,
          entry: entry,
          index: index,
          globalPosition: globalPosition,
        ),
        onFolderDrop: (payload) =>
            handleDrop(payload, locationToPathString(entry.location)),
      );
    }

    return _ExternalDropOverlay(
      onFilesDropped: (paths) => dropExternalFiles(context, ref, side, paths),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : (Theme.of(context).dividerColor),
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
                  side: side,
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
                      : DragTarget<DragPayload>(
                          onAcceptWithDetails: (details) =>
                              handleDrop(details.data, state.currentPath),
                          builder: (context, candidateData, rejectedData) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: candidateData.isNotEmpty
                                    ? (Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.05))
                                    : null,
                              ),
                              child: viewSettings.isThumbnails
                                  ? _ThumbnailGrid(
                                      side: side,
                                      itemCount: visibleEntries.length,
                                      extent: viewSettings.thumbnailSize.extent,
                                      cursorIndex: state.cursorIndex,
                                      onStepSize: (delta) => ref
                                          .read(paneViewSettingsProvider(side).notifier)
                                          .stepThumbnailSize(delta),
                                      itemBuilder: (context, index, extent) =>
                                          buildItem(
                                            context,
                                            index,
                                            grid: true,
                                            thumbExtent: extent,
                                          ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      itemCount: visibleEntries.length,
                                      itemBuilder: (context, index) =>
                                          buildItem(
                                            context,
                                            index,
                                            grid: false,
                                          ),
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
                  viewSettings: viewSettings,
                  onToggleViewMode: () =>
                      ref.read(paneViewSettingsProvider(side).notifier).toggleMode(),
                  onSelectThumbnailSize: (size) =>
                      ref.read(paneViewSettingsProvider(side).notifier).setThumbnailSize(size),
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
    required this.side,
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

  final PaneSide side;
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

  // 경로 입력창에 포커스가 남아 있으면 HomeScreen의 키 핸들러가 모든 키를
  // 무시한다(Delete 등 단축키가 먹통). 입력이 끝나면 포커스를 상위 Focus로
  // 돌려 단축키가 다시 동작하게 한다. 다이얼로그 등이 위에 떠 있으면 건드리지 않는다.
  void _releaseFocus() {
    if (!_focusNode.hasPrimaryFocus) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _focusNode.parent?.requestFocus();
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
            icon: const ToolIcon('icons8-left.svg', size: 18),
            tooltip: l10n.goBackTooltip,
            onPressed: widget.canGoBack ? widget.onBack : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const ToolIcon('icons8-right.svg', size: 18),
            tooltip: l10n.goForwardTooltip,
            onPressed: widget.canGoForward ? widget.onForward : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const ToolIcon('icons8-up.svg', size: 18),
            tooltip: l10n.goUpTooltip,
            onPressed: widget.onUp,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const ToolIcon('icons8-refresh.svg', size: 18),
            tooltip: l10n.refreshTooltip,
            onPressed: widget.onRefresh,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.switchDriveTooltip,
            icon: const ToolIcon('icons8-drive.svg', size: 18),
            onSelected: widget.onSelectDrive,
            itemBuilder: (context) {
              final accent = Theme.of(context).colorScheme.primary;
              return [
                for (final drive in widget.drives)
                  PopupMenuItem(
                    value: drive.path,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: driveKindIcon(drive.kind, color: accent, size: 16),
                        ),
                        Expanded(
                          child: Text(drive.name, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ];
            },
          ),
          PopupMenuButton<String>(
            tooltip: l10n.networkConnectTooltip,
            icon: ToolIcon('icons8-network-drive.svg', size: 18, active: widget.isRemote),
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
            icon: ToolIcon('icons8-favorite.svg', size: 18, active: widget.isBookmarked),
            tooltip: widget.isBookmarked ? l10n.removeBookmarkTooltip : l10n.addBookmarkTooltip,
            onPressed: widget.onToggleBookmark,
          ),
          if (widget.bookmarks.isNotEmpty || widget.recentFolders.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: l10n.bookmarksAndRecentTooltip,
              icon: const ToolIcon('icons8-favorite-folder.svg', size: 18),
              onSelected: widget.onSelectBookmark,
              itemBuilder: (context) => [
                if (widget.bookmarks.isNotEmpty) ...[
                  PopupMenuItem<String>(
                    enabled: false,
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(path, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ],
            ),
          Expanded(
            child: Tooltip(
              message: widget.path,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6),
                ),
                onSubmitted: (value) {
                  widget.onSubmitPath(value);
                  _releaseFocus();
                },
                onTapOutside: (_) => _releaseFocus(),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: ToolIcon('icons8-hide.svg', size: 18, active: widget.showHidden),
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
    required this.dragOutItems,
    required this.diffStatus,
    required this.onSelect,
    required this.onSecondaryTap,
    required this.onFolderDrop,
    this.gridMode = false,
    this.thumbExtent = 0,
    this.thumbKind,
    this.folderPreview = false,
  });

  final bool gridMode;
  final double thumbExtent;
  final ThumbnailKind? thumbKind;

  /// 폴더라면 안의 이미지를 모아 썸네일로 보인다.
  final bool folderPreview;
  final FileEntry entry;
  final bool selected;

  /// 키보드 커서(화살표로 이동한 위치)가 이 행인지. [selected]와 독립적이다 —
  /// 화살표만으로는 다중선택에 들어가지 않고(스페이스가 필요) 커서 표시만 된다.
  final bool isCursor;
  final DragPayload dragPayload;

  /// 창 밖으로 끌어냈을 때 OS 드래그에 실을 항목([dragOutItemsFor]).
  final List<DragOutItem>? Function() dragOutItems;
  final FileDiffStatus? diffStatus;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onSecondaryTap;
  final ValueChanged<DragPayload> onFolderDrop;

  Widget _row(BuildContext context, {bool dragHighlight = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = dragHighlight
        ? (Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.18))
        : selected
        ? (Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.10))
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
        borderRadius: gridMode ? BorderRadius.circular(8) : null,
        border: isCursor
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: gridMode ? 1.5 : 1,
              )
            : (gridMode && selected)
            ? Border.all(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.5),
              )
            : null,
      ),
      padding: gridMode
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: gridMode
          ? _cell(theme)
          : Row(
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

  Widget _cell(ThemeData theme) {
    final iconExtent = thumbExtent - 8;
    return Column(
      children: [
        // 폴더와 아이콘만 보이는 파일은 둥근 타일 위에 놓고, 내용이 있는 썸네일(이미지·PDF 등)은
        // 그림 자체의 모서리를 둥글게 한다. 반지름은 셀 크기에 비례한다.
        Expanded(
          child: folderPreview
              ? FolderThumbnail(
                  path: locationToPathString(entry.location),
                  name: entry.name,
                  extent: iconExtent,
                  modifiedMs: entry.modifiedAt?.millisecondsSinceEpoch,
                )
              : entry.isDirectory || thumbKind == null
              ? ThumbnailIconTile(
                  name: entry.name,
                  isDirectory: entry.isDirectory,
                  extent: iconExtent,
                )
              : ThumbnailImage(
                  path: locationToPathString(entry.location),
                  name: entry.name,
                  kind: thumbKind,
                  extent: iconExtent,
                  modifiedMs: entry.modifiedAt?.millisecondsSinceEpoch,
                  sizeBytes: entry.sizeBytes,
                ),
        ),
        const SizedBox(height: 4),
        // 이름 칸 높이를 2줄로 고정하고 아래쪽에 붙인다 — 이름이 길든 짧든 아이콘
        // 위치가 같고, 이름의 마지막 줄은 모든 셀에서 같은 높이에 놓인다.
        SizedBox(
          height: 34,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              breakableName(entry.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ),
      ],
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

    final windowSize = MediaQuery.sizeOf(context);
    // 이름이 길어 잘려도 전체 이름·확장자를 볼 수 있게 마우스를 올리면 툴팁으로 보인다.
    return Tooltip(
      message: entry.name,
      waitDuration: const Duration(milliseconds: 600),
      child: Draggable<DragPayload>(
      data: dragPayload,
      // 창 밖으로 나가면 OS 드래그로 넘겨 Finder/탐색기에 떨굴 수 있게 한다.
      // 원격 항목은 드롭된 뒤 그 자리로 내려받는다(macOS 파일 프로미스).
      onDragUpdate: (details) => FlutterDragOut.maybeStartOnExit(
        details.globalPosition,
        viewSize: windowSize,
        items: dragOutItems,
      ),
      feedback: _DragFeedback(payload: dragPayload),
      childWhenDragging: Opacity(opacity: 0.35, child: _row(context)),
      child: content,
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.payload});

  final DragPayload payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
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
    required this.viewSettings,
    required this.onToggleViewMode,
    required this.onSelectThumbnailSize,
  });

  final PaneViewSettings viewSettings;
  final VoidCallback onToggleViewMode;
  final ValueChanged<ThumbnailSize> onSelectThumbnailSize;
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
    Widget viewButton(String asset, String tooltip, VoidCallback onPressed) => InkWell(
      onTap: onPressed,
      splashFactory: NoSplash.splashFactory,
      child: Tooltip(
        message: tooltip,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: ToolIcon(asset, size: 18)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.labelSmall, overflow: TextOverflow.ellipsis),
          ),
          if (viewSettings.isThumbnails)
            Builder(
              builder: (buttonContext) => viewButton(
                'icons8-resize-file.svg',
                l10n.thumbnailSizeTooltip,
                () => showThumbnailMenu(buttonContext, viewSettings.thumbnailSize, onSelectThumbnailSize),
              ),
            ),
          viewButton(
            viewSettings.isThumbnails ? 'icons8-list.svg' : 'icons8-grid-view.svg',
            viewSettings.isThumbnails ? l10n.viewModeDetailsTooltip : l10n.viewModeThumbnailsTooltip,
            onToggleViewMode,
          ),
        ],
      ),
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
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
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

/// 썸네일 보기 그리드. 패널 폭에 맞춰 열 수를 정하고(셀은 정사각형), 키보드
/// 상하 이동이 쓸 수 있게 열 수([paneGridColumnsProvider])와 한 화면에 보이는 행 수
/// ([paneGridPageRowsProvider])를 기록한다.
/// 커서가 화면 밖으로 나가면 스크롤해서 보이게 한다.
/// 긴 이름이 글자 단위로 끊기지 않도록 `.`, `_`, `-`, 공백 뒤에 줄바꿈 후보
/// (zero-width space)를 넣는다. 화면 표시용이라 실제 이름은 바뀌지 않는다.
@visibleForTesting
String breakableName(String name) =>
    name.replaceAllMapped(RegExp(r'[._\-]'), (m) => '${m[0]}\u200B');

class _ThumbnailGrid extends ConsumerStatefulWidget {
  const _ThumbnailGrid({
    required this.side,
    required this.itemCount,
    required this.extent,
    required this.cursorIndex,
    required this.itemBuilder,
    required this.onStepSize,
  });

  final PaneSide side;
  final int itemCount;
  final double extent;
  final int? cursorIndex;
  final Widget Function(BuildContext context, int index, double cellExtent)
  itemBuilder;

  /// Ctrl/Cmd + 마우스 휠로 썸네일 크기를 한 단계씩 바꾼다(+1 크게, -1 작게).
  final ValueChanged<int> onStepSize;

  @override
  ConsumerState<_ThumbnailGrid> createState() => _ThumbnailGridState();
}

class _ThumbnailGridState extends ConsumerState<_ThumbnailGrid> {
  static const _padding = 6.0;
  static const _spacing = 4.0;
  static const _labelHeight = 46.0; // 이름 34 + 간격 4 + 셀 안쪽 여백 8

  final _scroll = ScrollController();
  DateTime _lastWheelStep = DateTime.fromMillisecondsSinceEpoch(0);
  int _columns = 1;
  double _cellWidth = 0;

  double get _cellHeight => _cellWidth + _labelHeight;

  @override
  void didUpdateWidget(_ThumbnailGrid old) {
    super.didUpdateWidget(old);
    if (old.cursorIndex != widget.cursorIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealCursor());
    }
  }

  void _revealCursor() {
    final index = widget.cursorIndex;
    if (index == null || !_scroll.hasClients || _cellWidth <= 0) return;
    final row = index ~/ _columns;
    final top = _padding + row * (_cellHeight + _spacing);
    final bottom = top + _cellHeight;
    final position = _scroll.position;
    final viewTop = position.pixels;
    final viewBottom = viewTop + position.viewportDimension;
    double? target;
    if (top < viewTop) {
      target = top - _padding;
    } else if (bottom > viewBottom) {
      target = bottom + _padding - position.viewportDimension;
    }
    if (target != null) {
      _scroll.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final usable = math.max(1.0, constraints.maxWidth - _padding * 2);
        // 셀은 고정 폭이고 남는 폭은 오른쪽에 비운다(탐색기처럼 왼쪽 정렬).
        final cell = math.min(widget.extent, usable);
        final columns = ((usable + _spacing) / (cell + _spacing))
            .floor()
            .clamp(1, 1000);
        _columns = columns;
        _cellWidth = cell;
        // 스크롤바가 패널 오른쪽 끝에 붙도록 스크롤 영역은 항상 전체 폭이고,
        // 남는 폭은 오른쪽 안쪽 여백으로 비운다.
        final leftover = usable - (columns * cell + (columns - 1) * _spacing);
        final side = widget.side;
        final pageRows = math
            .max(1, ((constraints.maxHeight - _padding * 2 + _spacing) /
                    (_cellHeight + _spacing))
                .floor());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (ref.read(paneGridColumnsProvider(side)) != columns) {
            ref.read(paneGridColumnsProvider(side).notifier).state = columns;
          }
          if (ref.read(paneGridPageRowsProvider(side)) != pageRows) {
            ref.read(paneGridPageRowsProvider(side).notifier).state = pageRows;
          }
        });
        return Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            final keys = HardwareKeyboard.instance;
            if (!keys.isControlPressed && !keys.isMetaPressed) return;
            // 휠 한 번에 여러 이벤트가 오므로 일정 간격으로만 한 단계씩 바꾼다.
            GestureBinding.instance.pointerSignalResolver.register(event, (_) {
              final now = DateTime.now();
              if (now.difference(_lastWheelStep) < const Duration(milliseconds: 250)) return;
              _lastWheelStep = now;
              widget.onStepSize(event.scrollDelta.dy < 0 ? 1 : -1);
            });
          },
          child: GridView.builder(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            _padding,
            _padding,
            _padding + leftover,
            _padding,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            childAspectRatio: _cellWidth / _cellHeight,
          ),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) =>
              widget.itemBuilder(context, index, _cellWidth),
          ),
        );
      },
    );
  }
}

String _thumbnailSizeLabel(AppLocalizations l10n, ThumbnailSize size) => switch (size) {
  ThumbnailSize.small => l10n.thumbnailSizeSmall,
  ThumbnailSize.medium => l10n.thumbnailSizeMedium,
  ThumbnailSize.large => l10n.thumbnailSizeLarge,
};

/// 썸네일 크기 선택과 썸네일 캐시 비우기 메뉴. 버튼 위에 펼친다.
Future<void> showThumbnailMenu(
  BuildContext buttonContext,
  ThumbnailSize current,
  ValueChanged<ThumbnailSize> onSelect,
) async {
  final l10n = AppLocalizations.of(buttonContext);
  final messenger = ScaffoldMessenger.of(buttonContext);
  final box = buttonContext.findRenderObject() as RenderBox;
  final overlay = Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
    Offset.zero & overlay.size,
  );
  final cacheBytes = await sharedThumbnailCache.totalBytes();
  if (!buttonContext.mounted) return;
  final choice = await showMenu<Object>(
    context: buttonContext,
    position: position,
    items: [
      for (final size in ThumbnailSize.values)
        CheckedPopupMenuItem<Object>(
          value: size,
          checked: size == current,
          child: Text(_thumbnailSizeLabel(l10n, size)),
        ),
      const PopupMenuDivider(),
      PopupMenuItem<Object>(
        value: 'clear',
        child: Text(l10n.clearThumbnailCache(formatBytes(cacheBytes))),
      ),
    ],
  );
  if (choice is ThumbnailSize) {
    onSelect(choice);
  } else if (choice == 'clear') {
    await sharedThumbnailCache.clear();
    PaintingBinding.instance.imageCache.clear();
    messenger.showSnackBar(SnackBar(content: Text(l10n.thumbnailCacheCleared)));
  }
}
