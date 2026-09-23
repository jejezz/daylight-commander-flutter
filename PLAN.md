# Daylight Commander — 기획서 (v0.1)

## 개요
Total Commander / Midnight Commander 스타일의 **무료 2-pane 파일 탐색기**를 Flutter로 구현한다.
지원 플랫폼은 **Windows, macOS, Linux (데스크톱 전용, 확정)**이며, 모바일은 지원하지 않는다.
UI 디자인은 이후 별도로 결정한다. 본 문서는 기능 범위 확인용 초안이다.

## 핵심 컨셉
- 2-pane(듀얼 패널) 구조, 좌/우 패널이 각각 독립적인 경로를 탐색
- 키보드 중심 조작(단축키) + 마우스 조작 병행 지원

## 우선순위 태그 정의
- **P0 (MVP 필수)**: 1차 출시에 반드시 포함
- **P1 (Fast-follow)**: MVP 직후 우선 추가
- **P2 (추후)**: 여유 있을 때 추가, 후순위

## 기능 리스트

### 1. 기본 파일 탐색
- `P0` 2-pane 동시 탐색 (좌/우 독립 경로 유지)
- `P2` 패널별 탭 지원 (다중 탭)
- `P0` 주소창 직접 입력 및 경로 히스토리(뒤로/앞으로)
- `P1` 즐겨찾기(북마크) 경로 관리
- `P0` 드라이브/볼륨 전환 (로컬 디스크, 외장 디스크, 네트워크 드라이브)
- `P0` 숨김 파일/시스템 파일 표시 토글
- `P0` 정렬 (이름/크기/수정일/확장자), 폴더 우선 정렬
- `P1` 퀵서치 (타이핑 시 즉시 필터링/점프)
- `P0` 상위 폴더 이동 및 경로 트리(Breadcrumb)

### 2. 파일 조작
- `P0` 복사 (다른 pane으로, 단축키 지원)
- `P0` 이동
- `P0` 삭제 (휴지통으로 보내기 / 영구 삭제 옵션)
- `P0` 이름 변경 (단일)
- `P2` 다중 일괄 리네임 규칙
- `P0` 새 폴더 / 새 파일 생성
- `P1` 압축 및 압축 해제 (zip 우선, 추후 다른 포맷 확장)
- `P1` 속성 확인/변경 (읽기전용, 권한 등 — OS별 대응 필요)
- `P0` 대용량 작업 진행률 표시, 취소/일시정지
- `P0` 충돌 처리 (덮어쓰기 / 건너뛰기 / 이름변경 / 모두 적용)

### 3. 다중 선택
- `P0` 체크박스 및 Ctrl/Shift 다중 선택
- `P1` 패턴 기반 선택/선택 해제 (예: `*.jpg`)
- `P0` 전체 선택 / 선택 반전
- `P1` 선택 항목 개수 및 총 용량 표시

### 4. 네트워크 드라이브
- `P1` SMB/CIFS 연결 (네트워크 드라이브 중 1순위, 최우선 구현) — ✅ 완료 (OS 마운트 방식)
- `P2` FTP 연결 (2순위) — ✅ 완료 (순수 Dart 클라이언트, `ftpconnect`) — 자세한 내용은 아래 "9. FTP 클라이언트" 참고
- `P2` WebDAV / SFTP 연결 — ✅ 완료 (순수 Dart 클라이언트, WebDAV는 `webdav_client`, SFTP는 `dartssh2`) — 자세한 내용은 아래 "10. SFTP/WebDAV 클라이언트" 참고
- `P1`/`P2` 연결 프로필 저장 (서버 즐겨찾기 목록, 계정 정보 안전 저장) — ✅ 완료 (SMB/FTP/SFTP/WebDAV 모두 host/port/공유·계정명만 저장, 비밀번호는 절대 저장 안 함)
- 클라우드 스토리지 연동은 1차 범위 밖 (향후 확장 가능한 구조로 설계)

### 5. 자체 뷰어 (Viewer)
- `P1` 텍스트 뷰어 (인코딩 자동 감지) — ✅ 완료 (UTF-8 → Latin-1 폴백, 자동 감지는 아님)
- `P1` 이미지 뷰어 (jpg/png/gif/webp 등, 슬라이드쇼) — ✅ 완료 (슬라이드쇼는 미착수)
- `P2` Hex 뷰어 (바이너리 파일 확인) — ✅ 완료 (256KB 미리보기 상한)
- `P2` 압축파일 내부 미리보기 (풀지 않고 열람) — ✅ 완료 (아래 8번 참고)
- `P2` 미디어(오디오/비디오) 간단 미리보기 — ✅ 완료 (`media_kit`)
- `P2` PDF 뷰어 — ✅ 완료 (`pdfrx`)

### 6. 추가 편의 기능
- `P2` 폴더 비교 (좌우 폴더 내용 비교, 차이점 하이라이트)
- `P2` 폴더 동기화 (단방향/양방향) — ✅ 완료 (양방향은 아래 8번 참고)
- `P1` 파일 검색 (이름/내용/정규식, 하위 폴더 재귀 검색)
- `P1` 최근 방문 폴더 히스토리
- `P2` 단축키 커스터마이징
- `P1` 다크/라이트 테마 — ✅ 완료. 처음엔 OS 시스템 설정만 따라갔는데, 앱
  안에서 직접 바꾸고 싶다는 요청으로 앱바에 토글 버튼 추가(시스템 →
  라이트 고정 → 다크 고정 → 다시 시스템 순환), 선택은
  `shared_preferences`로 저장돼 재시작해도 유지됨
- `P2` 다국어 지원 (한국어/영어) — ✅ 완료. Flutter 공식 `gen-l10n` 도구로
  ARB 기반 i18n 구축, 앱바에 언어 토글 버튼(테마 토글과 같은 패턴: 시스템
  → 한국어 → 영어 → 시스템 순환) 추가
- `P1` 터미널 열기 (현재 패널 경로에서, 사용자 요청으로 추가) — ✅ 완료
- `P1` 우클릭 컨텍스트 메뉴 (사용자 요청으로 추가) — ✅ 완료. Flutter 자체 `showMenu` 방식이라 OS별 분기 없음
- `P1` 키보드 탐색 (↑/↓ 커서 이동, Space 다중선택 토글 — 마우스 클릭과 분리된 모델, 사용자 요청으로 추가) — ✅ 완료
- `P1` OS → 앱 드래그앤드롭 (Finder/탐색기에서 파일을 끌어다 패널에 드롭 → 복사, 사용자 요청으로 추가) — ✅ 완료. `desktop_drop` 사용, 목적지가 FTP 패널이면 업로드로 자연스럽게 이어짐. 반대 방향(앱 → OS)은 아래 항목 참고.
- `P1` 앱 → OS 드래그 아웃 (패널에서 끌어 Finder/탐색기에 드롭 → 복사) — macOS ✅, Windows/Linux 예정. 자체 플러그인 [`flutter_drag_out`](https://github.com/jejezz/flutter_drag_out)으로 분리. 로컬·네트워크 드라이브 항목만, FTP/SFTP/WebDAV는 로컬 패널로 끌어 내려받은 뒤 끌어낸다.
- `P1` 더블클릭으로 OS 기본 앱 열기 (Finder/탐색기와 동일한 동작, 사용자 요청으로 추가) — ✅ 완료. 폴더는 그대로 탐색 이동, 파일은 항상 OS가 확장자에 연결해 둔 기본 앱으로 실행(`open`/`start`/`xdg-open`). 내장 뷰어(F3)는 더블클릭에서 분리되어 F3 키·우클릭 메뉴로만 접근. FTP 파일은 임시 폴더로 내려받은 뒤 그 로컬 경로로 실행

## 1차 범위 밖 (비목표)
- 클라우드 스토리지 전면 지원 (1차는 로컬 + SMB/FTP/WebDAV까지)
- 플러그인 시스템
- 모바일 지원 (Android/iOS 대상 아님, 확정)

## 기술 스택 (초안, 확정 아님)
- Flutter Desktop (Windows / macOS / Linux) — 지원 플랫폼 확정
- 파일시스템: `dart:io` + 필요 시 플랫폼 채널 (네트워크 드라이브, 권한 처리)
- 상태 관리: 미정
- UI 디자인: 미정 (별도 논의 예정)

## 다음 단계
1. ~~위 기능 리스트 검토 및 MVP 범위 확정 (우선순위 태깅)~~ — 완료
2. ~~아키텍처 설계 (패널 상태관리, 파일 작업 큐/취소 처리)~~ — 완료, [ARCHITECTURE.md](ARCHITECTURE.md) 참고
3. ~~UI/UX 설계~~ — 완료, [UI_UX.md](UI_UX.md) 참고
4. ~~프로젝트 초기 세팅~~ — 완료 (Windows/macOS/Linux 스캐폴드, 테마·아이콘 적용, macOS 빌드로 확인)
5. ~~P0 기능 구현~~ — 완료:
   - 다중 선택(클릭/Ctrl·Cmd/Shift/전체선택), 복사·이동(F5/F6, 충돌 시 덮어쓰기·건너뛰기·이름변경·모두적용), 삭제(F8, 휴지통/영구), 새 폴더(F7)·이름변경(F2), 진행률 배너+취소
   - 주소창 직접 입력 + 뒤로/앞으로 히스토리, 드라이브·볼륨 전환(macOS `/Volumes`, Windows 드라이브 문자, Linux `/media`·`/mnt`), 컬럼 헤더 클릭 정렬(이름/크기/수정일, 폴더 우선 고정), 숨김파일 표시 토글
   - 검증: `test/file_operation_service_test.dart`(11개) + `test/pane_controller_test.dart`(6개) 단위테스트, macOS 빌드 실행 화면 확인
6. P1 — **1차 완료**:
   - 즐겨찾기(북마크): 경로 저장/토글/이동/삭제 (`shared_preferences`, 경로 문자열만 저장 — 자격증명 아님)
   - 퀵서치: 타이핑 시 이름에 포함된 항목만 즉시 필터링, Backspace/Esc로 수정·해제, 주소창 미포커스 시에만 동작
   - SMB 연결: 호스트/공유명만 입력 → OS의 `smb://` 마운트 다이얼로그로 위임 (비밀번호는 절대 다루지 않음)
   - 압축/압축 해제: zip 생성·해제 (`archive` 패키지)
   - 텍스트/이미지 뷰어 (F3): 텍스트는 UTF-8→Latin-1 폴백, 그 외 형식은 OS 기본 앱으로 열기 제공
   - 검증: `test/pane_controller_test.dart`(퀵서치), `test/archive_service_test.dart`, `test/bookmarks_test.dart` 추가, macOS 릴리스 빌드로 UI 확인
   - ~~속성 확인/변경(읽기전용)~~ / ~~패턴 기반 선택·해제(`*.jpg`)~~ / ~~최근 방문 폴더 히스토리~~ / ~~저장된 SMB 서버 프로필~~ — 모두 완료 (아래 참고)
7. ~~P1~~ — **전체 완료**:
   - 속성: 이름/경로/종류/크기(폴더는 재귀 합산)/수정일/권한 문자열 표시 + "읽기 전용" 토글 (macOS·Linux는 `chmod`, Windows는 `attrib`). 전체 rwx 권한 그리드 편집은 P2로 미룸
   - 패턴 선택: `*`/`?` 와일드카드로 선택 추가/해제 (F-바 "패턴선택" 버튼)
   - 최근 방문 폴더: 뒤로/앞으로 히스토리와 별개로 최근 15개를 저장, 즐겨찾기 팝업 메뉴에 "최근 방문" 섹션으로 통합 표시
   - SMB 서버 프로필: 호스트/공유 이름만 저장(비밀번호 제외), 연결 다이얼로그에서 클릭 한 번으로 재사용
   - 터미널 열기: 앱바 아이콘 1개(활성 패널 경로 기준) + `Ctrl/Cmd+\`` 단축키로 OS 기본 터미널 실행 (macOS `open -a Terminal`, Windows `wt.exe`→`cmd` 폴백, Linux gnome-terminal/konsole/xfce4-terminal/xterm 순 폴백). 처음엔 패널마다 버튼을 뒀다가, 활성 패널 개념이 이미 있으니 하나로 충분하다는 피드백을 받아 통합함
   - 검증: `test/file_attributes_service_test.dart`, `test/network_profiles_test.dart`, `test/recent_folders_test.dart`, `pane_controller_test.dart`(패턴 선택) 추가, macOS 릴리스 빌드로 2단 기능바 레이아웃 확인
8. P2 — **일부 완료** (새 의존성 없이 구현 가능한 항목 우선):
   - Hex 뷰어: 뷰어(F3) 우측 상단 아이콘으로 어떤 파일이든 Hex 덤프로 전환 가능, 256KB까지만 미리보기(스트리밍은 후순위)
   - 폴더 비교: 앱바 우측 "폴더 비교" 아이콘으로 켜면 좌우 패널에서 이름 기준으로 한쪽에만 있는 항목(보라)/크기·수정일이 다른 항목(주황) 하이라이트, 하단에 "차이 N개 → 복사" / "← 복사" 버튼(단방향 동기화, 항상 복사만 — 원본 삭제 없음)
   - 전체 권한(rwx) 편집: 속성 다이얼로그에서 macOS/Linux는 소유자/그룹/기타 × 읽기/쓰기/실행 9칸 체크박스로 `chmod` 직접 편집, Windows는 기존 읽기전용 토글 유지
   - 검증: `test/folder_comparison_test.dart`(순수 비교 함수), `test/file_attributes_service_test.dart`(rwx 비트 설정) 추가, macOS 릴리스 빌드를 창 단위로 캡처해 새 아이콘 렌더링 확인
   - 양방향 동기화: "폴더 비교" 바에 세 번째 버튼 "양방향 동기화" 추가. 한쪽에만 있는 항목은 자동으로 반대쪽에 복사(충돌 없음), 양쪽 다 있지만 내용이 다른 파일은 `diffPairs()`로 짝지어 파일마다 좌/우 크기·수정일을 보여주는 다이얼로그로 하나하나 물어봄(사용자 요청: 자동 "최신 파일 우선" 병합은 하지 않음 — 항상 사용자가 선택). 취소 시 그 시점까지 처리분은 유지하고 나머지는 중단
   - 검증: `test/folder_comparison_test.dart`에 `diffPairs` 테스트 추가(총 81개 테스트 통과), macOS 디버그 빌드에서 `compareModeProvider` 기본값을 일시적으로 true로 바꿔 새 버튼 렌더링을 창 단위 캡처로 확인 후 원복
   - 압축파일 내부 미리보기: zip을 풀지 않고 F3/컨텍스트 메뉴 "보기"로 열면 내부 파일/폴더 구조를 훑어볼 수 있는 전용 뷰어(`ArchiveViewerScreen`)가 뜬다. `archive` 패키지의 `InputFileStream` + `ZipDecoder`로 중앙 디렉터리만 읽어 목록을 만들고(전체를 메모리에 올리지 않음), 이름의 슬래시로 가상 폴더 구조를 구성해 ".." 항목으로 상위 이동. 파일을 탭하면 그 파일 하나만 임시 폴더로 꺼내 기존 `ViewerScreen`(텍스트/이미지/PDF/오디오/비디오/Hex 뷰어)으로 그대로 연다 — zip 전체는 절대 풀지 않음
   - 검증: `test/archive_service_test.dart`에 `listZipEntries`/`extractZipEntry` 단위테스트, `test/archive_viewer_screen_test.dart`에 폴더 드릴다운·파일 열기 위젯테스트 추가(총 85개 테스트 통과). 위젯테스트에서 알게 된 점: `flutter test`의 FakeAsync 존 안에서 탭 콜백으로 시작되는 실제 dart:io 비동기 작업(파일 읽기/쓰기, 화면 전환)은 `pump()`만으로 끝나지 않으므로, 탭 자체를 `tester.runAsync()` 콜백 안에서 실행해야 함. macOS 디버그 빌드로 앱이 새 코드로 정상 구동되는지 창 단위 캡처로 확인
   - **아직 남은 P2 항목**: Hex 뷰어 대용량 스트리밍 — 사용자 판단으로 필수
     요소는 아니라고 보류 결정 (2026-09-20). 현재도 256KB까지는 미리보기
     되므로 실사용에 큰 지장은 없음
10. PDF/미디어(오디오·비디오) 뷰어 — **완료**:
    - PDF: `pdfrx` 채택 (Windows/macOS/Linux 모두 지원, PDFium 기반). 처음 검토한 `pdfx`는 Linux 미지원이라 제외
    - 오디오/비디오: `media_kit` + `media_kit_video` + `media_kit_libs_video` 채택 (libmpv 기반, 3개 데스크톱 플랫폼 모두 지원). `main.dart`에서 앱 시작 시 `MediaKit.ensureInitialized()` 1회 호출 필요
    - 비디오는 `Video(controller:)` 위젯 그대로 사용. 오디오는 영상 출력이 없어 커스텀 UI(재생/일시정지 버튼 + 탐색 슬라이더 + 경과/전체 시간)를 `Player.stream.position`/`.duration`/`.playing` 스트림으로 직접 구성
    - `pdfrx` 도입 과정에서 의존성 충돌 발견: `pdfrx`(→`pdfrx_engine`)가 `archive: ^4.0.9`를 요구해서 기존 `archive: ^3.6.1`(압축 기능이 쓰던 버전)과 버전 해결이 실패 — `archive`를 4.3.0으로 올려 해결. 메이저 버전업이지만 압축 기능이 쓰는 `ZipFileEncoder`/`extractFileToDisk` API는 그대로 유지되어 `archive_service_test.dart` 재실행으로 회귀 없음을 확인
    - 검증: `flutter analyze`/전체 테스트 61개 통과, macOS 디버그 빌드 성공(네이티브 라이브러리 링크 확인). ffmpeg으로 만든 샘플 pdf/mp4/mp3 파일로 실제 재생 확인은 사용자에게 요청(더블클릭/드래그앤드롭처럼 상호작용이 필요한 부분이라 자동 검증 불가)
9. FTP 클라이언트 — **완료** (사용자 요청으로 P2 중 우선 착수):
   - SMB와 달리 OS에 위임할 수 없어(모던 macOS는 Finder의 FTP 지원을 제거함) 앱이 직접 프로토콜을 구현 — 순수 Dart 패키지 `ftpconnect` 채택
   - 연결: 호스트/포트/사용자명 + 비밀번호(연결에만 사용, 저장 안 함) 입력 다이얼로그, "익명 로그인" 체크박스, 저장된 프로필(비밀번호 제외) 클릭으로 재사용
   - 패널 경로가 `ftp://user@host:port/path` 문자열이면 FTP로 인식해 탐색 — 주소창에 직접 입력해도 되고, 뒤로/앞으로/북마크/최근방문/퀵서치/정렬/패턴선택도 그대로 동작 (모두 FileEntry 리스트 위에서 동작하는 범용 로직이라 별도 작업 불필요)
   - 전송: 로컬↔FTP 업로드/다운로드, FTP 세션간 전송(임시 폴더 경유, 서버간 직접 복사 명령이 없어서), 개별 파일은 기존 충돌 다이얼로그(덮어쓰기/건너뛰기/이름변경/모두적용) 그대로 지원. **폴더 통째 전송은 패키지의 재귀 헬퍼에 위임해 폴더 내부 개별 충돌 확인은 지원하지 않음**(있으면 덮어씀) — 알려진 스코프 축소
   - 드래그 기본 동작: 같은 FTP 서버(같은 계정) 안에서는 이동, 그 외(로컬↔FTP, 다른 서버)는 복사가 기본
   - 아직 안 되는 것: 압축/압축풀기, 속성 보기, F3 뷰어는 지원(임시파일로 내려받아 봄) — 압축·속성은 로컬 전용으로 남겨둠
   - 검증: **실제 로컬 FTP 서버(`pyftpdlib`)를 띄워 통합 테스트 7개** 작성 — 목록/업로드/다운로드/새폴더/이름변경/삭제/충돌 덮어쓰기까지 전부 실제 서버 상대로 확인. SMB처럼 OS가 대신 해주는 게 아니라 우리가 프로토콜을 구현했기 때문에 이 정도 검증이 특히 중요했음
11. SFTP/WebDAV 클라이언트 — **완료** (FTP에 이어 사용자 요청):
    - SFTP: 순수 Dart SSH 구현 `dartssh2` 채택 — 이미 `ftpconnect`가 전이 의존성으로 물고 있던 패키지라 실질적으로 새 의존성 부담은 없었음(버전만 `^3.3.1`로 맞춤). FTP와 달리 익명 로그인 개념이 없어 연결 다이얼로그에 "익명" 체크박스 없이 사용자명이 항상 필수
    - WebDAV: 순수 Dart HTTP 클라이언트 `webdav_client` 채택. HTTP/HTTPS 둘 다 지원해야 해서 스킴을 `webdav://`(HTTP)/`webdavs://`(HTTPS) 둘로 나눔 — 세션 키에도 보안 여부를 포함해 같은 호스트라도 http/https는 다른 세션으로 취급
    - 패널 경로 스킴 판정을 `isFtpPath` 하나에서 `isSftpPath`/`isWebdavPath`/`isRemotePath`(셋 중 하나)로 일반화 (`pane_controller.dart`). `PaneController`가 세 세션 매니저를 모두 들고 있다가 경로 스킴에 따라 `ListFtpDirectory`/`ListSftpDirectory`/`ListWebdavDirectory` 중 하나로 디렉터리를 읽음
    - 전송(`transfer_router.dart`): 로컬↔SFTP, 로컬↔WebDAV, 같은 프로토콜의 세션간 전송(SFTP↔SFTP, WebDAV↔WebDAV — FTP↔FTP와 동일하게 임시 폴더 경유)에 더해, **서로 다른 원격 프로토콜간 전송(예: FTP→SFTP)** 도 새로 지원 — 표준 서버간 복사 명령이 있을 리 없으니 한쪽은 로컬 임시 폴더로 내려받고 다른 쪽으로 다시 올리는 일반화된 경로 하나로 6가지 조합을 전부 처리(프로토콜별 다운로드/업로드 함수만 스킴으로 골라 씀)
    - dartssh2/webdav_client 둘 다 `ftpconnect`(`uploadDirectory`/`downloadDirectory`)와 달리 폴더 통째 전송 헬퍼가 없어서, 로컬↔원격 폴더 재귀 순회를 직접 구현(`remote_dir_walk.dart`, SFTP/WebDAV 공용 콜백 기반 헬퍼). 다만 WebDAV의 삭제/이름변경은 반대로 서버가 컬렉션(폴더)에 대해 DELETE/MOVE를 재귀 처리해줘서 SFTP보다 오히려 더 간단함
    - UI: 패스바의 SMB/FTP 개별 아이콘 버튼 2개를 팝업 메뉴 하나("네트워크 드라이브 연결": SMB/FTP/SFTP/WebDAV 연결 + 연결됐을 때 "연결 해제")로 통합 — 원래도 아이콘이 4개가 될 상황이라 터미널 버튼 통합 때와 같은 이유로 먼저 정리함
    - 검증: **로컬 SFTP 서버(파이썬 asyncssh)와 로컬 WebDAV 서버(파이썬 wsgidav)를 각각 실제로 띄워 통합 테스트 8개씩** 작성(`test/sftp_integration_test.dart`, `test/webdav_integration_test.dart`, 실행 스크립트는 `test/support/*.py`) — 목록/업로드/다운로드/새폴더/이름변경/삭제/충돌 덮어쓰기/폴더 재귀 업로드까지 확인. SFTP 테스트 서버는 처음에 asyncssh의 `chroot` 옵션을 썼다가, dartssh2 클라이언트가 보내는 절대경로 요청을 서버가 진짜 파일시스템 루트로 잘못 풀어버려("Read-only file system" 에러, macOS SIP 때문에 진짜 `/`가 쓰기 금지라 이렇게 드러남) chroot 없이 실제 임시 폴더를 그대로 노출하는 방식으로 바꿔 해결
12. 다국어 지원(i18n) — **완료** (남은 P2 중 사용자가 우선순위로 선택):
    - Flutter 공식 `flutter_localizations` + `intl` + `gen-l10n` 코드젠 채택.
      `l10n.yaml`(`lib/l10n/app_ko.arb`를 템플릿으로) → `AppLocalizations`
      클래스 자동 생성. 커스텀 번역 맵 방식 대신 공식 도구를 쓴 이유는
      플레이스홀더 타입 체크·IDE 자동완성·표준 관례를 그대로 얻기 위해서
    - 범위: **presentation 레이어의 정적 UI 문자열**(버튼/툴팁/다이얼로그/
      컨텍스트 메뉴/상태바) 전부. **의도적으로 뺀 것**: `catch (e)` 이후
      `Text('$e')`로 그대로 보여주는 예외 메시지 자체(SnackBar에 뜨는 순수
      런타임 에러 텍스트) — 그 앞의 고정 문구("압축 실패: " 등)는
      번역했지만, 예외 객체가 실제로 담고 있는 메시지(대개 플랫폼/패키지가
      영어로 만든 문자열)까지 지역화하려면 앱 전체 예외 처리를 로케일
      인식 커스텀 예외로 다시 설계해야 해서 범위 밖으로 남김
    - 앱바에 언어 토글 버튼 추가 — 테마 토글과 완전히 같은 패턴
      (`LocaleController`가 `ThemeModeController`를 그대로 본떠 시스템 →
      한국어 → 영어 → 시스템 순환, `shared_preferences`로 저장)
    - **테스트가 실제로 잡은 버그**: 번역 후 `flutter test`를 돌렸더니
      `_ColumnHeader`(이름/크기/수정일 정렬 헤더)에서 "Modified"가 기존
      한국어 "수정일"보다 길어서 고정폭 컬럼을 오버플로했다 — 언어별
      텍스트 길이 차이가 레이아웃을 깨뜨리는 전형적인 i18n 버그. 컬럼
      너비를 90→105로 넓혀 해결(헤더와 파일 행 양쪽 다 맞춤). 이후 macOS
      빌드로 한국어/영어 두 로케일 모두 스크린샷 확인
    - 검증: `flutter analyze` 클린, 전체 테스트(신규 없음, 기존 회귀만
      확인) 통과, macOS 디버그 빌드로 한국어(기본)/영어(로케일 강제 후)
      두 화면 다 스크린샷 비교

13. 툴바 아이콘 교체 — **완료** (사용자가 icons8 컬러 아이콘 세트를 직접
    받아와 요청):
    - 기존 Material 단색 아이콘(뒤로/앞으로/상위폴더, 드라이브 전환,
      네트워크 연결 표시, 즐겨찾기 별표·목록, 숨김파일 토글, 컬럼 정렬
      화살표, 테마 3종, 언어, 터미널, 폴더 비교/양방향 동기화)을 파일
      타입 아이콘과 같은 icons8 컬러 SVG로 교체. 새 위젯
      `lib/presentation/widgets/tool_icon.dart`의 `ToolIcon`이
      `assets/icons/ui/*.svg`를 그린다
    - on/off 두 상태가 있는 토글(즐겨찾기 별표, 숨김파일, 네트워크 연결,
      폴더비교)은 새 아이콘을 상태별로 2개씩 받지 못해 하나만 받았으므로,
      꺼진 상태는 `Opacity(0.4)`로 흐리게 표시해 구분. 정렬 화살표는
      아이콘 하나를 오름/내림차순에 따라 세로로 뒤집어(`Transform.flip`)
      재사용
      - 매칭되는 새 아이콘이 없는 항목(F-바의 F3/F7/F2/F5/F6/F8/압축/
        압축풀기/속성/패턴선택, 다이얼로그 닫기 버튼 등)은 기존 Material
        아이콘 그대로 유지 — 사용자 확인 결과
      - `color-palette` 아이콘은 쓸 곳이 마땅치 않아 이번엔 미사용으로 확정
    - 검증: `flutter analyze` 클린, 전체 테스트 85개 통과(아이콘 교체는
      로직 변경이 아니라 신규 테스트는 추가하지 않음), macOS 디버그
      빌드로 라이트/다크 테마 두 화면과 폴더비교 켠 화면(동기화 바)까지
      창 단위 캡처로 새 아이콘 렌더링 확인

14. 라이선스 · 앱 정보(About) · 영문 README — **완료** (사용자 요청):
    - `LICENSE`(MIT, Copyright (c) 2026 jyahn) 신규 작성. Windows/macOS
      네이티브 메타데이터의 저작권 표시(`windows/runner/Runner.rc`의
      `CompanyName`/`LegalCopyright`, `macos/Runner/Configs/AppInfo.xcconfig`의
      `PRODUCT_COPYRIGHT`)도 기존 `com.ptype`에서 `jyahn`으로 통일. 앱 ID
      (`com.ptype.daylight_commander` 등 기술 식별자)는 빌드 스크립트가
      참조하므로 그대로 둠
    - `README.en.md` 신규: 기존 한국어 README를 영문으로 번역, 양쪽 문서
      상단에 언어 전환 링크 추가
    - 앱 안에 정보(About) 다이얼로그 신규 추가 — 앱바 우측 끝에 아이콘 추가
      (처음엔 매칭되는 새 아이콘이 없어 Material `info_outline` 사용,
      이후 사용자가 `icons8-information.svg`를 추가로 받아와 `ToolIcon`으로
      교체). `PackageInfo.fromPlatform()`으로 실제 빌드 버전을 읽어와
      표시(하드코딩 안 함), 태그라인/기능 요약/기술 스택/라이선스/GitHub
      링크 포함. GitHub 링크는 `url_launcher` 패키지 없이 기존
      `OpenTerminal`과 같은 방식(`Process.start` OS별 분기)의 신규
      `OpenUrl` 유스케이스로 연다
    - 검증: `flutter analyze` 클린, 전체 테스트 85개 통과, macOS 디버그
      빌드로 정보 다이얼로그 렌더링과 실제 버전 표시를 창 단위 캡처로 확인

15. 런타임 글자 크기 조절 — **완료** (사용자 요청):
    - 앱바에 3단계(보통 → 크게(1.15배) → 작게(0.9배) → 다시 보통)로
      순환하는 토글 버튼 추가. `ThemeModeController`/`LocaleController`와
      완전히 같은 패턴(`FontScaleController`, `shared_preferences`로 저장)
    - `main.dart`의 `MaterialApp.builder`에서 `MediaQuery`를
      `TextScaler.linear(fontScale)`로 감싸 앱 전체에 적용. OS 접근성
      글자 배율과는 곱해서 합성하지 않고 그냥 대체함 — 데스크톱 확대/축소
      기능(VS Code 줌 등)과 같은 방식으로 충분하다고 판단
    - 처음엔 매칭되는 새 아이콘이 없어 Material 아이콘 사용(`format_size`/
      `text_increase`/`text_decrease`)이었다가, 사용자가 `icons8-ocr.svg`를
      추가로 받아와 `ToolIcon`으로 교체 — 언어 토글과 마찬가지로 3단계
      상태 전부에 같은 아이콘 하나를 쓰고 툴팁으로만 구분(icons8 세트에
      상태별 아이콘이 없을 때의 기존 패턴)
    - **테스트가 실제로 잡은 버그**: 글자를 크게(1.15배) 했을 때
      `_ColumnHeader`(이름/크기/수정일 정렬 헤더)의 고정폭 `SizedBox`
      (크기 60px/수정일 105px) 안의 `Row`가 넘쳐 `RenderFlex overflowed`
      에러가 4번(양쪽 패널 × 컬럼 2개) 발생 — i18n 때 컬럼 오버플로
      버그와 같은 종류. 헤더 Row의 라벨 텍스트를 `Flexible` +
      `TextOverflow.ellipsis`로 감싸 해결(넘치면 잘라내고 말줄임표).
      같은 이유로 `_FileRow`의 크기/수정일 셀과 `ArchiveViewerScreen`의
      수정일 셀에도 `overflow: TextOverflow.ellipsis`를 미리 추가해둠
    - 검증: `test/font_scale_test.dart`(컨트롤러 순환/영속성 단위테스트),
      `test/font_scale_overflow_test.dart`(글자 크기를 크게 한 채로 2-pane
      화면을 그려 오버플로 예외가 없는지 확인 — 위 버그를 처음 잡아낸
      테스트) 신규 추가. macOS 디버그 빌드에 `defaults write`로 글자 크기
      "크게" 상태를 강제해 창 단위 캡처로 실제 렌더링 확인

16. 폴더 새로고침 · 새 파일 생성 — **완료** (사용자 요청):
    - 새로고침: 각 패널 툴바에 아이콘 버튼 추가(뒤로/앞으로/상위폴더
      옆), `Ctrl+R`/`Cmd+R` 단축키도 추가. 실제 재조회 로직은 이미 있던
      `PaneController.refresh()`를 그대로 노출한 것 — 지금까지는 파일
      작업 뒤 내부적으로만 호출됐음. 처음엔 매칭되는 새 아이콘이 없어
      Material `Icons.refresh` 사용했다가, 사용자가 `icons8-refresh.svg`를
      추가로 받아와 `ToolIcon`으로 교체
    - 새 파일: F-바에 "새 파일" 버튼 추가 (F7 새 폴더 바로 옆, 전용 F키는
      없음 — 압축/속성/패턴선택처럼 F키 없이 버튼만 있는 기존 항목과
      같은 패턴). `createFolder`와 완전히 같은 구조로 로컬/FTP/SFTP/
      WebDAV 4개 백엔드 모두 지원:
      - 로컬: `File(path).create()`
      - SFTP: `client.open(path, mode: create|write|truncate)` 후 close
      - WebDAV: `client.write(path, Uint8List(0))`
      - FTP: `client.uploadData(Uint8List(0), name)` — ftpconnect는 로컬
        파일 없이 메모리 바이트를 바로 올리는 API가 있어 임시 파일 불필요
    - 검증: `file_operation_service_test.dart`에 로컬 `createFile` 단위
      테스트 추가, `ftp_integration_test.dart`/`sftp_integration_test.dart`/
      `webdav_integration_test.dart`에 각각 "새 파일 생성" 통합테스트
      추가(3개 프로토콜 전부 실제 로컬 테스트 서버로 검증 — createFolder와
      동일한 검증 수준). 전체 테스트 95개 통과, macOS 디버그 빌드로 새
      새로고침 아이콘과 "새 파일" 버튼 렌더링을 창 단위 캡처로 확인

17. Bundle/Application ID를 `com.ptype.*`에서 `art.zoomon.*`로 변경 —
    **완료** (사용자 요청, 14번의 저작권 정리에 이어): 이 앱이 ptype
    조직과 무관하다는 게 이유. Developer ID 배포는 App ID를 Apple에 미리
    등록할 필요가 없어서 기술적으로도 문제없이 바꿀 수 있었음
    - macOS: `AppInfo.xcconfig`의 `PRODUCT_BUNDLE_IDENTIFIER`
      `com.ptype.daylightCommander` → `art.zoomon.daylightcommander`,
      `Runner.xcodeproj/project.pbxproj`의 RunnerTests 타깃도 동일하게
      맞춤
    - Linux: `linux/CMakeLists.txt`의 GTK `APPLICATION_ID`도
      `art.zoomon.daylightcommander`로 통일
    - Windows: 별도 App ID 개념이 없어 해당 없음. 다만 같은 작업 중
      `windows/installer.iss`의 `MyAppPublisher`가 아직 `com.ptype`로
      남아있던 걸 발견해 `jyahn`으로 같이 정리(14번에서 Runner.rc
      CompanyName은 이미 고쳤는데 설치 스크립트가 나중에 추가되며 누락됨)
    - **주의(문서화함, RELEASING.md 참고 필요 없음 — 그냥 알아둘 것)**:
      macOS/Linux는 앱 설정 저장소가 이 식별자를 키로 쓰므로, 기존
      사용자가 새 버전으로 업그레이드하면 로컬 설정(즐겨찾기·최근
      폴더·서버 프로필·테마/언어/글자크기)이 초기화된다 — macOS 기준
      "다른 앱"으로 인식되기 때문. 아직 사용자가 소수인 시점이라 사용자
      본인이 감수하기로 결정
    - 검증: `flutter analyze` 클린, 전체 테스트 95개 통과(로직 변경 없음),
      macOS 디버그 빌드 후 `defaults read .../Info CFBundleIdentifier`로
      새 식별자가 실제 빌드에 반영됐는지 확인, 앱 정상 실행 확인
