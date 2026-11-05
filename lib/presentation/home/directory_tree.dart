import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/drive_entry.dart';
import '../../domain/entities/file_entry.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'drag_payload.dart';
import 'drive_icon.dart';
import 'pane_controller.dart';
import 'drives_provider.dart';
import 'pane_actions.dart';

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
  Timer? _timer;
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    // 트리 밖(다른 패널, OS)에서 폴더가 바뀌어도 따라가도록 주기적으로 다시 읽는다.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    // 시작 시점의 활성 패널 경로까지 트리를 펼친다 (이후 변경은 build의 ref.listen이 처리).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealPath(ref.read(paneControllerProvider(widget.side)).currentPath);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 펼쳐진(= 보이는) 폴더의 자식 목록을 다시 읽는다. 달라진 곳만 갱신하고,
  /// 사라진 폴더는 펼침 상태에서도 뺀다.
  Future<void> refresh() async {
    if (_reloading || !mounted) return;
    _reloading = true;
    try {
      var changed = false;
      for (final path in _children.keys.toList()) {
        if (!mounted) return;
        if (!_expanded.contains(path) && !_isDrive(path)) continue;
        final names = await _listChildren(path);
        final old = _children[path];
        if (old == null || !_sameList(old, names)) {
          _children[path] = names;
          changed = true;
        }
      }
      final gone = _expanded.where((e) => !Directory(e).existsSync()).toList();
      if (gone.isNotEmpty) {
        _expanded.removeAll(gone);
        _children.removeWhere((k, _) => gone.contains(k));
        changed = true;
      }
      if (changed && mounted) setState(() {});
    } finally {
      _reloading = false;
    }
  }

  bool _isDrive(String path) =>
      (ref.read(drivesProvider).valueOrNull ?? const <DriveEntry>[])
          .any((d) => d.path == path);

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _loadChildren(String path) async {
    if (_children.containsKey(path) || _loading.contains(path)) return;
    _loading.add(path);
    final names = await _listChildren(path);
    _loading.remove(path);
    if (!mounted) return;
    setState(() => _children[path] = names);
  }

  Future<List<String>> _listChildren(String path) async {
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
    return names;
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
    // 파일 작업(복사·이동·삭제·새 폴더 등)으로 어느 패널의 목록이 바뀌면 트리도 새로 읽는다.
    for (final s in PaneSide.values) {
      ref.listen(
        paneControllerProvider(s).select((st) => st.entries),
        (_, _) => refresh(),
      );
    }
    final drives =
        ref.watch(drivesProvider).valueOrNull ?? const <DriveEntry>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = <Widget>[];

    void addNode(String path, String label, int depth, {DriveKind? driveKind}) {
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
          driveKind: driveKind,
          onToggle: () => _toggle(path),
          onTap: () => _select(path),
          path: path,
          draggable: depth > 0,
          onDrop: (payload) => dropOnTreeFolder(
            context,
            ref,
            payload: payload,
            target: path,
          ),
          onSecondaryTap: (pos) => showTreeContextMenu(
            context,
            ref,
            side: side,
            path: path,
            isRoot: depth == 0,
            globalPosition: pos,
            onChanged: refresh,
          ),
        ),
      );
      if (expanded && children != null) {
        for (final c in children) {
          addNode(c, p.basename(c), depth + 1);
        }
      }
    }

    for (final d in drives) {
      addNode(d.path, d.name, 0, driveKind: d.kind);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: rows,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: AppLocalizations.of(context).refreshTooltip,
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(drivesProvider);
                  refresh();
                },
              ),
            ),
          ],
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
    required this.onSecondaryTap,
    required this.path,
    required this.draggable,
    required this.onDrop,
    this.driveKind,
  });

  final String label;
  final int depth;
  final bool expanded;
  final bool leaf;
  final bool selected;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final void Function(Offset globalPosition) onSecondaryTap;
  final String path;
  final bool draggable;
  final void Function(DragPayload payload) onDrop;

  /// 드라이브 루트 행에서만 넘어온다(하위 폴더는 null) — 네트워크/이동식
  /// 드라이브면 전용 아이콘을, 아니면 평소 폴더 아이콘을 쓴다.
  final DriveKind? driveKind;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final icon = (driveKind == null ? null : driveKindIcon(driveKind!, color: accent)) ??
        Icon(expanded ? Icons.folder_open : Icons.folder, size: 16, color: accent);
    final row = _buildRow(context, accent, icon);
    final uri = Uri.file(path);
    final payload = DragPayload(
      fromSide: PaneSide.left,
      entries: [FileEntry(location: uri, name: p.basename(path), isDirectory: true)],
    );
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (d) => !d.data.entries.any(
        (e) => e.location == uri || p.isWithin(e.location.toFilePath(), path),
      ),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final target = candidates.isNotEmpty
            ? ColoredBox(color: accent.withValues(alpha: 0.25), child: row)
            : row;
        if (!draggable) return target;
        return Draggable<DragPayload>(
          data: payload,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent),
              ),
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: row),
          child: target,
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, Color accent, Widget icon) {
    return InkWell(
      onTap: onTap,
      onSecondaryTapUp: (d) => onSecondaryTap(d.globalPosition),
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
            icon,
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  // 색을 안 넣으면 bodyMedium(textMid, 흐린 보조색)을 물려받아
                  // 다크 모드에서 특히 희미해 보인다 — 파일 목록 이름(bodyLarge)과
                  // 같은 고대비 색으로 맞춘다.
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
