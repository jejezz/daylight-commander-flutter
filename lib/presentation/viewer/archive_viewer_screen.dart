import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../application/archive_service.dart';
import '../../core/bytes_format.dart';
import '../../core/date_format.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/file_icon.dart';
import 'viewer_screen.dart';

const _archiveService = ArchiveService();

/// zip 내부를 풀지 않고 훑어보는 뷰어 (F3/컨텍스트 메뉴 "보기", PLAN.md P2 —
/// "압축파일 내부 미리보기"). 항목 이름의 슬래시로 가상 폴더 구조를 만들고,
/// ".." 항목으로 상위 폴더 이동, 파일은 더블클릭 시 임시 폴더로 그 하나만
/// 꺼내 [ViewerScreen]으로 연다 (zip 전체는 풀지 않음).
class ArchiveViewerScreen extends StatefulWidget {
  const ArchiveViewerScreen({super.key, required this.zipPath, required this.archiveName});

  final String zipPath;
  final String archiveName;

  @override
  State<ArchiveViewerScreen> createState() => _ArchiveViewerScreenState();
}

class _ArchiveNode {
  const _ArchiveNode({
    required this.name,
    required this.fullPath,
    required this.isDirectory,
    this.size,
    this.modifiedAt,
  });

  final String name;
  final String fullPath;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedAt;
}

class _ArchiveViewerScreenState extends State<ArchiveViewerScreen> {
  late final Future<List<ArchiveEntry>> _entriesFuture;
  final List<String> _currentPath = [];

  @override
  void initState() {
    super.initState();
    _entriesFuture = _archiveService.listZipEntries(widget.zipPath);
  }

  List<_ArchiveNode> _childrenOf(List<ArchiveEntry> entries) {
    final prefix = _currentPath.isEmpty ? '' : '${_currentPath.join('/')}/';
    final dirs = <String, _ArchiveNode>{};
    final files = <_ArchiveNode>[];

    for (final entry in entries) {
      final name = entry.name.replaceAll('\\', '/');
      if (!name.startsWith(prefix)) continue;
      final rest = name.substring(prefix.length);
      if (rest.isEmpty) continue;

      final slashIndex = rest.indexOf('/');
      if (slashIndex == -1) {
        if (!entry.isDirectory) {
          files.add(_ArchiveNode(
            name: rest,
            fullPath: name,
            isDirectory: false,
            size: entry.size,
            modifiedAt: entry.modifiedAt,
          ));
        }
      } else {
        final dirName = rest.substring(0, slashIndex);
        dirs.putIfAbsent(
          dirName,
          () => _ArchiveNode(name: dirName, fullPath: '$prefix$dirName', isDirectory: true),
        );
      }
    }

    final sortedDirs = dirs.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    final sortedFiles = files..sort((a, b) => a.name.compareTo(b.name));
    return [...sortedDirs, ...sortedFiles];
  }

  Future<void> _openFile(_ArchiveNode node) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp('daylight_commander_archive_');
      final tempFile = File(p.join(tempDir.path, node.name));
      await _archiveService.extractZipEntry(
        zipPath: widget.zipPath,
        entryName: node.fullPath,
        destinationPath: tempFile.path,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ViewerScreen(path: tempFile.path, name: node.name),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).archiveEntryOpenFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title =
        _currentPath.isEmpty ? widget.archiveName : '${widget.archiveName} / ${_currentPath.join('/')}';

    return Scaffold(
      appBar: AppBar(title: Text(title), toolbarHeight: 44),
      body: FutureBuilder<List<ArchiveEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.archiveEntryOpenFailed('${snapshot.error}')));
          }

          final nodes = _childrenOf(snapshot.data!);
          if (nodes.isEmpty && _currentPath.isEmpty) {
            return Center(child: Text(l10n.archiveEmptyFolder));
          }

          return ListView(
            children: [
              if (_currentPath.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.arrow_upward),
                  title: const Text('..'),
                  onTap: () => setState(() => _currentPath.removeLast()),
                ),
              for (final node in nodes)
                ListTile(
                  leading: FileIcon(name: node.name, isDirectory: node.isDirectory),
                  title: Text(node.name),
                  trailing: node.isDirectory
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatBytes(node.size)),
                            const SizedBox(width: 16),
                            SizedBox(width: 90, child: Text(formatModified(node.modifiedAt))),
                          ],
                        ),
                  onTap: () {
                    if (node.isDirectory) {
                      setState(() => _currentPath.add(node.name));
                    } else {
                      _openFile(node);
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
