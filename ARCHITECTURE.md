# Daylight Commander — 아키텍처 설계 (v0.1)

[PLAN.md](PLAN.md)의 기능 리스트(P0/P1/P2)를 기준으로 한 초안 아키텍처. UI 위젯 디테일은 제외하고 상태관리/데이터 흐름/확장 구조에 집중한다.

## 1. 레이어 구조

```
presentation/   화면, 다이얼로그, Riverpod 컨트롤러(StateNotifier/AsyncNotifier)
application/    유스케이스 (CopyFiles, MoveFiles, DeleteFiles, ListDirectory, ConnectDrive ...)
domain/         엔티티(FileEntry, DriveInfo, ConnectionProfile), Repository 인터페이스
data/           Repository 구현체 (Local/Smb/Ftp), 영속성(설정/북마크/자격증명), 플랫폼 채널
core/           OperationQueue, Isolate 유틸, 에러 타입, 공통 확장
```

의존 방향은 `presentation → application → domain ← data` (domain은 다른 레이어를 모른다). `data`는 `domain`의 Repository 인터페이스를 구현한다.

## 2. 상태관리: Riverpod

- 이유: 데스크톱 앱에서 다중 패널·다중 비동기 작업(파일 목록 로딩, 백그라운드 복사)을 다루기에 테스트 가능하고 Provider 단위로 스코프를 나누기 쉬움.
- 주요 Provider 구성 (예시)
  - `paneControllerProvider(PaneSide side)` — 좌/우 패널 각각의 상태(`AsyncNotifier<PaneState>`)
  - `activePaneProvider` — 현재 포커스된 패널 (StateProvider)
  - `operationQueueProvider` — 진행 중인 파일 작업 목록 (StreamProvider/Notifier)
  - `bookmarksProvider`, `connectionProfilesProvider`, `settingsProvider` — 영속 데이터

## 3. 핵심 엔티티

```dart
class FileEntry {
  final Uri location;        // file:///path 또는 smb://host/share/path, ftp://...
  final String name;
  final bool isDirectory;
  final int? sizeBytes;
  final DateTime? modifiedAt;
  final bool isHidden;
  final FileSourceType source; // local, smb, ftp, webdav
}

class PaneState {
  final Uri currentPath;
  final List<FileEntry> entries;
  final Set<Uri> selection;
  final List<Uri> backHistory;
  final List<Uri> forwardHistory;
  final SortSpec sort;
  final String? quickFilter;
  final bool loading;
}

class ConnectionProfile {
  final String id;
  final FileSourceType type;   // smb, ftp
  final String host;
  final String? shareOrPath;
  final String? username;      // 비밀번호는 별도 secure storage에 credentialId로만 참조
}
```

경로를 `Uri` 스킴(`file/smb/ftp`)으로 통일하면 패널이 어떤 소스를 보고 있든 동일한 인터페이스로 다룰 수 있다.

## 4. 파일시스템 추상화 (로컬/네트워크 공통 인터페이스)

```dart
abstract class FileSystemRepository {
  bool supports(Uri location);
  Stream<FileEntry> list(Uri directory);
  Future<void> createDirectory(Uri location);
  Future<void> delete(Uri location, {required bool toTrash});
  Future<void> rename(Uri from, Uri to);
  Stream<TransferProgress> copy(List<Uri> sources, Uri destDir, {required ConflictResolver onConflict});
  Stream<TransferProgress> move(List<Uri> sources, Uri destDir, {required ConflictResolver onConflict});
}
```

- `LocalFileSystemRepository` — `dart:io` 기반 (P0)
- `SmbFileSystemRepository` — P1
- `FtpFileSystemRepository` — P2
- 상위 레벨 `CompositeFileSystemRepository`가 URI 스킴을 보고 알맞은 구현체로 라우팅.

**SMB/FTP 구현 방식 결정 필요 (스파이크 항목):**
| 방식 | 장점 | 단점 |
|---|---|---|
| A. OS 레벨 마운트 후 로컬 경로처럼 처리 (Windows `net use`, macOS `mount_smbfs`, Linux `gvfs`/`cifs`) | 구현 리스크 낮음, LocalFileSystemRepository 재사용 가능 | OS별 마운트 명령 상이, 관리자 권한/사용자 동의 필요할 수 있음 |
| B. 순수 Dart/네이티브 SMB·FTP 클라이언트 라이브러리 직접 구현 | 마운트 없이 앱 내에서 완결, UX 일관 | SMB 라이브러리 생태계 미성숙 (검증 필요), 유지보수 부담 |

→ **확정: SMB는 A안(OS 마운트)**으로 진행. **FTP/SFTP/WebDAV는 B안(순수 Dart 클라이언트 — 각각 `ftpconnect`/`dartssh2`/`webdav_client`)으로 구현 완료.**

> **실제 구현은 위 추상 인터페이스보다 더 얇게 갔다** (YAGNI — 처음엔 스킴이 2개뿐이라 풀 리포지토리 패턴은 과했음): `PaneState.currentPath`는 여전히 `String`이고, `ftp://`/`sftp://`/`webdav(s)://`로 시작하면 각각 원격 스킴으로 인식한다(`pane_controller.dart`의 `isFtpPath`/`isSftpPath`/`isWebdavPath`/`isRemotePath`/`resolveLocationString`/`locationToPathString`). 로컬-로컬 전송은 기존 `FileOperationService`를 그대로 쓰고, 원격 스킴이 하나라도 관여하면 `application/transfer_router.dart`의 `performTransfer()`가 소스/목적지 스킴 조합을 보고 알맞은 전송 서비스(`FtpTransferService`/`SftpTransferService`/`WebdavTransferService`)로 라우팅한다 — 로컬↔원격, 같은 프로토콜의 세션간, 그리고 **서로 다른 원격 프로토콜간**(예: FTP→SFTP, 로컬 임시 폴더 경유)까지 하나의 일반화된 분기 세트로 처리한다. `FileEntry.location.path`는 어떤 스킴이든 항상 posix 스타일 슬래시라서 `p.posix.*`로 전부 동일하게 다룰 수 있었다. 각 프로토콜의 세션 매니저(`Ftp`/`Sftp`/`WebdavSessionManager`)가 `user@host:port`(WebDAV는 http/https 구분까지) 키로 살아있는 연결을 들고 있는다. 비밀번호는 연결에만 쓰고 어디에도 저장하지 않으며, 각 프로토콜의 `*Profile`(host/port/username만)만 `shared_preferences`에 저장한다. **알려진 스코프 축소**: 폴더 전체 업로드/다운로드는 재귀 헬퍼(`ftpconnect` 내장 또는 `application/remote_dir_walk.dart`의 공용 콜백 기반 순회)로 처리해 폴더 안 개별 파일 충돌 확인은 지원하지 않는다(있으면 덮어씀). 압축·속성 보기는 로컬 전용으로 남겨뒀다.

## 5. 파일 작업 큐 (복사/이동/삭제) — 진행률·취소·충돌 처리

대용량 작업 중 UI 응답성을 유지하기 위해 **Isolate**에서 실행하고, 진행률/충돌을 포트로 스트리밍한다.

```
UI ── enqueue(CopyJob) ──▶ OperationQueue
                              │ spawn Isolate
                              ▼
                     ┌─────────────────┐
                     │  copy worker    │──▶ ReceivePort: TransferProgress(bytesDone, currentFile)
                     │  (파일 단위 루프) │──▶ ReceivePort: ConflictEvent(existingFile) ─┐
                     └─────────────────┘                                          │
                              ▲                                                    ▼
                              └──────────── SendPort: ConflictResolution ◀── UI 다이얼로그
```

- **취소/일시정지**: Job마다 `CancelToken`(플래그를 담은 공유 상태)을 두고, worker가 파일 단위 경계마다 체크. 취소 시 마지막 파일은 롤백(임시 파일 삭제).
- **충돌 처리**: worker가 대상 파일 존재를 감지하면 진행을 멈추고 `ConflictEvent`를 보낸 뒤 UI 응답을 기다림. "모두 적용" 선택 시 이후 동일 정책을 worker에 캐싱.
- **큐 정책**: 기본은 순차 실행(동시 1개) — 네트워크 드라이브 동시 다중 작업 시 대역폭/락 문제 회피. 로컬-로컬 작업은 추후 병렬화 검토(P2).
- `OperationQueueProvider`가 모든 Job의 상태(`queued/running/paused/done/error/cancelled`)를 노출 → 하단 "작업 상태 패널" UI에서 구독.

## 6. 패널(Pane) 및 탐색

- 좌/우 패널은 독립된 `PaneState`를 가지며, `activePaneProvider`로 포커스만 공유.
- 패널 간 동작(복사 대상 = 반대 패널의 현재 경로)은 `application` 레이어의 `CopyToOtherPaneUseCase`가 두 패널 상태를 참조해 처리 — UI는 패널 상태를 직접 알 필요 없음.
- 뒤로/앞으로 히스토리는 패널별 스택으로 관리, Breadcrumb은 `currentPath.pathSegments`에서 파생.
- 정렬/필터/숨김파일 표시는 패널별 로컬 설정이되, 기본값은 전역 설정에서 상속.

## 7. 뷰어 (Viewer) 확장 구조

```dart
abstract class FileViewer {
  bool canHandle(FileEntry entry);
  Widget build(BuildContext context, FileEntry entry);
}
```
- `ViewerRegistry`에 텍스트/이미지(P1), Hex/PDF/미디어(P2) 뷰어를 등록. 확장자·MIME 기준 매칭, 다중 매칭 시 우선순위로 선택.
- 뷰어는 지연 로딩(파일을 열 때만 해당 위젯 빌드) → 초기 구동 속도 영향 최소화.

## 8. 영속성

| 데이터 | 저장 방식 |
|---|---|
| 앱 설정(테마, 정렬 기본값 등) | `shared_preferences` 또는 JSON 파일 (앱 지원 디렉터리) |
| 북마크, 최근 방문 경로, 연결 프로필 메타데이터 | 로컬 DB (`drift` 또는 `sqlite3`) — 목록/검색이 필요한 데이터라 키값 저장소보다 적합 |
| 네트워크 드라이브 자격증명 | `flutter_secure_storage` (OS 자격증명 저장소, 평문 저장 금지) |

## 9. 플랫폼별 고려사항

- **macOS**: **App Sandbox는 비활성화**한다 (확정, `macos/Runner/*.entitlements`에 반영됨). 파일 매니저는 사용자가 선택하지 않은 임의 경로를 자유롭게 탐색해야 하는데, App Sandbox 기본값은 `$HOME`조차 앱 컨테이너 경로로 리다이렉트해 정상 동작이 불가능함을 빌드 검증 중 확인했다. App Store 배포 대신 공증(notarization) 기반 독립 배포를 전제로 한다. Full Disk Access(사진/캘린더 등 TCC 보호 폴더) 권한은 필요 시점에 사용자 안내 다이얼로그로 별도 처리.
- **Windows**: 드라이브 문자 목록(`GetLogicalDrives` 계열), UAC가 필요한 경로 접근 시 에러 처리.
- **Linux**: 배포판별 trash 구현 차이(`trash-cli`/`gio trash`), 파일 권한 UI는 POSIX 모드 기준으로 단순화.

## 10. 제안 패키지 (초안)

- 상태관리: `flutter_riverpod`
- 로컬 DB: `drift` (또는 초기엔 `sqlite3` 직접)
- 보안 저장소: `flutter_secure_storage`
- 압축: `archive`
- FTP: `ftpconnect`
- SFTP: `dartssh2` (`ftpconnect`가 이미 전이 의존성으로 물고 있던 패키지라 새 의존성 부담은 사실상 없음)
- WebDAV: `webdav_client`
- 드래그앤드롭(OS → 앱): `desktop_drop` — ✅ 구현 완료. `DropTarget`은 네이티브 OS 드래그 이벤트를 쓰고 패널 내부 이동에 쓰는 Flutter 기본 `Draggable`/`DragTarget`은 제스처 기반이라 서로 다른 경로 — 같은 위젯 트리에 겹쳐놔도 간섭 없음. 드롭은 항상 복사(원본 삭제 위험 방지), 목적지 스킴에 따라 로컬 복사/업로드로 자동 라우팅(`transferEntries` 재사용). 앱 → OS 드래그 아웃은 자체 플러그인 [`flutter_drag_out`](https://github.com/jejezz/flutter_drag_out)(git 의존성)으로 분리했다 — macOS ✅, Windows/Linux 예정. 앱 내부 드래그(`Draggable`)와 드래그 인(`desktop_drop`)은 그대로 두고, 포인터가 창 밖으로 나가는 순간에만 OS 드래그 세션으로 넘긴다(드롭 타겟을 등록하지 않으므로 `desktop_drop`과 충돌 없음). `file://` 항목(로컬 + OS 마운트 네트워크 드라이브)만 대상이며, FTP/SFTP/WebDAV 항목은 로컬 패널로 끌어 내려받은 뒤 끌어낸다. 앱 밖으로는 복사만 허용. `super_drag_and_drop`으로 드래그 전체를 교체했던 #20은 Windows에서 앱 내부 드래그까지 깨뜨려 롤백했다(#22) — 그래서 기존 경로를 건드리지 않는 방식을 택했다.
- 커스텀 타이틀바/창 제어: `window_manager`
- 경로 처리: `path`

## 11. 테스트 전략

- `domain`/`application`: 순수 Dart 유닛 테스트. 로컬 파일 연산은 `Directory.systemTemp`로 실제 검증(`file_operation_service_test.dart` 등).
- `presentation`: 위젯 테스트는 핵심 인터랙션(선택, 정렬 변경)만 우선.
- **FTP/SFTP/WebDAV는 실제 로컬 서버로 통합 테스트한다** — Docker 대신 파이썬 서버를 테스트 안에서 직접 fork해 임시 디렉터리를 서빙한다: FTP는 `python3 -m pyftpdlib`(CLI가 있어 바로 실행), SFTP/WebDAV는 CLI로는 사용자명/비밀번호 인증을 못 켜서 최소 서버 스크립트를 따로 뒀다(`test/support/sftp_test_server.py` — asyncssh, `test/support/webdav_test_server.py` — wsgidav+cheroot). 각각 우리 세션 매니저/전송 서비스/목록 usecase로 목록·업로드·다운로드·새폴더·이름변경·삭제·충돌·폴더 재귀 업로드까지 실제 프로토콜로 검증한다(`test/ftp_integration_test.dart`, `test/sftp_integration_test.dart`, `test/webdav_integration_test.dart`). 필요한 파이썬 패키지(`pyftpdlib`/`asyncssh`/`wsgidav`+`cheroot`) 미설치 환경에서는 각 테스트가 스킵된다. SMB는 OS가 프로토콜을 구현하므로 이런 통합 테스트가 필요 없었다.
- SFTP 테스트 서버는 처음에 asyncssh의 `chroot` 옵션으로 서버 루트를 가상 `/`로 격리하려 했으나, dartssh2 클라이언트가 보내는 절대경로 mkdir/open 요청을 서버가 chroot 밖(진짜 파일시스템 루트)으로 잘못 풀어버리는 문제가 있었다(순수 파이썬 클라이언트로는 재현 안 됨). macOS에서는 진짜 `/`가 SIP로 쓰기 금지라 "Read-only file system" 에러로 드러나 원인을 특정할 수 있었다. 해결책은 chroot를 아예 안 쓰고 서버가 실제 로컬 임시 폴더를 그대로 노출하는 것 — 이 앱은 애초에 원격 루트를 `/`로 가정하지 않고 URI의 path를 그대로 쓰므로 실제 동작과도 더 가깝다.

## 다음 단계
P0/P1은 완료, P2는 진행 중 — 최신 진행 상황과 남은 항목은 [PLAN.md](PLAN.md)를 참고 (이 문서는 설계 근거·결정 기록용, 진행 상태 추적은 PLAN.md가 맡는다).
