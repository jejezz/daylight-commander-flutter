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

`pubspec.yaml`의 `version:` 필드를 올린다 (`버전이름+빌드번호` 형식).

```yaml
version: 1.1.0+2
```

커밋하고 태그를 만든다. 태그는 반드시 `v`로 시작해야 아래 A 방식이 자동
실행된다.

```bash
git add pubspec.yaml
git commit -m "chore: 1.1.0으로 버전 올림"
git tag v1.1.0
git push origin main
git push origin v1.1.0
```

## A. GitHub Actions로 자동 빌드+릴리스 (추천)

`.github/workflows/release.yml`가 `v*.*.*` 형태의 태그가 push되면 자동으로:

1. `macos-latest`/`windows-latest`/`ubuntu-latest` 세 러너에서 각각
   `flutter build <platform> --release` 실행
2. macOS는 `.dmg`, Windows는 `.zip`, Linux는 `.tar.gz`로 패키징
3. 세 파일을 전부 첨부해 GitHub Release 하나를 생성 (릴리스 노트는
   `--generate-notes`로 커밋 로그에서 자동 생성)

위 "0. 버전 올리기"에서 태그를 push하면 그걸로 끝이다. GitHub 저장소의
**Actions** 탭에서 진행 상황을 볼 수 있고, 완료되면 **Releases** 탭에 새
릴리스가 올라와 있다.

태그 없이 지금 상태로 한 번 테스트해보고 싶다면 GitHub 웹 UI의 Actions →
Release → **Run workflow** 버튼으로 수동 실행할 수도 있다(이 경우
`manual-<타임스탬프>`라는 이름으로 릴리스가 만들어진다).

### 처음 설정할 때 확인할 것

- 저장소 **Settings → Actions → General → Workflow permissions**이
  "Read and write permissions"로 되어 있어야 마지막 단계(`gh release
  create`)가 릴리스를 만들 권한을 가진다. 기본값이 read-only인 조직/계정
  설정도 있으니 한 번은 확인이 필요하다.
- 워크플로가 쓰는 Flutter 버전은 `release.yml`의 `FLUTTER_VERSION`
  환경변수로 고정되어 있다(현재 `3.47.1`, 이 프로젝트를 개발한 버전과
  동일). Flutter를 업그레이드하면 이 값도 같이 올려준다.

## B. 로컬에서 수동으로 빌드+패키징

CI 없이 지금 당장 이 머신에서 macOS 바이너리만 만들어보고 싶을 때, 또는
Windows/Linux 머신을 따로 갖고 있어서 거기서 직접 빌드할 때 쓰는 방법이다.

### macOS (이 머신에서 바로 가능)

```bash
flutter build macos --release
mkdir -p dist
hdiutil create -volname "Daylight Commander" \
  -srcfolder build/macos/Build/Products/Release/daylight_commander.app \
  -ov -format UDZO dist/DaylightCommander-macos.dmg
```

`hdiutil`은 macOS에 기본 내장되어 있어 별도 설치가 필요 없다. 결과물은
`dist/DaylightCommander-macos.dmg`.

> **참고**: Apple Developer 서명이 없는 빌드라서 다른 사람 macOS에서 처음
> 열 때 "확인되지 않은 개발자" 경고가 뜬다. 받은 사람이 앱을 우클릭 →
> "열기"로 한 번 열어주거나, `System Settings → Privacy & Security`에서
> 허용해야 한다. 정식 배포를 하려면 Apple Developer Program 가입 후
> 코드사이닝/공증(notarization)이 필요하다 — 지금은 범위 밖으로 둔다.

### Windows (Windows 머신 필요)

```powershell
flutter build windows --release
mkdir dist -Force
Compress-Archive -Path build\windows\x64\runner\Release\* `
  -DestinationPath dist\DaylightCommander-windows.zip
```

`build\windows\` 아래 정확한 경로는 Flutter 버전에 따라
`build\windows\runner\Release`일 수도 있다 — 못 찾으면
`Get-ChildItem -Recurse -Directory -Filter Release build\windows`로 확인.

간단한 zip 배포 대신 진짜 설치 마법사(.exe)를 만들고 싶다면 [Inno
Setup](https://jrsoftware.org/isinfo.php)으로 `Release` 폴더 전체를 묶는
스크립트를 작성하는 방법이 있다 (이 프로젝트에는 아직 `.iss` 스크립트가
없음 — 필요해지면 추가).

### Linux (Linux 머신 필요)

```bash
flutter build linux --release
mkdir -p dist
tar -czf dist/DaylightCommander-linux.tar.gz \
  -C build/linux/x64/release/bundle .
```

리눅스 빌드에는 `clang cmake ninja-build pkg-config libgtk-3-dev`가 필요
하다 (Ubuntu/Debian 기준 `sudo apt-get install`).

tar.gz 대신 배포판을 가리지 않는 [AppImage](https://appimage.org/)나
Debian 패키지(`.deb`)로 만들 수도 있다 — 둘 다 이 프로젝트에는 아직 설정
되어 있지 않다 (`appimagetool`/`dpkg-deb` 필요, 향후 개선 항목).

### 수동으로 GitHub Release 올리기

로컬에서 만든 `dist/` 안의 파일들을 GitHub CLI로 바로 올릴 수 있다
(플랫폼별로 각자 다른 머신에서 만든 파일을 한곳에 모아서 한 번에
올려도 된다):

```bash
gh release create v1.0.0 \
  dist/DaylightCommander-macos.dmg \
  dist/DaylightCommander-windows.zip \
  dist/DaylightCommander-linux.tar.gz \
  --title "v1.0.0" \
  --generate-notes
```
```bash
gh release create v1.0.0 \
  dist/DaylightCommander-windows.zip \
  --title "v1.0.0" \
  --generate-notes
```
```bash
gh release create v1.0.0 \
  dist/DaylightCommander-linux.tar.gz \
  --title "v1.0.0" \
  --generate-notes
```

이미 만들어둔 태그가 없다면 `gh release create`가 태그도 함께 만들어
push해준다.

## 향후 개선 여지

- macOS 코드사이닝/공증 (Apple Developer Program 필요)
- Windows용 정식 설치 마법사 (Inno Setup 등)
- Linux AppImage/.deb/.rpm 패키징
- Linux `.desktop` 파일 + 아이콘 설치 (현재 앱 아이콘은 macOS/Windows에만
  적용되어 있음 — PLAN.md 참고)
