import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:daylight_commander/application/ftp_session_manager.dart';
import 'package:daylight_commander/application/ftp_transfer_service.dart';
import 'package:daylight_commander/application/usecases/list_ftp_directory.dart';
import 'package:daylight_commander/domain/entities/file_conflict.dart';
import 'package:daylight_commander/domain/entities/file_entry.dart';

/// 실제 로컬 FTP 서버(파이썬 pyftpdlib)를 띄워 우리 FTP 클라이언트 코드를
/// 검증한다. SMB는 OS에 위임해서 우리가 프로토콜을 구현하지 않지만, FTP는
/// 이 앱이 직접 클라이언트를 구현하므로 실제 서버 없이는 신뢰하기 어렵다.
///
/// `python3 -m pyftpdlib`이 없으면(이 리포지토리 개발 환경에만 설치됨) 스킵한다.
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
    serverRoot = await Directory.systemTemp.createTemp('daylight_commander_ftpserver_');
    localTemp = await Directory.systemTemp.createTemp('daylight_commander_ftpclient_');
    port = await _findFreePort();

    try {
      serverProcess = await Process.start('python3', [
        '-m',
        'pyftpdlib',
        '-i',
        host,
        '-p',
        '$port',
        '-u',
        username,
        '-P',
        password,
        '-w',
        '-d',
        serverRoot.path,
      ]);
      unawaited(serverProcess.stdout.drain());
      unawaited(serverProcess.stderr.drain());

      serverAvailable = false;
      for (var i = 0; i < 50; i++) {
        try {
          final socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 200));
          await socket.close();
          serverAvailable = true;
          break;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (_) {
      serverAvailable = false;
    }
  });

  tearDownAll(() async {
    if (serverAvailable) serverProcess.kill();
    if (await serverRoot.exists()) await serverRoot.delete(recursive: true);
    if (await localTemp.exists()) await localTemp.delete(recursive: true);
  });

  late FtpSessionManager sessions;
  late Uri rootUri;

  setUp(() async {
    if (!serverAvailable) return;
    sessions = FtpSessionManager();
    await sessions.connect(host: host, port: port, username: username, password: password);
    rootUri = Uri(scheme: 'ftp', userInfo: username, host: host, port: port, path: '/');
  });

  test(
    '목록: 서버에 미리 만들어둔 파일이 보인다',
    () async {
      File(p.join(serverRoot.path, 'hello.txt')).writeAsStringSync('hi');

      final entries = await ListFtpDirectory(sessions)(rootUri);

      expect(entries.map((e) => e.name), contains('hello.txt'));
      expect(entries.firstWhere((e) => e.name == 'hello.txt').source, FileSourceType.ftp);
    },
    skip: !_pyftpdlibAvailable ? 'pyftpdlib 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '업로드: 로컬 파일을 올리면 서버 디스크에 나타나고 원본은 남는다',
    () async {
      final localFile = File(p.join(localTemp.path, 'upload.txt'))
        ..writeAsStringSync('업로드 테스트');
      final entry =
          FileEntry(location: Uri.file(localFile.path), name: 'upload.txt', isDirectory: false);

      await FtpTransferService(sessions).upload(
        sources: [entry],
        destinationDir: rootUri,
        deleteSourceAfter: false,
        onConflict: _neverAsk,
      );

      expect(File(p.join(serverRoot.path, 'upload.txt')).readAsStringSync(), '업로드 테스트');
      expect(localFile.existsSync(), isTrue, reason: '복사는 원본을 남겨야 한다');
    },
    skip: !_pyftpdlibAvailable ? 'pyftpdlib 미설치 — 로컬 통합 테스트 스킵' : false,
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

      await FtpTransferService(sessions).download(
        sources: [entry],
        destinationDir: localTemp.path,
        deleteSourceAfter: false,
        onConflict: _neverAsk,
      );

      expect(File(p.join(localTemp.path, 'download.txt')).readAsStringSync(), '다운로드 테스트');
    },
    skip: !_pyftpdlibAvailable ? 'pyftpdlib 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '새 폴더 생성',
    () async {
      await FtpTransferService(sessions).createFolder(parentDir: rootUri, name: 'newdir');
      expect(Directory(p.join(serverRoot.path, 'newdir')).existsSync(), isTrue);
    },
    skip: !_pyftpdlibAvailable ? 'pyftpdlib 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '새 파일 생성',
    () async {
      await FtpTransferService(sessions).createFile(parentDir: rootUri, name: 'newfile.txt');
      final file = File(p.join(serverRoot.path, 'newfile.txt'));
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), 0);
    },
    skip: !_pyftpdlibAvailable ? 'pyftpdlib 미설치 — 로컬 통합 테스트 스킵' : false,
  );

  test(
    '이름 변경',
    () async {
      File(p.join(serverRoot.path, 'old_name.txt')).writeAsStringSync('x');

      await FtpTransferService(sessions).rename(
        location: rootUri.replace(path: '/old_name.txt'),
        newName: 'new_name.txt',
      );

      expect(File(p.join(serverRoot.path, 'new_name.txt')).existsSync(), isTrue);
      expect(File(p.join(serverRoot.path, 'old_name.txt')).existsSync(), isFalse);
    },
    skip: !_pyftpdlibAvailable ? 'pyftpdlib 미설치 — 로컬 통합 테스트 스킵' : false,
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

      await FtpTransferService(sessions).deleteEntry(entry);

      expect(File(p.join(serverRoot.path, 'to_delete.txt')).existsSync(), isFalse);
    },
    skip: !_pyftpdlibAvailable ? 'pyftpdlib 미설치 — 로컬 통합 테스트 스킵' : false,
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

      await FtpTransferService(sessions).upload(
        sources: [entry],
        destinationDir: rootUri,
        deleteSourceAfter: false,
        onConflict: (c) async => ConflictAction.overwrite,
      );

      expect(File(p.join(serverRoot.path, 'conflict.txt')).readAsStringSync(), 'new');
    },
    skip: !_pyftpdlibAvailable ? 'pyftpdlib 미설치 — 로컬 통합 테스트 스킵' : false,
  );
}

bool get _pyftpdlibAvailable {
  try {
    final result = Process.runSync('python3', ['-c', 'import pyftpdlib']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
