# Daylight Commander

Total Commander / Midnight Commander 스타일의 무료 2단(dual-pane) 데스크톱 파일
매니저입니다. Flutter로 만들었고 Windows, macOS, Linux를 지원합니다 (모바일은
대상이 아닙니다).

## 주요 기능

- **2단 패널 탐색**: 뒤로/앞으로/상위 폴더, 주소창 직접 입력, 드라이브 전환
- **다중 선택**: 마우스(클릭/Shift/Ctrl)와 키보드(방향키 커서 + Space) 모두 지원,
  전체 선택/반전, 패턴(`*.jpg`) 기반 선택
- **파일 작업**: 복사/이동/삭제(휴지통), 새 폴더, 이름변경, 압축·압축풀기(zip),
  진행률 표시, 충돌 시 스킵/덮어쓰기/이름변경/모두적용 선택
- **네트워크 드라이브**: SMB(OS 마운트), FTP, SFTP, WebDAV — 서버 프로필 저장
  (비밀번호는 절대 저장하지 않음)
- **내장 뷰어 (F3)**: 텍스트, 이미지, PDF, 오디오/비디오, Hex 덤프. 지원하지
  않는 형식은 OS 기본 앱으로 열기
- **더블클릭으로 열기**: Finder/탐색기처럼 더블클릭 시 OS가 연결해 둔 기본
  앱으로 파일 실행
- **편의 기능**: 즐겨찾기, 최근 방문 폴더, 폴더 비교 및 단방향 동기화, 속성/
  권한(rwx) 편집, 우클릭 컨텍스트 메뉴, 현재 폴더에서 터미널 열기
- **드래그앤드롭**: 패널 간 이동/복사, Finder/탐색기 → 앱으로 드래그해 복사
- **라이트/다크 테마**, 파일 형식별 컬러 아이콘

## 지원 플랫폼

Windows · macOS · Linux

## 시작하기

### 요구 사항

- Flutter SDK (`environment.sdk: ^3.13.1`, `pubspec.yaml` 참고)

### 의존성 설치

```bash
flutter pub get
```

### 실행

```bash
flutter run -d macos    # 또는 -d windows, -d linux
```

### 릴리스 빌드

```bash
flutter build macos --release    # 또는 windows/linux
```

## 테스트

```bash
flutter test
```

FTP/SFTP/WebDAV 클라이언트는 실제 로컬 서버를 띄워 통합 테스트합니다. 해당
프로토콜을 이 앱이 직접 구현하기 때문에 목(mock)만으로는 신뢰하기 어렵다고
판단했습니다. 아래 파이썬 패키지가 설치되어 있으면 통합 테스트가 실행되고,
없으면 자동으로 스킵됩니다.

```bash
pip3 install --user pyftpdlib asyncssh wsgidav cheroot
```

## 프로젝트 문서

- [`PLAN.md`](PLAN.md) — 기능 목록, MVP 우선순위(P0/P1/P2), 진행 현황
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — 아키텍처 설계와 주요 기술적 결정 근거
- [`UI_UX.md`](UI_UX.md) — 테마, 아이콘 시스템, 컴포넌트/단축키 가이드
