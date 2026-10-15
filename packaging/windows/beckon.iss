; Beckon's installer for Windows, built with Inno Setup 6 (ISCC.exe, which GitHub's Windows runners have):
;
;   ISCC /DVersion=2.0.0 /DSource=C:\path\to\beckon.exe /DOutputDir=C:\path\to\dist ^
;        /DOutputName=beckon-v2.0.0-windows-x86_64-setup packaging\windows\beckon.iss
;
; It installs for the person who runs it only, so there is no administrator prompt, and it puts Beckon
; in the Start menu and in "Apps" with an uninstaller. Starting at sign-in is offered, and on by default,
; since a phone can only use a Beckon that is running.

#ifndef Version
  #define Version "0.0.0"
#endif
#ifndef Source
  #define Source "..\..\target\release\beckon.exe"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#ifndef OutputName
  #define OutputName "beckon-setup"
#endif

#define AppName "Beckon"
#define AppExe "beckon.exe"
; The key Windows reads at sign-in. The program writes the same entry when "Start at login" is switched on in its menu.
; "--background" is what it is started with then: quietly, with no page opening by itself.
#define RunKey "Software\Microsoft\Windows\CurrentVersion\Run"

[Setup]
; A fixed id: it is how a newer installer knows the older install is the same program, and replaces it.
AppId={{6E1F4C2A-5B7D-4E39-9A0C-3D8B7F21C4A6}
AppName={#AppName}
AppVersion={#Version}
AppVerName={#AppName} {#Version}
VersionInfoVersion={#Version}
VersionInfoDescription={#AppName} setup
AppPublisher=Om Singh
AppPublisherURL=https://github.com/omsingh02/beckon
AppSupportURL=https://github.com/omsingh02/beckon/issues
AppUpdatesURL=https://github.com/omsingh02/beckon/releases
DefaultDirName={autopf}\{#AppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile=..\icons\beckon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "autostart"; Description: "Start Beckon when I sign in to Windows"; GroupDescription: "Options:"

[Files]
Source: "{#Source}"; DestDir: "{app}"; DestName: "{#AppExe}"; Flags: ignoreversion
Source: "..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\THIRD_PARTY_LICENSES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"

[Registry]
Root: HKCU; Subkey: "{#RunKey}"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\{#AppExe}"" --background"; Tasks: autostart

[Run]
; The first start shows the page with the QR code. Not run by a silent install, which has nobody to show it to.
Filename: "{app}\{#AppExe}"; Description: "Open Beckon and show the QR code"; Flags: nowait postinstall skipifsilent
; An update that Beckon started itself (it passes /RELAUNCH=1) ends with the new program running again, quietly, as
; the old one was.
Filename: "{app}\{#AppExe}"; Parameters: "--background"; Flags: nowait skipifdoesntexist; Check: StartedByUpdate

[Code]
{ Beckon has no window to ask to close, so it is asked to quit the way its own menu does. }
procedure StopRunningBeckon();
var
  ResultCode: Integer;
  Exe: String;
begin
  Exe := ExpandConstant('{app}\{#AppExe}');
  if FileExists(Exe) then
    Exec(Exe, '--quit', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

{ True when Beckon itself ran this installer to update, with /RELAUNCH=1 on the command line. }
function StartedByUpdate(): Boolean;
begin
  Result := ExpandConstant('{param:RELAUNCH|0}') = '1';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  StopRunningBeckon();
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    StopRunningBeckon();
    { Whether the installer or the program made the entry that starts Beckon at sign-in, it goes. }
    RegDeleteValue(HKEY_CURRENT_USER, '{#RunKey}', '{#AppName}');
  end;
end;
