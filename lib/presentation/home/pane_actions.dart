import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_drag_out/flutter_drag_out.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../application/archive_service.dart';
import '../../application/file_operation_service.dart';
import '../../application/ftp_session_manager.dart';
import '../../application/ftp_transfer_service.dart';
import '../../application/sftp_session_manager.dart';
import '../../application/sftp_transfer_service.dart';
import '../../application/transfer_router.dart';
import '../../application/usecases/connect_network_drive.dart';
import '../../application/usecases/local_file_entry.dart';
import '../../application/usecases/clipboard_files.dart';
import '../../application/usecases/open_terminal.dart';
import '../../application/usecases/open_with_default_app.dart';
import '../../application/usecases/reveal_in_file_manager.dart';
import '../../application/webdav_session_manager.dart';
import '../../application/webdav_transfer_service.dart';
import '../../domain/entities/file_conflict.dart';
import '../../domain/entities/file_entry.dart';
import '../../domain/entities/ftp_profile.dart';
import '../../domain/entities/sftp_profile.dart';
import '../../domain/entities/webdav_profile.dart';
import '../../l10n/app_localizations.dart';
import '../viewer/archive_viewer_screen.dart';
import '../viewer/viewer_screen.dart';
import '../widgets/dialogs.dart';
import '../widgets/properties_dialog.dart';
import 'bookmarks_provider.dart';
import 'folder_comparison_provider.dart';
import 'ftp_profiles_provider.dart';
import 'network_profiles_provider.dart';
import 'operation_controller.dart';
import 'pane_controller.dart';
import 'sftp_profiles_provider.dart';
import 'webdav_profiles_provider.dart';

const _fileOps = FileOperationService();
const _archiveService = ArchiveService();
const _connectNetworkDrive = ConnectNetworkDrive();
const _openTerminal = OpenTerminal();
const _openWithDefaultApp = OpenWithDefaultApp();
const _revealInFileManager = RevealInFileManager();
const _clipboardFiles = ClipboardFiles();

Future<void> openTerminalHere(WidgetRef ref, PaneSide side) async {
  final path = ref.read(paneControllerProvider(side)).currentPath;
  if (isRemotePath(path)) return; // 원격 경로에서는 로컬 터미널을 열 수 없다.
  await _openTerminal(path);
}

/// [from] 패널에만 있거나 다른 패널과 내용이 다른 항목을 반대 패널로 복사한다
/// (단방향 동기화 — PLAN.md P2). 원본은 지우지 않으므로 항상 복사다.
Future<void> syncFolders(BuildContext context, WidgetRef ref, PaneSide from) async {
  final comparison = ref.read(folderComparisonProvider);
  if (comparison == null) return;

  final to = otherSide(from);
  final diffMap = from == PaneSide.left ? comparison.left : comparison.right;
  final sourceEntries = ref.read(paneControllerProvider(from)).entries;
  final toSync = sourceEntries.where((e) => diffMap.containsKey(e.location)).toList();
  if (toSync.isEmpty) return;

  final destinationDir = ref.read(paneControllerProvider(to)).currentPath;
  await transferEntries(
    context,
    ref,
    fromSide: from,
    entries: toSync,
    destinationDir: destinationDir,
    isMove: false,
  );
}

/// 좌우 폴더를 양방향으로 동기화한다 (PLAN.md P2). 한쪽에만 있는 항목은
/// 자동으로 반대쪽에 복사하고, 양쪽에 다 있지만 내용이 다른 파일은
/// [diffPairs]로 짝지어 하나씩 [showSyncConflictDialog]로 물어본다 — "최신
/// 파일 우선" 같은 자동 병합은 하지 않는다.
Future<void> syncFoldersBidirectional(BuildContext context, WidgetRef ref) async {
  final leftEntries = ref.read(paneControllerProvider(PaneSide.left)).entries;
  final rightEntries = ref.read(paneControllerProvider(PaneSide.right)).entries;
  final comparison = compareFolders(leftEntries, rightEntries);

  final leftOnly = leftEntries
      .where((e) => comparison.left[e.location] == FileDiffStatus.onlyHere)
      .toList();
  final rightOnly = rightEntries
      .where((e) => comparison.right[e.location] == FileDiffStatus.onlyHere)
      .toList();

  final leftDir = ref.read(paneControllerProvider(PaneSide.left)).currentPath;
  final rightDir = ref.read(paneControllerProvider(PaneSide.right)).currentPath;

  if (leftOnly.isNotEmpty) {
    await transferEntries(
      context,
      ref,
      fromSide: PaneSide.left,
      entries: leftOnly,
      destinationDir: rightDir,
      isMove: false,
    );
  }
  if (!context.mounted) return;
  if (rightOnly.isNotEmpty) {
    await transferEntries(
      context,
      ref,
      fromSide: PaneSide.right,
      entries: rightOnly,
      destinationDir: leftDir,
      isMove: false,
    );
  }

  final pairs = diffPairs(leftEntries, rightEntries);
  if (pairs.isEmpty) return;

  final operation = ref.read(operationControllerProvider.notifier);
  final ftpSessions = ref.read(ftpSessionManagerProvider.notifier);
  final sftpSessions = ref.read(sftpSessionManagerProvider.notifier);
  final webdavSessions = ref.read(webdavSessionManagerProvider.notifier);

  for (final (left, right) in pairs) {
    if (!context.mounted) return;
    final action = await showSyncConflictDialog(context, left: left, right: right);
    if (action == SyncConflictAction.cancel) return;
    if (action == SyncConflictAction.skip) continue;

    final useLeft = action == SyncConflictAction.useLeft;
    await operation.runCopy(
      sources: [useLeft ? left : right],
      destinationDir: resolveLocationString(useLeft ? rightDir : leftDir),
      onConflict: (_) async => ConflictAction.overwrite,
      ftpSessions: ftpSessions,
      sftpSessions: sftpSessions,
      webdavSessions: webdavSessions,
    );
  }

  await ref.read(paneControllerProvider(PaneSide.left).notifier).refresh();
  await ref.read(paneControllerProvider(PaneSide.right).notifier).refresh();
}

Future<void> copySelectionToOtherPane(
  BuildContext context,
  WidgetRef ref,
  PaneSide from,
) async {
  final to = otherSide(from);
  final sources = ref.read(paneControllerProvider(from)).selectedEntries;
  final destinationDir = ref.read(paneControllerProvider(to)).currentPath;
  await transferEntries(
    context,
    ref,
    fromSide: from,
    entries: sources,
    destinationDir: destinationDir,
    isMove: false,
  );
}

Future<void> moveSelectionToOtherPane(
  BuildContext context,
  WidgetRef ref,
  PaneSide from,
) async {
  final to = otherSide(from);
  final sources = ref.read(paneControllerProvider(from)).selectedEntries;
  final destinationDir = ref.read(paneControllerProvider(to)).currentPath;
  await transferEntries(
    context,
    ref,
    fromSide: from,
    entries: sources,
    destinationDir: destinationDir,
    isMove: true,
  );
}

/// F5/F6 버튼과 드래그앤드롭이 공유하는 전송 로직.
///
/// 드래그앤드롭은 소스/목적지가 어느 패널에 속하는지, 목적지가 패널 루트인지
/// 특정 하위 폴더 행인지에 따라 자유롭게 호출되므로 `entries`/`destinationDir`을
/// 명시적으로 받는다. 로컬/FTP 판단은 [performTransfer]가 URI 스킴으로 한다.
Future<void> transferEntries(
  BuildContext context,
  WidgetRef ref, {
  required PaneSide fromSide,
  required List<FileEntry> entries,
  required String destinationDir,
  required bool isMove,
}) async {
  if (entries.isEmpty) return;

  final destUri = resolveLocationString(destinationDir);
  // entry.location.path는 로컬/FTP 모두 항상 posix 스타일(슬래시)이라
  // p.posix로 통일해서 검사할 수 있다.
  for (final entry in entries) {
    if (entry.location.scheme != destUri.scheme) continue;
    final srcPath = entry.location.path;
    final destPath = destUri.path;
    if (p.posix.equals(destPath, p.posix.dirname(srcPath))) {
      return; // 이미 그 위치에 있음 — 아무 것도 하지 않는다.
    }
    if (entry.isDirectory &&
        (p.posix.equals(destPath, srcPath) || p.posix.isWithin(srcPath, destPath))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).cannotMoveFolderIntoItself)),
        );
      }
      return;
    }
  }

  final operation = ref.read(operationControllerProvider.notifier);
  final ftpSessions = ref.read(ftpSessionManagerProvider.notifier);
  final sftpSessions = ref.read(sftpSessionManagerProvider.notifier);
  final webdavSessions = ref.read(webdavSessionManagerProvider.notifier);
  Future<ConflictAction> onConflict(FileConflict conflict) =>
      showConflictDialog(context, conflict);

  try {
    if (isMove) {
      await operation.runMove(
        sources: entries,
        destinationDir: destUri,
        onConflict: onConflict,
        ftpSessions: ftpSessions,
        sftpSessions: sftpSessions,
        webdavSessions: webdavSessions,
      );
    } else {
      await operation.runCopy(
        sources: entries,
        destinationDir: destUri,
        onConflict: onConflict,
        ftpSessions: ftpSessions,
        sftpSessions: sftpSessions,
        webdavSessions: webdavSessions,
      );
    }
  } on UnsupportedError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? '$e')));
    }
  }

  await ref.read(paneControllerProvider(PaneSide.left).notifier).refresh();
  await ref.read(paneControllerProvider(PaneSide.right).notifier).refresh();
}

Future<void> deleteSelection(BuildContext context, WidgetRef ref, PaneSide side) async {
  final pane = ref.read(paneControllerProvider(side));
  final entries = pane.selectedEntries;
  if (entries.isEmpty) return;

  final choice = await showDeleteConfirmDialog(context, count: entries.length);
  if (choice == DeleteChoice.cancel) return;

  await ref.read(operationControllerProvider.notifier).runDelete(
        entries: entries,
        toTrash: choice == DeleteChoice.trash,
        ftpSessions: ref.read(ftpSessionManagerProvider.notifier),
        sftpSessions: ref.read(sftpSessionManagerProvider.notifier),
        webdavSessions: ref.read(webdavSessionManagerProvider.notifier),
      );
  await ref.read(paneControllerProvider(side).notifier).refresh();
}

Future<void> createFolder(BuildContext context, WidgetRef ref, PaneSide side) async {
  final l10n = AppLocalizations.of(context);
  final name = await promptForName(context, title: l10n.newFolderTitle, confirmLabel: l10n.createLabel);
  if (name == null || name.isEmpty) return;
  if (!context.mounted) return;

  final parentDir = ref.read(paneControllerProvider(side)).currentPath;
  try {
    if (isFtpPath(parentDir)) {
      final ftpSessions = ref.read(ftpSessionManagerProvider.notifier);
      await FtpTransferService(ftpSessions)
          .createFolder(parentDir: Uri.parse(parentDir), name: name);
    } else if (isSftpPath(parentDir)) {
      final sftpSessions = ref.read(sftpSessionManagerProvider.notifier);
      await SftpTransferService(sftpSessions)
          .createFolder(parentDir: Uri.parse(parentDir), name: name);
    } else if (isWebdavPath(parentDir)) {
      final webdavSessions = ref.read(webdavSessionManagerProvider.notifier);
      await WebdavTransferService(webdavSessions)
          .createFolder(parentDir: Uri.parse(parentDir), name: name);
    } else {
      await _fileOps.createFolder(parentDir: parentDir, name: name);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    return;
  }
  await ref.read(paneControllerProvider(side).notifier).refresh();
}

Future<void> createFile(BuildContext context, WidgetRef ref, PaneSide side) async {
  final l10n = AppLocalizations.of(context);
  final name = await promptForName(context, title: l10n.newFileTitle, confirmLabel: l10n.createLabel);
  if (name == null || name.isEmpty) return;
  if (!context.mounted) return;

  final parentDir = ref.read(paneControllerProvider(side)).currentPath;
  try {
    if (isFtpPath(parentDir)) {
      final ftpSessions = ref.read(ftpSessionManagerProvider.notifier);
      await FtpTransferService(ftpSessions)
          .createFile(parentDir: Uri.parse(parentDir), name: name);
    } else if (isSftpPath(parentDir)) {
      final sftpSessions = ref.read(sftpSessionManagerProvider.notifier);
      await SftpTransferService(sftpSessions)
          .createFile(parentDir: Uri.parse(parentDir), name: name);
    } else if (isWebdavPath(parentDir)) {
      final webdavSessions = ref.read(webdavSessionManagerProvider.notifier);
      await WebdavTransferService(webdavSessions)
          .createFile(parentDir: Uri.parse(parentDir), name: name);
    } else {
      await _fileOps.createFile(parentDir: parentDir, name: name);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    return;
  }
  await ref.read(paneControllerProvider(side).notifier).refresh();
}

Future<void> renameSelected(BuildContext context, WidgetRef ref, PaneSide side) async {
  final pane = ref.read(paneControllerProvider(side));
  final selected = pane.selectedEntries;
  if (selected.length != 1) return;
  final entry = selected.first;

  final l10n = AppLocalizations.of(context);
  final newName = await promptForName(
    context,
    title: l10n.renameTitle,
    initialValue: entry.name,
    confirmLabel: l10n.renameLabel,
  );
  if (newName == null || newName.isEmpty || newName == entry.name) return;
  if (!context.mounted) return;

  try {
    switch (entry.location.scheme) {
      case 'ftp':
        final ftpSessions = ref.read(ftpSessionManagerProvider.notifier);
        await FtpTransferService(ftpSessions).rename(location: entry.location, newName: newName);
      case 'sftp':
        final sftpSessions = ref.read(sftpSessionManagerProvider.notifier);
        await SftpTransferService(sftpSessions).rename(location: entry.location, newName: newName);
      case 'webdav':
      case 'webdavs':
        final webdavSessions = ref.read(webdavSessionManagerProvider.notifier);
        await WebdavTransferService(webdavSessions)
            .rename(location: entry.location, newName: newName);
      default:
        await _fileOps.rename(path: entry.location.toFilePath(), newName: newName);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    return;
  }
  await ref.read(paneControllerProvider(side).notifier).refresh();
}

Future<void> toggleBookmark(WidgetRef ref, PaneSide side) async {
  final path = ref.read(paneControllerProvider(side)).currentPath;
  await ref.read(bookmarksProvider.notifier).toggle(path);
}

/// [entry]를 열 때 쓸 로컬 경로를 얻는다. 원격 항목(FTP/SFTP/WebDAV)은 임시
/// 폴더로 내려받고, 로컬 항목은 그 경로를 그대로 돌려준다. 내장 뷰어(F3)와
/// OS 기본 앱 열기 둘 다 이 경로 하나만 있으면 되므로 공용으로 뺐다.
Future<String?> _resolveLocalPath(
  BuildContext context,
  WidgetRef ref,
  FileEntry entry,
) async {
  final scheme = entry.location.scheme;
  if (scheme == 'file') {
    return entry.location.toFilePath();
  }

  if (scheme == 'ftp') {
    final client = ref.read(ftpSessionManagerProvider.notifier).clientForUri(entry.location);
    if (client == null) return null;
    final tempDir = await Directory.systemTemp.createTemp('daylight_commander_view_');
    final tempFile = File(p.join(tempDir.path, entry.name));
    final remoteDir = p.posix.dirname(entry.location.path);
    await client.changeDirectory(remoteDir.isEmpty ? '/' : remoteDir);
    final ok = await client.downloadFile(entry.name, tempFile);
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).downloadFailed)),
        );
      }
      return null;
    }
    return tempFile.path;
  }

  if (scheme == 'sftp') {
    final client = ref.read(sftpSessionManagerProvider.notifier).clientForUri(entry.location);
    if (client == null) return null;
    final tempDir = await Directory.systemTemp.createTemp('daylight_commander_view_');
    final tempFile = File(p.join(tempDir.path, entry.name));
    final handle = await client.open(entry.location.path);
    try {
      final sink = tempFile.openWrite();
      await handle.downloadTo(sink);
      await sink.close();
    } finally {
      await handle.close();
    }
    return tempFile.path;
  }

  // webdav / webdavs
  final client = ref.read(webdavSessionManagerProvider.notifier).clientForUri(entry.location);
  if (client == null) return null;
  final tempDir = await Directory.systemTemp.createTemp('daylight_commander_view_');
  final tempFile = File(p.join(tempDir.path, entry.name));
  await client.read2File(entry.location.path, tempFile.path);
  return tempFile.path;
}

/// F3 보기. FTP 파일은 임시 폴더로 내려받은 뒤 같은 뷰어로 연다.
Future<void> viewSelected(BuildContext context, WidgetRef ref, PaneSide side) async {
  final entries = ref.read(paneControllerProvider(side)).selectedEntries;
  final viewable = entries.where((e) => !e.isDirectory).toList();
  if (viewable.length != 1) return;
  final entry = viewable.first;

  final path = await _resolveLocalPath(context, ref, entry);
  if (path == null || !context.mounted) return;

  if (entry.name.toLowerCase().endsWith('.zip')) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchiveViewerScreen(zipPath: path, archiveName: entry.name),
      ),
    );
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ViewerScreen(path: path, name: entry.name),
    ),
  );
}

/// Finder/탐색기처럼 OS가 확장자에 연결해 둔 기본 앱으로 [entry]를 연다.
/// 더블클릭과 컨텍스트 메뉴 둘 다 여기로 온다.
Future<void> openEntryWithDefaultApp(
  BuildContext context,
  WidgetRef ref,
  FileEntry entry,
) async {
  final path = await _resolveLocalPath(context, ref, entry);
  if (path == null) return;
  await _openWithDefaultApp(path);
}

/// 선택한 항목 중 첫 번째를 OS 파일 관리자(Finder/탐색기)에서 부모 폴더 안에
/// 선택된 상태로 연다. 앱 안에서 파일 목록 밖으로 직접 드래그 아웃하는 대신,
/// 실제 OS 파일 관리자로 보내 거기서 드래그하게 하는 우회 수단이다. 원격
/// 항목은 로컬 경로가 없어 지원하지 않는다.
Future<void> revealSelectedInFileManager(WidgetRef ref, PaneSide side) async {
  final entries = ref.read(paneControllerProvider(side)).selectedEntries;
  if (entries.isEmpty) return;
  final target = entries.first;
  if (target.location.scheme != 'file') return;
  await _revealInFileManager(target.location.toFilePath());
}

/// Ctrl+C. 선택한 로컬 항목들을 OS 클립보드에 "복사한 파일"로 올려서
/// 탐색기/Finder에서 Ctrl+V로 실제 붙여넣기할 수 있게 한다 — 앱 안에서
/// 밖으로 드래그 아웃하는 기능이 없는 동안의 우회 수단. 원격 항목은 실제
/// 로컬 경로가 없어 건너뛴다.
Future<void> copySelectionToOsClipboard(
  BuildContext context,
  WidgetRef ref,
  PaneSide side,
) async {
  final entries = ref.read(paneControllerProvider(side)).selectedEntries;
  final localPaths = entries
      .where((e) => e.location.scheme == 'file')
      .map((e) => e.location.toFilePath())
      .toList();
  if (localPaths.isEmpty) {
    if (entries.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).networkClipboardUnsupported)),
      );
    }
    return;
  }
  await _clipboardFiles.writeFiles(localPaths);
}

/// Ctrl+V. OS 클립보드에 탐색기/Finder에서 Ctrl+C로 복사해 둔 파일이 있으면
/// 현재 패널 위치로 복사한다. 클립보드에 파일이 없으면(텍스트만 있거나
/// 비어 있으면) 조용히 아무것도 하지 않는다.
Future<void> pasteFromOsClipboard(BuildContext context, WidgetRef ref, PaneSide side) async {
  final paths = await _clipboardFiles.readFiles();
  if (paths.isEmpty || !context.mounted) return;

  final entries = <FileEntry>[];
  for (final path in paths) {
    try {
      entries.add(await localFileEntryFor(path));
    } catch (_) {
      // 접근할 수 없거나 이미 사라진 항목은 조용히 건너뛴다.
    }
  }
  if (entries.isEmpty || !context.mounted) return;

  final destinationDir = ref.read(paneControllerProvider(side)).currentPath;
  await transferEntries(
    context,
    ref,
    fromSide: side,
    entries: entries,
    destinationDir: destinationDir,
    isMove: false,
  );
}

Future<void> compressSelection(BuildContext context, WidgetRef ref, PaneSide side) async {
  final pane = ref.read(paneControllerProvider(side));
  final entries = pane.selectedEntries;
  if (entries.isEmpty) return;
  final l10n = AppLocalizations.of(context);
  if (entries.any((e) => e.location.scheme != 'file')) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.networkCompressUnsupported)),
    );
    return;
  }

  final defaultName = entries.length == 1 ? '${entries.first.name}.zip' : 'archive.zip';
  final name = await promptForName(
    context,
    title: l10n.compressLabel,
    initialValue: defaultName,
    confirmLabel: l10n.compressLabel,
  );
  if (name == null || name.isEmpty) return;
  if (!context.mounted) return;

  final zipName = name.toLowerCase().endsWith('.zip') ? name : '$name.zip';
  final zipPath = p.join(pane.currentPath, zipName);

  try {
    await _archiveService.compressToZip(sources: entries, zipPath: zipPath);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).compressFailed('$e'))));
    return;
  }
  await ref.read(paneControllerProvider(side).notifier).refresh();
}

Future<void> extractSelection(BuildContext context, WidgetRef ref, PaneSide side) async {
  final pane = ref.read(paneControllerProvider(side));
  final entries = pane.selectedEntries;
  if (entries.length != 1) return;
  final entry = entries.first;
  if (entry.location.scheme != 'file' ||
      entry.isDirectory ||
      !entry.name.toLowerCase().endsWith('.zip')) {
    return;
  }

  final zipPath = entry.location.toFilePath();
  final destDir = p.join(pane.currentPath, p.basenameWithoutExtension(entry.name));

  try {
    await _archiveService.extractZip(zipPath: zipPath, destinationDir: destDir);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).extractFailed('$e'))));
    return;
  }
  await ref.read(paneControllerProvider(side).notifier).refresh();
}

Future<void> connectSmbServer(BuildContext context, WidgetRef ref) async {
  final request = await showSmbConnectDialog(context);
  if (request == null || request.host.isEmpty) return;
  await _connectNetworkDrive(host: request.host, share: request.share);
  if (request.save) {
    await ref.read(networkProfilesProvider.notifier).add(request.host, request.share);
  }
}

/// FTP 서버에 연결하고, 성공하면 [side] 패널을 그 서버의 루트로 이동시킨다.
Future<void> connectFtpServer(BuildContext context, WidgetRef ref, PaneSide side) async {
  final request = await showFtpConnectDialog(context);
  if (request == null || request.host.isEmpty) return;
  if (!context.mounted) return;

  final ftpSessions = ref.read(ftpSessionManagerProvider.notifier);
  try {
    await ftpSessions.connect(
      host: request.host,
      port: request.port,
      username: request.username,
      password: request.password,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    return;
  }

  if (request.save) {
    await ref.read(ftpProfilesProvider.notifier).add(
          FtpProfile(host: request.host, port: request.port, username: request.username),
        );
  }

  final rootUri = Uri(
    scheme: 'ftp',
    userInfo: request.username,
    host: request.host,
    port: request.port,
    path: '/',
  );
  await ref.read(paneControllerProvider(side).notifier).navigateTo(rootUri.toString());
}

/// SFTP 서버에 연결하고, 성공하면 [side] 패널을 사용자 홈 디렉터리로 이동시킨다
/// (FTP와 달리 SFTP는 로그인 계정의 홈이 자연스러운 시작 위치).
Future<void> connectSftpServer(BuildContext context, WidgetRef ref, PaneSide side) async {
  final request = await showSftpConnectDialog(context);
  if (request == null || request.host.isEmpty) return;
  if (!context.mounted) return;

  final sftpSessions = ref.read(sftpSessionManagerProvider.notifier);
  try {
    await sftpSessions.connect(
      host: request.host,
      port: request.port,
      username: request.username,
      password: request.password,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    return;
  }

  if (request.save) {
    await ref.read(sftpProfilesProvider.notifier).add(
          SftpProfile(host: request.host, port: request.port, username: request.username),
        );
  }

  final rootUri = Uri(
    scheme: 'sftp',
    userInfo: request.username,
    host: request.host,
    port: request.port,
    path: '/',
  );
  await ref.read(paneControllerProvider(side).notifier).navigateTo(rootUri.toString());
}

/// WebDAV 서버에 연결하고, 성공하면 [side] 패널을 그 서버의 루트로 이동시킨다.
Future<void> connectWebdavServer(BuildContext context, WidgetRef ref, PaneSide side) async {
  final request = await showWebdavConnectDialog(context);
  if (request == null || request.host.isEmpty) return;
  if (!context.mounted) return;

  final webdavSessions = ref.read(webdavSessionManagerProvider.notifier);
  try {
    await webdavSessions.connect(
      host: request.host,
      port: request.port,
      username: request.username,
      password: request.password,
      secure: request.useHttps,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    return;
  }

  if (request.save) {
    await ref.read(webdavProfilesProvider.notifier).add(
          WebdavProfile(
            host: request.host,
            port: request.port,
            username: request.username,
            useHttps: request.useHttps,
          ),
        );
  }

  final rootUri = Uri(
    scheme: request.useHttps ? 'webdavs' : 'webdav',
    userInfo: request.username,
    host: request.host,
    port: request.port,
    path: '/',
  );
  await ref.read(paneControllerProvider(side).notifier).navigateTo(rootUri.toString());
}

/// 현재 패널이 원격 위치(FTP/SFTP/WebDAV)일 때 그 세션 연결을 끊고 홈
/// 디렉터리로 되돌린다. 어떤 프로토콜이든 경로 문자열만 보고 알아서
/// 갈라진다 — 패스바에는 통합된 "연결 해제" 버튼 하나만 있으면 된다.
Future<void> disconnectRemote(WidgetRef ref, PaneSide side) async {
  final path = ref.read(paneControllerProvider(side)).currentPath;
  if (isFtpPath(path)) {
    final key = FtpSessionManager.keyForUri(Uri.parse(path));
    await ref.read(ftpSessionManagerProvider.notifier).disconnect(key);
  } else if (isSftpPath(path)) {
    final key = SftpSessionManager.keyForUri(Uri.parse(path));
    await ref.read(sftpSessionManagerProvider.notifier).disconnect(key);
  } else if (isWebdavPath(path)) {
    final key = WebdavSessionManager.keyForUri(Uri.parse(path));
    await ref.read(webdavSessionManagerProvider.notifier).disconnect(key);
  } else {
    return;
  }
  await ref.read(paneControllerProvider(side).notifier).navigateTo(homeDirectory());
}

Future<void> showProperties(BuildContext context, WidgetRef ref, PaneSide side) async {
  final selected = ref.read(paneControllerProvider(side)).selectedEntries;
  if (selected.length != 1) return;
  if (selected.first.location.scheme != 'file') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).networkPropertiesUnsupported)),
    );
    return;
  }
  await showPropertiesDialog(context, selected.first);
}

Future<void> selectByPattern(BuildContext context, WidgetRef ref, PaneSide side) async {
  final result = await showPatternSelectDialog(context);
  if (result == null || result.pattern.isEmpty) return;
  ref.read(paneControllerProvider(side).notifier).selectByPattern(result.pattern, add: result.add);
}

/// 우클릭 컨텍스트 메뉴.
///
/// 우클릭한 항목이 이미 다중선택(2개 이상)에 속해 있으면 그 다중선택 전체를
/// 대상으로 삼고, 아니면 그 항목 하나로 선택을 바꾼 뒤 메뉴를 띄운다 — OS
/// 탐색기들의 일반적인 관례. 메뉴 항목을 고르면 F5/F6/F8 등과 동일한 기존
/// 액션 함수를 그대로 재사용한다(둘 다 `pane.selectedEntries`를 읽으므로).
Future<void> showRowContextMenu(
  BuildContext context,
  WidgetRef ref, {
  required PaneSide side,
  required FileEntry entry,
  required int index,
  required Offset globalPosition,
}) async {
  ref.read(activePaneProvider.notifier).state = side;

  final controller = ref.read(paneControllerProvider(side).notifier);
  final currentSelection = ref.read(paneControllerProvider(side)).selection;
  final isPartOfMultiSelect =
      currentSelection.contains(entry.location) && currentSelection.length > 1;
  if (!isPartOfMultiSelect) {
    controller.selectOnly(index);
  }

  final targets = ref.read(paneControllerProvider(side)).selectedEntries;
  if (targets.isEmpty || !context.mounted) return;

  final allLocal = targets.every((e) => e.location.scheme == 'file');
  final singleTarget = targets.length == 1 ? targets.first : null;
  final canView = singleTarget != null && !singleTarget.isDirectory;
  final canOpen = singleTarget != null && singleTarget.isDirectory;
  final canExtract = singleTarget != null &&
      allLocal &&
      !singleTarget.isDirectory &&
      singleTarget.name.toLowerCase().endsWith('.zip');
  final canBookmark = singleTarget != null && singleTarget.isDirectory;

  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final position = RelativeRect.fromRect(
    globalPosition & const Size(1, 1),
    Offset.zero & overlay.size,
  );
  final l10n = AppLocalizations.of(context);

  final action = await showMenu<String>(
    context: context,
    position: position,
    items: [
      if (canOpen) PopupMenuItem(value: 'open', child: Text(l10n.contextMenuOpen)),
      if (canView)
        PopupMenuItem(value: 'open_with_default', child: Text(l10n.contextMenuOpenWithDefault)),
      if (canView) PopupMenuItem(value: 'view', child: Text(l10n.contextMenuView)),
      if (singleTarget != null)
        PopupMenuItem(value: 'rename', child: Text(l10n.contextMenuRename)),
      PopupMenuItem(value: 'copy', child: Text(l10n.contextMenuCopy)),
      PopupMenuItem(value: 'move', child: Text(l10n.contextMenuMove)),
      PopupMenuItem(value: 'delete', child: Text(l10n.contextMenuDelete)),
      if (allLocal) PopupMenuItem(value: 'compress', child: Text(l10n.compressLabel)),
      if (canExtract) PopupMenuItem(value: 'extract', child: Text(l10n.extractLabel)),
      if (singleTarget != null && allLocal)
        PopupMenuItem(value: 'properties', child: Text(l10n.propertiesTitle)),
      if (canBookmark) PopupMenuItem(value: 'bookmark', child: Text(l10n.addBookmarkTooltip)),
      if (allLocal)
        PopupMenuItem(
          value: 'reveal_in_file_manager',
          child: Text(l10n.contextMenuRevealInFileManager),
        ),
    ],
  );

  if (action == null || !context.mounted) return;
  switch (action) {
    case 'open':
      controller.openEntry(singleTarget!);
    case 'open_with_default':
      await openEntryWithDefaultApp(context, ref, singleTarget!);
    case 'view':
      await viewSelected(context, ref, side);
    case 'rename':
      await renameSelected(context, ref, side);
    case 'copy':
      await copySelectionToOtherPane(context, ref, side);
    case 'move':
      await moveSelectionToOtherPane(context, ref, side);
    case 'delete':
      await deleteSelection(context, ref, side);
    case 'compress':
      await compressSelection(context, ref, side);
    case 'extract':
      await extractSelection(context, ref, side);
    case 'properties':
      await showProperties(context, ref, side);
    case 'bookmark':
      await ref
          .read(bookmarksProvider.notifier)
          .toggle(locationToPathString(singleTarget!.location));
    case 'reveal_in_file_manager':
      await revealSelectedInFileManager(ref, side);
  }
}

/// Finder/탐색기 등 OS에서 드래그해 패널에 드롭한 로컬 경로들을 그 패널의
/// 현재 위치로 복사한다 (항상 복사 — OS 밖에서 온 항목을 옮기면서 원본까지
/// 지우는 건 위험하므로 이동은 지원하지 않는다). 목적지가 FTP 패널이면
/// 업로드로 자연스럽게 이어진다(스킴 기반 라우팅은 [transferEntries]가 처리).
Future<void> dropExternalFiles(
  BuildContext context,
  WidgetRef ref,
  PaneSide side,
  List<String> paths,
) async {
  // 이 앱이 끌어낸 드래그가 창 안으로 되돌아온 것이면 외부 드롭이 아니다.
  if (paths.isEmpty || FlutterDragOut.inProgress) return;

  final entries = <FileEntry>[];
  for (final path in paths) {
    try {
      entries.add(await localFileEntryFor(path));
    } catch (_) {
      // 접근할 수 없거나 이미 사라진 항목은 조용히 건너뛴다.
    }
  }
  if (entries.isEmpty || !context.mounted) return;

  final destinationDir = ref.read(paneControllerProvider(side)).currentPath;
  await transferEntries(
    context,
    ref,
    fromSide: side,
    entries: entries,
    destinationDir: destinationDir,
    isMove: false,
  );
}
