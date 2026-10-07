import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/drive_entry.dart';
import '../theme/app_theme.dart';
import 'pane_controller.dart';
import 'drives_provider.dart';

OverlayEntry? _treeBarrier;
OverlayEntry? _treePopup;

bool get isDirectoryTreePopupOpen => _treePopup != null;

void closeDirectoryTreePopup() {
  _treeBarrier?.remove();
  _treePopup?.remove();
  _treeBarrier = null;
  _treePopup = null;
}

/// [anchorContext](패널 우측의 트리 버튼) 아래에 [side] 패널용 디렉토리 트리
/// 팝업을 띄운다. 트리에서 폴더를 누르면 그 패널이 이동하고 팝업은 유지되며,
/// 팝업 바깥(패널 등)을 누르면 팝업이 닫힌다 — 그 클릭은 아래 위젯에도 그대로
/// 전달된다(barrier가 translucent라서).
void showDirectoryTreePopup(BuildContext anchorContext, PaneSide side) {
  closeDirectoryTreePopup();
  final overlay = Overlay.of(anchorContext);
  final button = anchorContext.findRenderObject() as RenderBox;
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final anchor = button.localToGlobal(Offset.zero, ancestor: overlayBox);
  final screen = overlayBox.size;

  const width = 300.0;
  final height = (screen.height - anchor.dy - button.size.height - 16).clamp(160.0, 440.0);
  final left = (anchor.dx + button.size.width - width).clamp(8.0, screen.width - width - 8);
  final top = anchor.dy + button.size.height + 4;

  _treeBarrier = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => closeDirectoryTreePopup(),
      ),
    ),
  );
  _treePopup = OverlayEntry(
    builder: (_) => Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: DirectoryTree(side: side),
      ),
    ),
  );
  overlay.insert(_treeBarrier!);
  overlay.insert(_treePopup!);
}

/// 탐색기/Finder 스타일의 디렉토리 트리. 루트는 드라이브/볼륨 목록이고
/// 하위 폴더는 펼칠 때 지연 로딩한다. 폴더를 클릭하면 [side] 패널이 그
/// 폴더로 이동하고, 그 패널의 현재 경로가 트리에서 강조된다.
class DirectoryTree extends ConsumerStatefulWidget {
  const DirectoryTree({super.key, required this.side});

  final PaneSide side;

  @override
  ConsumerState<DirectoryTree> createState() => _DirectoryTreeState();
}

class _DirectoryTreeState extends ConsumerState<DirectoryTree> {
  final Set<String> _expanded = {};
  final Map<String, List<String>> _children = {};
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    // 시작 시점의 활성 패널 경로까지 트리를 펼친다 (이후 변경은 build의 ref.listen이 처리).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealPath(ref.read(paneControllerProvider(widget.side)).currentPath);
    });
  }

  Future<void> _loadChildren(String path) async {
    if (_children.containsKey(path) || _loading.contains(path)) return;
    _loading.add(path);
    final names = <String>[];
    try {
      await for (final e in Directory(path).list(followLinks: false)) {
        if (e is! Directory) continue;
        final name = p.basename(e.path);
        if (name.startsWith('.')) continue;
        names.add(e.path);
      }
      names.sort(
        (a, b) =>
            p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()),
      );
    } catch (_) {
      // 접근 권한 없음 등: 자식이 없는 것으로 취급한다.
    }
    _loading.remove(path);
    if (!mounted) return;
    setState(() => _children[path] = names);
  }

  void _toggle(String path) {
    if (_expanded.remove(path)) {
      setState(() {});
    } else {
      setState(() => _expanded.add(path));
      _loadChildren(path);
    }
  }

  /// [target]의 모든 조상을 펼쳐서 트리에서 보이게 한다.
  void _revealPath(String target) {
    if (isRemotePath(target)) return;
    var cur = target;
    final toLoad = <String>[];
    while (true) {
      final parent = p.dirname(cur);
      if (parent == cur) break;
      toLoad.add(parent);
      cur = parent;
    }
    var changed = false;
    for (final dir in toLoad) {
      if (_expanded.add(dir)) changed = true;
      _loadChildren(dir);
    }
    if (changed) setState(() {});
  }

  void _select(String path) {
    ref.read(activePaneProvider.notifier).state = widget.side;
    ref.read(paneControllerProvider(widget.side).notifier).navigateTo(path);
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.side;
    final currentPath = ref.watch(
      paneControllerProvider(side).select((s) => s.currentPath),
    );
    ref.listen<String>(
      paneControllerProvider(side).select((s) => s.currentPath),
      (_, next) => _revealPath(next),
    );
    final drives =
        ref.watch(drivesProvider).valueOrNull ?? const <DriveEntry>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = <Widget>[];

    void addNode(String path, String label, int depth) {
      final expanded = _expanded.contains(path);
      final children = _children[path];
      final hasNoChildren = children != null && children.isEmpty;
      rows.add(
        _TreeRow(
          label: label,
          depth: depth,
          expanded: expanded,
          leaf: hasNoChildren,
          selected: _samePath(path, currentPath),
          isDark: isDark,
          onToggle: () => _toggle(path),
          onTap: () => _select(path),
        ),
      );
      if (expanded && children != null) {
        for (final c in children) {
          addNode(c, p.basename(c), depth + 1);
        }
      }
    }

    for (final d in drives) {
      addNode(d.path, d.name, 0);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: isDark ? AppColors.stroke : AppColors.strokeLight),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: rows,
        ),
      ),
    );
  }

  bool _samePath(String a, String b) => p.normalize(a) == p.normalize(b);
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.label,
    required this.depth,
    required this.expanded,
    required this.leaf,
    required this.selected,
    required this.isDark,
    required this.onToggle,
    required this.onTap,
  });

  final String label;
  final int depth;
  final bool expanded;
  final bool leaf;
  final bool selected;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.primary : AppColors.primaryDeep;
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      child: Container(
        height: 26,
        color: selected ? accent.withValues(alpha: 0.18) : null,
        padding: EdgeInsets.only(left: 4.0 + depth * 14),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: leaf
                  ? null
                  : InkWell(
                      onTap: onToggle,
                      child: Icon(
                        expanded ? Icons.expand_more : Icons.chevron_right,
                        size: 16,
                      ),
                    ),
            ),
            Icon(
              expanded ? Icons.folder_open : Icons.folder,
              size: 16,
              color: accent,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
