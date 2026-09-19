## 설치 안내

### macOS

`DaylightCommander-macos.dmg`를 열고 `Daylight Commander.app`을 Applications
폴더로 옮긴 뒤 실행하세요.

**"손상되었습니다" 또는 "확인되지 않은 개발자" 경고가 뜨는 경우** — Apple
공증(notarization)을 받지 않은 빌드라서 인터넷에서 받은 파일에 자동으로
붙는 격리(quarantine) 속성 때문입니다. 터미널에서 아래 명령을 실행하면
해결됩니다:

```bash
xattr -cr "/Applications/Daylight Commander.app"
```

실행 후 다시 더블클릭하면 정상적으로 열립니다.

### Windows

`DaylightCommander-windows.zip` 압축을 풀고 `daylight_commander.exe`를
실행하세요. 서명되지 않은 실행 파일이라 SmartScreen 경고가 뜰 수
있습니다 — "추가 정보" → "실행"을 클릭하면 됩니다.

### Linux

`DaylightCommander-linux.tar.gz` 압축을 풀고 안의 실행 파일을 실행하세요.

---
