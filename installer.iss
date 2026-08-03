; Inno Setup script for Retroachievements Rom Manager (Windows).
; Builds a single setup.exe from the Flutter release folder.
; No code signing required. Installs per-user (no admin prompt).
;
; Compile from the repo root after `flutter build windows --release`:
;   iscc /DMyAppVersion=1.0.0 installer.iss
; Output: artifacts/windows_installer/rarm-setup.exe

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "Retroachievements Rom Manager"
#define MyAppExeName "rarm.exe"
#define MyAppPublisher "George Englezos"
#define MyAppURL "https://github.com/GeorgeEnglezos/retroachievements-rom-manager"
#define BuildDir "build\windows\x64\runner\Release"

[Setup]
AppId={{A7E3F9C2-4B1D-4E8A-9F6C-2D5B8E1A3C7F}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\RARM
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Per-user install -> no admin elevation, no UAC prompt.
PrivilegesRequired=lowest
OutputDir=artifacts\windows_installer
OutputBaseFilename=rarm-setup
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
