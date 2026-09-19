import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bytes_format.dart';
import '../../domain/entities/file_conflict.dart';
import '../home/ftp_profiles_provider.dart';
import '../home/network_profiles_provider.dart';
import '../home/sftp_profiles_provider.dart';
import '../home/webdav_profiles_provider.dart';

/// 새 폴더/이름변경에 쓰는 단일 텍스트 입력 다이얼로그.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String confirmLabel = '확인',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// SMB 서버 연결 정보 입력. 비밀번호는 절대 받지 않는다 — OS가 띄우는 신뢰된
/// 다이얼로그에서 사용자가 직접 입력하게 한다 (ARCHITECTURE.md 4장).
class SmbConnectRequest {
  const SmbConnectRequest({required this.host, required this.share, required this.save});
  final String host;
  final String share;
  final bool save;
}

Future<SmbConnectRequest?> showSmbConnectDialog(BuildContext context) {
  return showDialog<SmbConnectRequest>(
    context: context,
    builder: (context) => const _SmbConnectDialog(),
  );
}

class _SmbConnectDialog extends ConsumerStatefulWidget {
  const _SmbConnectDialog();

  @override
  ConsumerState<_SmbConnectDialog> createState() => _SmbConnectDialogState();
}

class _SmbConnectDialogState extends ConsumerState<_SmbConnectDialog> {
  final _hostController = TextEditingController();
  final _shareController = TextEditingController();
  bool _save = false;

  @override
  void dispose() {
    _hostController.dispose();
    _shareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(networkProfilesProvider);
    return AlertDialog(
      title: const Text('네트워크 드라이브 연결 (SMB)'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profiles.isNotEmpty) ...[
              const Text('저장된 서버', style: TextStyle(fontWeight: FontWeight.w500)),
              for (final profile in profiles)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    profile.share.isEmpty ? profile.host : '${profile.host}/${profile.share}',
                  ),
                  onTap: () {
                    _hostController.text = profile.host;
                    _shareController.text = profile.share;
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () =>
                        ref.read(networkProfilesProvider.notifier).remove(profile),
                  ),
                ),
              const Divider(),
            ],
            TextField(
              controller: _hostController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '호스트 (예: 192.168.0.10)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _shareController,
              decoration: const InputDecoration(labelText: '공유 이름 (선택)'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _save,
              onChanged: (v) => setState(() => _save = v ?? false),
              title: const Text('이 서버 정보 저장 (비밀번호 제외)'),
            ),
            const Text(
              '연결하면 OS의 서버 연결 대화상자가 뜹니다. 비밀번호는 그 대화상자에\n직접 입력하세요 — 이 앱은 자격증명을 저장하거나 다루지 않습니다.',
              style: TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            SmbConnectRequest(
              host: _hostController.text.trim(),
              share: _shareController.text.trim(),
              save: _save,
            ),
          ),
          child: const Text('연결'),
        ),
      ],
    );
  }
}

/// `*`/`?` 와일드카드 패턴으로 선택/선택 해제.
class PatternSelectionResult {
  const PatternSelectionResult({required this.pattern, required this.add});
  final String pattern;
  final bool add;
}

Future<PatternSelectionResult?> showPatternSelectDialog(BuildContext context) {
  final controller = TextEditingController(text: '*.');
  return showDialog<PatternSelectionResult>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('패턴으로 선택'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '예: *.jpg, IMG_*.png'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            PatternSelectionResult(pattern: controller.text.trim(), add: false),
          ),
          child: const Text('선택 해제'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            PatternSelectionResult(pattern: controller.text.trim(), add: true),
          ),
          child: const Text('선택 추가'),
        ),
      ],
    ),
  );
}

/// FTP 서버 연결 정보 입력. SMB와 달리 FTP는 앱이 직접 프로토콜을 구현하므로
/// 비밀번호를 실제로 받아야 하지만, 세션 연결에만 쓰고 어디에도 저장하지
/// 않는다 — "저장" 체크박스는 host/port/username만 남긴다.
class FtpConnectRequest {
  const FtpConnectRequest({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.save,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final bool save;
}

Future<FtpConnectRequest?> showFtpConnectDialog(BuildContext context) {
  return showDialog<FtpConnectRequest>(
    context: context,
    builder: (context) => const _FtpConnectDialog(),
  );
}

class _FtpConnectDialog extends ConsumerStatefulWidget {
  const _FtpConnectDialog();

  @override
  ConsumerState<_FtpConnectDialog> createState() => _FtpConnectDialogState();
}

class _FtpConnectDialogState extends ConsumerState<_FtpConnectDialog> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '21');
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _anonymous = true;
  bool _save = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(ftpProfilesProvider);
    return AlertDialog(
      title: const Text('FTP 서버 연결'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profiles.isNotEmpty) ...[
              const Text('저장된 서버', style: TextStyle(fontWeight: FontWeight.w500)),
              for (final profile in profiles)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${profile.username}@${profile.host}:${profile.port}'),
                  onTap: () {
                    _hostController.text = profile.host;
                    _portController.text = profile.port.toString();
                    _userController.text = profile.username;
                    setState(() => _anonymous = false);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref.read(ftpProfilesProvider.notifier).remove(profile),
                  ),
                ),
              const Divider(),
            ],
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '호스트'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '포트'),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v ?? true),
              title: const Text('익명(anonymous) 로그인'),
            ),
            if (!_anonymous) ...[
              TextField(
                controller: _userController,
                decoration: const InputDecoration(labelText: '사용자명'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호'),
              ),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _save,
              onChanged: (v) => setState(() => _save = v ?? false),
              title: const Text('이 서버 정보 저장 (비밀번호 제외)'),
            ),
            const Text(
              '비밀번호는 이 연결에만 사용되고 저장되지 않습니다.',
              style: TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            FtpConnectRequest(
              host: _hostController.text.trim(),
              port: int.tryParse(_portController.text.trim()) ?? 21,
              username: _anonymous ? 'anonymous' : _userController.text.trim(),
              password: _anonymous ? '' : _passController.text,
              save: _save,
            ),
          ),
          child: const Text('연결'),
        ),
      ],
    );
  }
}

/// SFTP 서버 연결 정보 입력. FTP와 달리 익명 로그인 개념이 없어 사용자명이
/// 항상 필요하다. 비밀번호는 이 연결에만 쓰이고 저장하지 않는다.
class SftpConnectRequest {
  const SftpConnectRequest({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.save,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final bool save;
}

Future<SftpConnectRequest?> showSftpConnectDialog(BuildContext context) {
  return showDialog<SftpConnectRequest>(
    context: context,
    builder: (context) => const _SftpConnectDialog(),
  );
}

class _SftpConnectDialog extends ConsumerStatefulWidget {
  const _SftpConnectDialog();

  @override
  ConsumerState<_SftpConnectDialog> createState() => _SftpConnectDialogState();
}

class _SftpConnectDialogState extends ConsumerState<_SftpConnectDialog> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _save = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(sftpProfilesProvider);
    return AlertDialog(
      title: const Text('SFTP 서버 연결'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profiles.isNotEmpty) ...[
              const Text('저장된 서버', style: TextStyle(fontWeight: FontWeight.w500)),
              for (final profile in profiles)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${profile.username}@${profile.host}:${profile.port}'),
                  onTap: () {
                    _hostController.text = profile.host;
                    _portController.text = profile.port.toString();
                    _userController.text = profile.username;
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref.read(sftpProfilesProvider.notifier).remove(profile),
                  ),
                ),
              const Divider(),
            ],
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '호스트'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '포트'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: '사용자명'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _save,
              onChanged: (v) => setState(() => _save = v ?? false),
              title: const Text('이 서버 정보 저장 (비밀번호 제외)'),
            ),
            const Text(
              '비밀번호는 이 연결에만 사용되고 저장되지 않습니다.',
              style: TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            SftpConnectRequest(
              host: _hostController.text.trim(),
              port: int.tryParse(_portController.text.trim()) ?? 22,
              username: _userController.text.trim(),
              password: _passController.text,
              save: _save,
            ),
          ),
          child: const Text('연결'),
        ),
      ],
    );
  }
}

/// WebDAV 서버 연결 정보 입력. HTTP(S) 기반이라 SMB/FTP와 달리 보안 연결
/// 여부(HTTPS)를 고른다. 비밀번호는 이 연결에만 쓰이고 저장하지 않는다.
class WebdavConnectRequest {
  const WebdavConnectRequest({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.useHttps,
    required this.save,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final bool useHttps;
  final bool save;
}

Future<WebdavConnectRequest?> showWebdavConnectDialog(BuildContext context) {
  return showDialog<WebdavConnectRequest>(
    context: context,
    builder: (context) => const _WebdavConnectDialog(),
  );
}

class _WebdavConnectDialog extends ConsumerStatefulWidget {
  const _WebdavConnectDialog();

  @override
  ConsumerState<_WebdavConnectDialog> createState() => _WebdavConnectDialogState();
}

class _WebdavConnectDialogState extends ConsumerState<_WebdavConnectDialog> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '443');
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _useHttps = true;
  bool _save = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(webdavProfilesProvider);
    return AlertDialog(
      title: const Text('WebDAV 서버 연결'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profiles.isNotEmpty) ...[
              const Text('저장된 서버', style: TextStyle(fontWeight: FontWeight.w500)),
              for (final profile in profiles)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${profile.username}@${profile.host}:${profile.port}'
                    '${profile.useHttps ? " (https)" : " (http)"}',
                  ),
                  onTap: () {
                    _hostController.text = profile.host;
                    _portController.text = profile.port.toString();
                    _userController.text = profile.username;
                    setState(() => _useHttps = profile.useHttps);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref.read(webdavProfilesProvider.notifier).remove(profile),
                  ),
                ),
              const Divider(),
            ],
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '호스트'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '포트'),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _useHttps,
              onChanged: (v) {
                final next = v ?? true;
                setState(() {
                  _useHttps = next;
                  if (_portController.text == '443' || _portController.text == '80') {
                    _portController.text = next ? '443' : '80';
                  }
                });
              },
              title: const Text('HTTPS 사용'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: '사용자명'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _save,
              onChanged: (v) => setState(() => _save = v ?? false),
              title: const Text('이 서버 정보 저장 (비밀번호 제외)'),
            ),
            const Text(
              '비밀번호는 이 연결에만 사용되고 저장되지 않습니다.',
              style: TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            WebdavConnectRequest(
              host: _hostController.text.trim(),
              port: int.tryParse(_portController.text.trim()) ?? (_useHttps ? 443 : 80),
              username: _userController.text.trim(),
              password: _passController.text,
              useHttps: _useHttps,
              save: _save,
            ),
          ),
          child: const Text('연결'),
        ),
      ],
    );
  }
}

enum DeleteChoice { trash, permanent, cancel }

Future<DeleteChoice> showDeleteConfirmDialog(
  BuildContext context, {
  required int count,
}) async {
  final choice = await showDialog<DeleteChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('삭제'),
      content: Text('선택한 $count개 항목을 삭제할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(DeleteChoice.cancel),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(DeleteChoice.permanent),
          child: const Text('영구 삭제'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(DeleteChoice.trash),
          child: const Text('휴지통으로 이동'),
        ),
      ],
    ),
  );
  return choice ?? DeleteChoice.cancel;
}

/// 복사/이동 중 대상 경로에 동일 이름이 있을 때 표시.
Future<ConflictAction> showConflictDialog(
  BuildContext context,
  FileConflict conflict,
) async {
  final action = await showDialog<ConflictAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('같은 이름의 파일이 있습니다'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(conflict.destinationPath, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text('원본: ${formatBytes(conflict.sourceSizeBytes)}'),
          Text('대상: ${formatBytes(conflict.destinationSizeBytes)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.cancel),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.skipAll),
          child: const Text('모두 건너뛰기'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.skip),
          child: const Text('건너뛰기'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.rename),
          child: const Text('이름 바꿔서 복사'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.overwriteAll),
          child: const Text('모두 덮어쓰기'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.overwrite),
          child: const Text('덮어쓰기'),
        ),
      ],
    ),
  );
  return action ?? ConflictAction.cancel;
}
