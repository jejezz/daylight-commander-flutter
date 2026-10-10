# Daylight Commander

Total Commander · Midnight Commander 스타일의 무료 2단(듀얼 패널) 데스크톱 파일 매니저
(Windows / macOS / Linux). 로컬 파일, SMB·FTP·SFTP·WebDAV 네트워크 드라이브, 내장 뷰어,
폴더 비교·동기화를 키보드 중심으로 다룬다.

릴리스·버전·패키징·정보 창·아이콘·라이선스·UI/UX·글꼴·언어·테마는
https://github.com/jejezz/application-release-templates/tree/main/conventions
규약을 따른다. 이 앱에 적용된 규약 버전: conventions-v1 (미적용: README, 하드코딩 한국어 문자열 28개)

- 표시 이름 `Daylight Commander`, 파일 이름 `DaylightCommander`, 패키지 `daylight_commander`,
  식별자 `art.zoomon.daylightcommander`, 저장소 `daylight-commander-flutter`.
  식별자와 `installer/windows/app.iss`의 `AppId`는 릴리스 후 바꾸지 않는다.
- 구조는 [ARCHITECTURE.md](ARCHITECTURE.md)(presentation → application → domain ← data, 상태관리
  Riverpod), 기능 범위는 [PLAN.md](PLAN.md), 화면은 [UI_UX.md](UI_UX.md), 릴리스 절차는
  [RELEASING.md](RELEASING.md).
- 테마·언어는 `lib/settings/`(`AppSettings`, 저장 키 `theme_mode`·`app_locale`), 글자 크기만
  Riverpod(`fontScaleProvider`, 키 `font_scale`)이다. 앱 바 오른쪽 끝은 `글자 크기 | 테마 | 언어 | 정보`.
- 앱 고유 정보 창 문구는 `lib/about/daylight_about.dart`에 두고, 공통 `about_dialog.dart` 는
  템플릿과 같게 둔다.
- 번들 글꼴은 SeoulNamsan 400/700/800 (300 은 뺐다). 대체 글꼴은 `AppFonts.fallback`.
- 사용자 대상 문자열은 ARB(`lib/l10n/app_ko.arb`, `app_en.arb`)에 둔다 — 아직 `lib/` 에 남은
  한국어 문자열 28개는 옮기는 중이다 (`python3 tool/audit_app.py` 의 `l10n.hardcoded`).
