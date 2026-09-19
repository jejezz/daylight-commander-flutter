; Inno Setup 스크립트 — Daylight Commander Windows 설치 파일.
; CI(.github/workflows/release.yml)가 `flutter build windows --release`
; 이후 이 스크립트를 컴파일해 DaylightCommander-Setup.exe를 만든다.
; 로컬에서 다시 만들 때는 저장소 루트에서 실행:
;   iscc /DMyAppVersion=1.1.0 windows\installer.iss
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "Daylight Commander"
#define MyAppExeName "daylight_commander.exe"
#define MyAppPublisher "com.ptype"

[Setup]
; 업그레이드 설치가 같은 앱으로 인식되도록 고정된 GUID를 쓴다 — 절대 바꾸지 말 것.
AppId={{ED59335F-BE3D-4478-9DF8-44F2DEA294DD}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=..\dist
OutputBaseFilename=DaylightCommander-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=runner\resources\app_icon.ico
WizardStyle=modern
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; flutter build windows --release 결과물(실행파일 + data\ + 플러그인 dll) 전체를 담는다.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
