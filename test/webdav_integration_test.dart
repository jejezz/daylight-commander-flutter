import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:daylight_commander/application/usecases/list_webdav_directory.dart';
import 'package:daylight_commander/application/webdav_session_manager.dart';
import 'package:daylight_commander/application/webdav_transfer_service.dart';
import 'package:daylight_commander/domain/entities/file_conflict.dart';
import 'package:daylight_commander/domain/entities/file_entry.dart';

/// 실제 로컬 WebDAV 서버(파이썬 wsgidav, `test/support/webdav_test_server.py`)를
/// 띄워 우리 WebDAV 클라이언트 코드를 검증한다. [ftp_integration_test.dart]와
/// 같은 이유.
///
/// `python3 -c "import wsgidav, cheroot"`가 없으면(이 리포지토리 개발 환경에만
/// 설치됨) 스킵한다.
Future<int> _findFreePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<ConflictAction> _neverAsk(FileConflict c) async =>
    throw StateError('충돌이 예상되지 않았는데 발생함: ${c.destinationPath}');

void main() {
  const host = '127.0.0.1';
  const username = 'tester';
  const password = 'testpass';

  late Directory serverRoot;
  late Directory localTemp;
  late Process serverProcess;
  late int port;
  late bool serverAvailable;

  setUpAll(() async {
    serverRoot = await Directory.systemTemp.createTemp('daylight_commander_webdavserver_');
    localTemp = await Directory.systemTemp.createTemp('daylight_commander_webdavclient_');
    port = await _findFreePort();

    try {
      final scriptPath =
          p.join(Directory.current.path, 'test', 'support', 'webdav_test_server.py');
      serverProcess = await Process.start('python3', [
        scriptPath,
        host,
        '$port',
        serverRoot.path,
        username,
        password,
      ]);
      unawaited(serverProcess.stderr.drain());

      final ready = Completer<void>();
      serverProcess.stdout.transform(const SystemEncoding().decoder).listen((line) {
        if (line.contains('READY') && !ready.isCompleted) ready.complete();
      });
      await ready.future.timeout(const Duration(seconds: 10));
      serverAvailable = true;
    } catch (_) {
      serverAvailable = false;
    }
  });

  tearDownAll(() async {
    if (serverAvailable) serverProcess.kill();
    if (await serverRoot.exists()) await serverRoot.delete(recursive: true);
    if (await localTemp.exists()) await localTemp.delete(recursive: true);
  });

  late WebdavSessionManager sessions;
  late Uri rootUri;

  setUp(() async {
    if (!serverAvailable) return;
    sessions = WebdavSessionManager();
    await sessions.connect(
      host: host,
      port: port,
      username: username,
      password: password,
      secure: false,
    );
    rootUri = Uri(scheme: 'webdav', userInfo: username, host: host, port: port, path: '/');
  });

  test(
    '목록: 서버에 미리 만들어둔 파일이 보인다',
    () async {
      File(p.join(serverRoot.path, 'hello.txt')).writeAsStringSync('hi');

      final entries = await ListWebdavDirectory(sessions)(rootUri);

      expect(entries.map((e) => e.name), contains('hello.txt'));
      expect(entries.firstWhere((e) => e.name == 'hello.txt').source, FileSourceType.webdav);
    },
    skip: !_webdavServerAvailable ? 'wsgidav 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '업로드: 로컬 파일을 올리면 서버 디스크에 나타나고 원본은 남는다',
    () async {
      final localFile = File(p.join(localTemp.path, 'upload.txt'))
        ..writeAsStringSync('업로드 테스트');
      final entry =
          FileEntry(location: Uri.file(localFile.path), name: 'upload.txt', isDirectory: false);

      await WebdavTransferService(sessions).upload(
        sources: [entry],
        destinationDir: rootUri,
        deleteSourceAfter: false,
        onConflict: _neverAsk,
      );

      expect(File(p.join(serverRoot.path, 'upload.txt')).readAsStringSync(), '업로드 테스트');
      expect(localFile.existsSync(), isTrue, reason: '복사는 원본을 남겨야 한다');
    },
    skip: !_webdavServerAvailable ? 'wsgidav 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '다운로드: 서버 파일을 받으면 로컬에 저장된다',
    () async {
      File(p.join(serverRoot.path, 'download.txt')).writeAsStringSync('다운로드 테스트');
      final entry = FileEntry(
        location: rootUri.replace(path: '/download.txt'),
        name: 'download.txt',
        isDirectory: false,
      );

      await WebdavTransferService(sessions).download(
        sources: [entry],
        destinationDir: localTemp.path,
        deleteSourceAfter: false,
        onConflict: _neverAsk,
      );

      expect(File(p.join(localTemp.path, 'download.txt')).readAsStringSync(), '다운로드 테스트');
    },
    skip: !_webdavServerAvailable ? 'wsgidav 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '새 폴더 생성',
    () async {
      await WebdavTransferService(sessions).createFolder(parentDir: rootUri, name: 'newdir');
      expect(Directory(p.join(serverRoot.path, 'newdir')).existsSync(), isTrue);
    },
    skip: !_webdavServerAvailable ? 'wsgidav 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '이름 변경',
    () async {
      File(p.join(serverRoot.path, 'old_name.txt')).writeAsStringSync('x');

      await WebdavTransferService(sessions).rename(
        location: rootUri.replace(path: '/old_name.txt'),
        newName: 'new_name.txt',
      );

      expect(File(p.join(serverRoot.path, 'new_name.txt')).existsSync(), isTrue);
      expect(File(p.join(serverRoot.path, 'old_name.txt')).existsSync(), isFalse);
    },
    skip: !_webdavServerAvailable ? 'wsgidav 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '삭제',
    () async {
      File(p.join(serverRoot.path, 'to_delete.txt')).writeAsStringSync('x');
      final entry = FileEntry(
        location: rootUri.replace(path: '/to_delete.txt'),
        name: 'to_delete.txt',
        isDirectory: false,
      );

      await WebdavTransferService(sessions).deleteEntry(entry);

      expect(File(p.join(serverRoot.path, 'to_delete.txt')).existsSync(), isFalse);
    },
    skip: !_webdavServerAvailable ? 'wsgidav 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '업로드 충돌: overwrite를 선택하면 서버 파일이 교체된다',
    () async {
      File(p.join(serverRoot.path, 'conflict.txt')).writeAsStringSync('old');
      final localFile = File(p.join(localTemp.path, 'conflict.txt'))..writeAsStringSync('new');
      final entry = FileEntry(
        location: Uri.file(localFile.path),
        name: 'conflict.txt',
        isDirectory: false,
      );

      await WebdavTransferService(sessions).upload(
        sources: [entry],
        destinationDir: rootUri,
        deleteSourceAfter: false,
        onConflict: (c) async => ConflictAction.overwrite,
      );

      expect(File(p.join(serverRoot.path, 'conflict.txt')).readAsStringSync(), 'new');
    },
    skip: !_webdavServerAvailable ? 'wsgidav 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '폴더 통째 업로드: 하위 파일까지 재귀적으로 올라간다',
    () async {
      final dir = Directory(p.join(localTemp.path, 'folder'))..createSync();
      File(p.join(dir.path, 'inner.txt')).writeAsStringSync('inner');
      final entry = FileEntry(location: Uri.file(dir.path), name: 'folder', isDirectory: true);

      await WebdavTransferService(sessions).upload(
        sources: [entry],
        destinationDir: rootUri,
        deleteSourceAfter: false,
        onConflict: _neverAsk,
      );

      expect(
        File(p.join(serverRoot.path, 'folder', 'inner.txt')).readAsStringSync(),
        'inner',
      );
    },
    skip: !_webdavServerAvailable ? 'wsgidav 미설치 — 로컬 통합 테스트 스킵' : false,
  );
}

bool get _webdavServerAvailable {
  try {
    final result = Process.runSync('python3', ['-c', 'import wsgidav, cheroot']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
