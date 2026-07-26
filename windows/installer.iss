; Inno Setup script for AI Usage (Windows)
[Setup]
AppName=AI Usage
AppId={{B7E1F1D0-3A44-4A6E-9E63-AIUSAGE00001}
AppVersion=1.0.0
AppPublisher=Atti
DefaultDirName={autopf}\AIUsage
DefaultGroupName=AI Usage
DisableProgramGroupPage=yes
OutputBaseFilename=AIUsage-Windows-Setup
OutputDir=..\dist
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Files]
Source: "..\flutter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\AI Usage"; Filename: "{app}\aiusage.exe"
Name: "{autodesktop}\AI Usage"; Filename: "{app}\aiusage.exe"

[Run]
Filename: "{app}\aiusage.exe"; Description: "Launch AI Usage"; Flags: nowait postinstall skipifsilent
