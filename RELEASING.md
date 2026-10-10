# 릴리스 만들기

Daylight Commander를 Windows/macOS/Linux용 설치 파일로 패키징해서 GitHub
Release로 배포하는 방법. 두 가지 경로가 있다.

- **A. GitHub Actions로 자동 빌드+릴리스** (추천 — Windows/Linux 빌드는
  이 macOS 개발 환경에서 직접 만들 수 없으므로 사실상 유일하게 세 플랫폼을
  전부 만드는 방법)
- **B. 로컬에서 수동으로 빌드+패키징** (macOS 바이너리만 이 머신에서 직접
  테스트하고 싶을 때)

둘 다 최종적으로는 `gh release create`로 GitHub Release를 만든다.

## 0. 버전 올리기

`scripts/bump-version.sh`가 `pubspec.yaml`의 버전과 빌드 번호를 함께 올린다
(빌드 번호는 릴리스마다 +1, 되돌리지 않는다 — conventions `versioning.md`).

```bash
scripts/bump-version.sh patch        # 1.4.1+20 -> 1.4.2+21
scripts/bump-version.sh minor        # 1.4.1+20 -> 1.5.0+21
scripts/bump-version.sh 1.5.0-rc.1   # 프리릴리스
git commit -am "chore(release): v1.4.2"
```

PR로 `main`에 병합한 뒤, **병합 커밋에** 태그를 만들어 push한다. 태그는 반드시
`v`로 시작하고 `pubspec.yaml`의 버전과 같아야 한다 — 다르면 워크플로의 `check`
잡이 멈춘다.

```bash
git switch main && git pull
git tag v1.4.2
git push origin v1.4.2
```

## A. GitHub Actions로 자동 빌드+릴리스 (추천)

`.github/workflows/release.yml`가 `v*.*.*` 형태의 태그가 push되면 자동으로:

1. **`check`** — 태그가 `pubspec.yaml` 버전과 같은지, `lib/app_identity.dart`의
   표시 이름이 `PRODUCT_NAME`과 같은지, 번역이 빠지지 않았는지 확인한다.
   하나라도 어긋나면 여기서 멈춘다.
2. **`build-macos` / `build-windows` / `build-linux`** 를 병렬로 돌린다
   (`macos-26` / `windows-latest` / `ubuntu-latest`).
3. **`release`** — 셋 다 성공했을 때만 GitHub Release 하나를 만든다.
   제목은 `Daylight Commander vX.Y.Z`. 하나라도 실패하면 릴리스가 만들어지지 않는다.

산출물 이름은 `<파일 이름>-<버전>-<os>-<arch>` 규칙이다
(conventions `packaging.md`): `DaylightCommander-1.4.2-macos-universal.dmg`,
`DaylightCommander-1.4.2-windows-x64-setup.exe`,
`DaylightCommander-1.4.2-linux-x64.tar.gz`, 그리고 `SHA256SUMS.txt`.
내려받은 뒤 `sha256sum -c SHA256SUMS.txt`(macOS는 `shasum -a 256 -c SHA256SUMS.txt
--ignore-missing`)로 검증할 수 있다. 앱 안의 업데이트 확인이 이 파일 이름과
`SHA256SUMS.txt`를 보고 내려받을 파일을 고르므로 **이름 규칙을 바꾸지 않는다.**

릴리스 노트는 `.github/release-notes-header.md`(플랫폼별 설치 안내)를 맨 앞에
붙이고, 그 뒤에 `--generate-notes`로 PR 목록을 자동으로 이어붙인다. 설치 안내를 바꾸려면
이 파일을 고치면 다음 릴리스부터 반영된다 (이미 나온 릴리스는 `gh release edit
<태그> --notes-file ...`로 직접 고쳐야 한다). 태그에 `-rc.N` 같은 접미사가 있으면
프리릴리스로 만들어진다.

각 설치 파일:

- **macOS**: DMG를 열어 앱을 Applications로 끌어다 놓는다. 서명 + 공증을 거친다.
- **Windows**: Inno Setup 설치 프로그램(서명 없음 — SmartScreen에서 "추가 정보 → 실행").
  `installer/windows/app.iss`의 `AppId`는 **절대 바꾸지 않는다** (바꾸면 다음 버전을
  다른 앱으로 인식해 업그레이드·제거가 깨진다). 설치 위치는 `Program Files\Daylight Commander`.
- **Linux**: tar.gz를 풀고 `./install.sh`를 실행하면 `~/.local`에 설치되어 앱 메뉴에 나타난다
  (`./install.sh --remove`로 제거).

태그 없이 빌드만 확인하고 싶다면 GitHub 웹 UI의 Actions → Release → **Run workflow**
버튼으로 수동 실행할 수 있다. 이 경우 `check`와 세 빌드까지만 돌고 **릴리스는 만들지
않는다.**

### 처음 설정할 때 확인할 것

- 저장소 **Settings → Actions → General → Workflow permissions**이
  "Read and write permissions"로 되어 있어야 마지막 단계(`gh release
  create`)가 릴리스를 만들 권한을 가진다. 기본값이 read-only인 조직/계정
  설정도 있으니 한 번은 확인이 필요하다.
- 워크플로가 쓰는 Flutter 버전은 `release.yml`의 `FLUTTER_VERSION`
  환경변수로 고정되어 있다(현재 `3.47.1`, 이 프로젝트를 개발한 버전과
  동일). Flutter를 업그레이드하면 이 값도 같이 올려준다.
- macOS 서명/공증에 필요한 GitHub Secrets 6개를 설정해야 한다 — 바로
  아래 "macOS 코드사이닝 · 공증 설정" 참고. 설정 전까지는 워크플로의
  macOS 잡이 그 단계에서 실패한다.

### macOS 코드사이닝 · 공증 설정 (최초 1회)

Apple Developer Program 멤버십(연 $99)과 **Developer ID Application**
인증서가 있어야 한다. 아래 값들은 전부 **본인만 다루고 저장소 Secrets에
직접 등록**해야 한다 — Claude나 다른 사람에게 인증서 파일·비밀번호·앱
암호를 전달하지 말 것.

1. **Developer ID Application 인증서를 .p12로 내보내기**
   - Xcode에서 이미 만들어 키체인에 있다면: Keychain Access 앱 → 로그인
     키체인 → "내 인증서"에서 `Developer ID Application: 이름 (팀ID)`을
     찾아 우클릭 → "내보내기" → `.p12` 형식, 내보낼 때 비밀번호를 하나
     정해 입력(이게 `MACOS_CERTIFICATE_PASSWORD`가 됨)
   - 아직 인증서가 없다면 Xcode → Settings → Accounts → 팀 선택 →
     "Manage Certificates" → `+` → "Developer ID Application"으로 생성한
     뒤 위 방법으로 내보낸다

2. **.p12를 base64로 인코딩**

   ```bash
   base64 -i DeveloperID.p12 | pbcopy
   ```

   (클립보드에 복사됨 — 이 값이 `MACOS_CERTIFICATE_P12_BASE64`)

3. **App-specific password 만들기** — [appleid.apple.com](https://appleid.apple.com)
   로그인 → 로그인 및 보안 → "앱 암호" → 새로 생성. **Apple ID 로그인
   비밀번호 자체가 아니라 이 앱 암호**를 쓴다 (`APPLE_ID_PASSWORD`)

4. **Team ID 확인** — [developer.apple.com/account](https://developer.apple.com/account)
   → Membership 탭에서 10자리 Team ID 확인 (`APPLE_TEAM_ID`)

5. **저장소에 Secrets 등록** (GitHub CLI 사용, 본인 터미널에서 직접 실행):

   ```bash
   gh secret set MACOS_CERTIFICATE_P12_BASE64   # 붙여넣기 프롬프트가 뜨면 2번 값 붙여넣기
   gh secret set MACOS_CERTIFICATE_PASSWORD     # 1번에서 정한 .p12 내보내기 비밀번호
   gh secret set MACOS_KEYCHAIN_PASSWORD        # CI 임시 키체인용 — 아무 문자열이나 새로 정해서 입력
   gh secret set APPLE_ID                       # Apple ID 이메일
   gh secret set APPLE_ID_PASSWORD              # 3번의 앱 암호
   gh secret set APPLE_TEAM_ID                  # 4번의 Team ID
   ```

   또는 GitHub 웹에서 **Settings → Secrets and variables → Actions →
   New repository secret**으로 하나씩 등록해도 된다.

6. 다음 릴리스 태그부터 CI가 자동으로 서명 → 공증 → DMG에 티켓 스테이플까지
   끝낸다. 결과물을 받은 사용자는 `xattr -cr` 없이 바로 실행할 수 있다.
   **이 파이프라인은 아직 실제 인증서로 검증된 적이 없으니, 다음 릴리스
   실행 결과(Actions 로그)를 꼭 확인할 것** — 서명 아이덴티티를 못 찾거나
   공증이 거부되면(예: 하드닝된 런타임과 충돌하는 서드파티 바이너리) 로그에
   원인이 나온다.

## B. 로컬에서 수동으로 빌드+패키징

CI 없이 지금 당장 이 머신에서 macOS 바이너리만 만들어보고 싶을 때, 또는
Windows/Linux 머신을 따로 갖고 있어서 거기서 직접 빌드할 때 쓰는 방법이다.

### macOS (이 머신에서 바로 가능)

```bash
flutter build macos --release
APP_PATH="build/macos/Build/Products/Release/Daylight Commander.app"
codesign --force --deep --sign - "$APP_PATH"
mkdir -p dist
hdiutil create -volname "Daylight Commander" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO dist/DaylightCommander-<버전>-macos.dmg
```

`hdiutil`/`codesign` 둘 다 macOS에 기본 내장되어 있어 별도 설치가 필요
없다. 결과물은 `dist/DaylightCommander-<버전>-macos.dmg`.

> **이 로컬 빌드는 애드혹 서명만 된다(다운받는 사람 배포용 아님)**: 위
> 명령은 `codesign --sign -`로 애드혹 서명만 하므로, 이 산출물을 다른
> 사람에게 그대로 배포하면 "손상되었습니다"/"확인되지 않은 개발자" 경고가
> 뜬다. 정식 배포용 DMG(서명 + Apple 공증까지 끝난 것)는 GitHub Actions
> 릴리스 파이프라인이 만든다 — 아래 "macOS 코드사이닝 · 공증 설정" 참고.
> 이 머신에서 직접 만든 걸 자기 자신만 테스트해볼 때는:
>
> ```bash
> xattr -cr "/Applications/Daylight Commander.app"
> ```
>
> 로 quarantine 속성을 지우면 실행된다 (경로는 실제로 옮긴 위치에 맞게).

### Windows (Windows 머신 필요)

[Inno Setup](https://jrsoftware.org/isinfo.php)이 설치되어 있어야 한다
(`choco install innosetup` 또는 공식 사이트에서 다운로드).

```powershell
flutter build windows --release
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DMyAppVersion=1.1.0 windows\installer.iss
```

`windows\installer.iss`가 `build\windows\x64\runner\Release` 폴더 전체를
묶어 `dist\DaylightCommander-<버전>-Setup.exe` 설치 마법사를 만든다 (시작 메뉴
바로가기, "앱 및 기능"에서 제거 가능). `/DMyAppVersion`은 설치 프로그램의
버전 표시용이라 생략해도 빌드는 되지만(기본값 `0.0.0`), 릴리스 CI는
`pubspec.yaml`의 버전을 읽어 자동으로 채운다.

`build\windows\` 아래 정확한 경로는 Flutter 버전에 따라
`build\windows\runner\Release`일 수도 있다(이 프로젝트는 Flutter 3.47.1
기준 `x64\runner\Release`로 확인됨) — 못 찾으면
`Get-ChildItem -Recurse -Directory -Filter Release build\windows`로 확인
하고 `installer.iss`의 `[Files]` 섹션 경로도 맞춰 고쳐야 한다.

### Linux (Linux 머신 필요)

```bash
flutter build linux --release
mkdir -p dist
tar -czf dist/DaylightCommander-<버전>-linux.tar.gz \
  -C build/linux/x64/release/bundle .
```

리눅스 빌드에는 `clang cmake ninja-build pkg-config libgtk-3-dev
libsecret-1-dev libmpv-dev`가 필요하다 (Ubuntu/Debian 기준 `sudo apt-get
install`). `libsecret-1-dev`는 `flutter_secure_storage`, `libmpv-dev`는
`media_kit`(오디오/비디오 뷰어) 플러그인이 요구하는데 둘 다 빠뜨리기
쉽다 — CMake가 "package not found"/링크 에러로 바로 알려준다.

tar.gz 대신 배포판을 가리지 않는 [AppImage](https://appimage.org/)나
Debian 패키지(`.deb`)로 만들 수도 있다 — 둘 다 이 프로젝트에는 아직 설정
되어 있지 않다 (`appimagetool`/`dpkg-deb` 필요, 향후 개선 항목).

### 수동으로 GitHub Release 올리기

로컬에서 만든 `dist/` 안의 파일들을 GitHub CLI로 바로 올릴 수 있다
(플랫폼별로 각자 다른 머신에서 만든 파일을 한곳에 모아서 한 번에
올려도 된다):

```bash
gh release create v1.0.0 \
  dist/DaylightCommander-<버전>-macos.dmg \
  dist/DaylightCommander-<버전>-Setup.exe \
  dist/DaylightCommander-<버전>-linux.tar.gz \
  --title "v1.0.0" \
  --generate-notes
```

파일 중 일부만 있어도(예: macOS만 로컬에서 만들었을 때) 그 파일만 넘기면
된다. 이미 만들어둔 태그가 없다면 `gh release create`가 태그도 함께
만들어 push해준다. 같은 태그로 이미 릴리스가 있다면 `gh release upload
v1.0.0 dist/...`로 파일만 추가할 수 있다.

## 향후 개선 여지

- Linux AppImage/.deb/.rpm 패키징
- Linux `.desktop` 파일 + 아이콘 설치 (현재 앱 아이콘은 macOS/Windows에만
  적용되어 있음 — PLAN.md 참고)
