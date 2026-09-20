# Daylight Commander

[![Latest Release](https://img.shields.io/github/v/release/jejezz/daylight-commander-flutter?label=release)](https://github.com/jejezz/daylight-commander-flutter/releases/latest)
[![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)](#지원-플랫폼)
[![Built with Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**[English](README.en.md) | 한국어**

Total Commander / Midnight Commander 스타일의 **무료 2단(dual-pane) 데스크톱 파일
매니저**입니다. Flutter로 만들었고 Windows, macOS, Linux를 모두 지원합니다
(모바일은 대상이 아닙니다).

빠른 키보드 중심 조작, SMB/FTP/SFTP/WebDAV 네트워크 드라이브, 내장 뷰어,
폴더 비교·동기화까지 갖춘 클래식 파일 매니저를 목표로 합니다.

## 스크린샷

|                             라이트 테마                              |                              다크 테마                              |
| :--------------------------------------------------------------: | :--------------------------------------------------------------: |
| ![라이트 테마 2단 패널 화면](docs/screenshots/dual-pane-light.png) | ![다크 테마 2단 패널 화면](docs/screenshots/dual-pane-dark.png) |

파일 형식별 컬러 아이콘, 왼쪽/오른쪽 패널 각각 독립적인 경로 탐색, 앱바의
테마·언어 토글 버튼을 볼 수 있습니다.

## 주요 기능

### 탐색 · 선택
- **2단 패널 탐색**: 뒤로/앞으로/상위 폴더, 주소창 직접 입력, 드라이브 전환,
  컬럼(이름/크기/수정일) 클릭 정렬
- **다중 선택**: 마우스(클릭/Shift/Ctrl)와 키보드(방향키 커서 + Space) 모두
  지원, 전체 선택, 패턴(`*.jpg`) 기반 선택/해제
- **퀵서치**: 패널에 포커스한 채로 타이핑하면 이름에 포함된 항목만 즉시 필터링
- **즐겨찾기 · 최근 방문 폴더**: 자주 쓰는 경로를 저장하고 한 번에 이동

### 파일 작업
- 복사/이동(F5/F6, 충돌 시 스킵/덮어쓰기/이름변경/모두적용 선택), 삭제(F8,
  휴지통 또는 영구), 새 폴더(F7), 이름변경(F2), 진행률 표시 + 취소
- 압축/압축 풀기(zip) — **압축을 풀지 않고 내부 구조를 훑어보는 미리보기**도
  지원 (F3/우클릭 "보기")
- 속성 확인 및 읽기전용/rwx 권한 편집 (macOS·Linux는 `chmod`, Windows는
  `attrib`)
- Finder/탐색기 ↔ 앱 드래그앤드롭, 더블클릭 시 OS가 연결해 둔 기본 앱으로 실행

### 네트워크 드라이브
- **SMB** (OS 마운트 다이얼로그로 위임), **FTP**, **SFTP**, **WebDAV** — 순수
  Dart 클라이언트로 구현
- 서버 프로필 저장(호스트/포트/계정명만) — **비밀번호는 절대 저장하지 않음**

### 내장 뷰어 (F3)
- 텍스트, 이미지, PDF, 오디오/비디오, Hex 덤프
- 지원하지 않는 형식은 OS 기본 앱으로 열기 버튼 제공

### 폴더 비교 · 동기화
- 좌우 패널을 이름 기준으로 비교해 차이점 하이라이트
- **단방향 동기화**: 차이 나는 항목을 반대 패널로 일괄 복사
- **양방향 동기화**: 한쪽에만 있는 파일은 자동 복사하고, 양쪽에 다 있지만
  내용이 다른 파일은 파일마다 어느 쪽을 쓸지 하나씩 확인

### 그 외 편의 기능
- **라이트/다크 테마** 토글 (시스템 설정 따라가기도 지원)
- **다국어 지원 (한국어/영어)** — 앱바에서 바로 전환
- 우클릭 컨텍스트 메뉴, 현재 폴더에서 터미널 열기, 파일 형식별 컬러 아이콘

## 지원 플랫폼

Windows · macOS · Linux

## 다운로드 및 설치

빌드된 실행 파일은 [Releases 페이지](https://github.com/jejezz/daylight-commander-flutter/releases/latest)에서 받을 수 있습니다.

### macOS

1. `DaylightCommander-macos.dmg`를 열고 `Daylight Commander.app`을
   Applications 폴더로 드래그
2. **처음 실행할 때 "손상되었습니다" 또는 "확인되지 않은 개발자" 경고가
   뜨면** — Apple 공증(notarization)을 받지 않은 빌드라서 인터넷에서 받은
   파일에 자동으로 붙는 격리(quarantine) 속성 때문입니다. 터미널에서
   아래 명령을 실행하면 해결됩니다:

   ```bash
   xattr -cr "/Applications/Daylight Commander.app"
   ```

   실행 후 다시 더블클릭하면 정상적으로 열립니다.

### Windows

1. `DaylightCommander-Setup.exe`를 실행해 설치 마법사를 따라가세요
   (시작 메뉴 바로가기 생성, "앱 및 기능"에서 제거 가능)
2. 서명되지 않은 설치 파일이라 SmartScreen 경고가 뜰 수 있습니다 —
   "추가 정보" → "실행"을 클릭하면 됩니다

### Linux

1. `DaylightCommander-linux.tar.gz` 압축을 풀고 안의 실행 파일 실행

## 소스에서 빌드하기 (개발자용)

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

새 버전을 태그하고 GitHub Release로 배포하는 전체 절차는
[`RELEASING.md`](RELEASING.md)를 참고하세요.

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
- [`RELEASING.md`](RELEASING.md) — 설치 파일 빌드 및 GitHub Release 배포 방법

## 라이선스

[MIT License](LICENSE) — Copyright © 2026 jyahn
