; ============================================================
; PREREQUISITE: Build Ghostty before running this script.
;   cd ..\src
;   zig build -Doptimize=ReleaseFast
; This populates src\zig-out\bin\ with ghostty.exe and ghostty-vt.dll.
; ============================================================

#define MyAppName "Ghostty"
#define MyAppVersion "1.3.0-dev"
#define MyAppPublisher "Ghostty Contributors"
#define MyAppURL "https://ghostty.org"
#define MyAppExeName "ghostty.exe"
#define SrcDir "..\src\zig-out"

[Setup]
AppId={{A7B3C2D4-E5F6-4789-ABCD-EF0123456789}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Ghostty
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile={#SourcePath}LICENSE.txt
OutputDir={#SourcePath}output
OutputBaseFilename=ghostty-windows-{#MyAppVersion}-x64-setup
SetupIconFile={#SourcePath}ghostty.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\bin\{#MyAppExeName}
UninstallDisplayName={#MyAppName} {#MyAppVersion}
ChangesEnvironment=yes
CloseApplications=yes
CloseApplicationsFilter=ghostty.exe
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon";    Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "addtopath";      Description: "Add Ghostty to the PATH environment variable"; GroupDescription: "System integration:"
Name: "windowsterminal"; Description: "Register as a Windows Terminal profile"; GroupDescription: "System integration:"; Flags: unchecked

[Files]
; Main executable and DLL — restartreplace handles locked files gracefully
Source: "{#SrcDir}\bin\{#MyAppExeName}"; DestDir: "{app}\bin"; Flags: ignoreversion restartreplace uninsrestartdelete
Source: "{#SrcDir}\bin\ghostty-vt.dll";  DestDir: "{app}\bin"; Flags: ignoreversion restartreplace uninsrestartdelete

; Ghostty resources (themes, shell integration)
Source: "{#SrcDir}\share\ghostty\*"; DestDir: "{app}\share\ghostty"; Flags: ignoreversion recursesubdirs createallsubdirs

; Terminfo (required for resources dir detection)
Source: "{#SrcDir}\share\terminfo\*"; DestDir: "{app}\share\terminfo"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";           Filename: "{app}\bin\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";     Filename: "{app}\bin\{#MyAppExeName}"; Tasks: desktopicon

[Dirs]
; Create user config directory
Name: "{userappdata}\ghostty"

[Code]
// ---------------------------------------------------------------
// PATH helpers — add/remove only our entry, never touch the rest
// ---------------------------------------------------------------

function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(
    HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Param + ';', ';' + OrigPath + ';') = 0;
end;

procedure RemovePath(Param: string);
var
  OrigPath, NewPath: string;
  P: Integer;
begin
  if not RegQueryStringValue(
    HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then exit;

  // Remove ';Param' or 'Param;' from the PATH string
  NewPath := OrigPath;
  P := Pos(';' + Param, NewPath);
  if P > 0 then
    Delete(NewPath, P, Length(';' + Param))
  else begin
    P := Pos(Param + ';', NewPath);
    if P > 0 then
      Delete(NewPath, P, Length(Param + ';'))
    else begin
      P := Pos(Param, NewPath);
      if P > 0 then
        Delete(NewPath, P, Length(Param));
    end;
  end;

  if NewPath <> OrigPath then
    RegWriteExpandStringValue(
      HKEY_LOCAL_MACHINE,
      'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
      'Path', NewPath);
end;

// ---------------------------------------------------------------
// Windows Terminal fragment
// ---------------------------------------------------------------

procedure CreateWindowsTerminalFragment();
var
  FragmentDir, FragmentFile, Json: string;
begin
  FragmentDir := ExpandConstant('{localappdata}\Microsoft\Windows Terminal\Fragments\Ghostty');
  if not DirExists(FragmentDir) then
    ForceDirectories(FragmentDir);
  FragmentFile := FragmentDir + '\ghostty.json';
  Json :=
    '{' + #13#10 +
    '  "profiles": [' + #13#10 +
    '    {' + #13#10 +
    '      "name": "Ghostty",' + #13#10 +
    '      "commandline": "' + ExpandConstant('{app}\bin\ghostty.exe') + '",' + #13#10 +
    '      "icon": "' + ExpandConstant('{app}\bin\ghostty.ico') + '",' + #13#10 +
    '      "guid": "{a7b3c2d4-e5f6-4789-abcd-ef0123456789}"' + #13#10 +
    '    }' + #13#10 +
    '  ]' + #13#10 +
    '}';
  SaveStringToFile(FragmentFile, Json, False);
end;

procedure RemoveWindowsTerminalFragment();
var
  FragmentFile: string;
begin
  FragmentFile := ExpandConstant('{localappdata}\Microsoft\Windows Terminal\Fragments\Ghostty\ghostty.json');
  if FileExists(FragmentFile) then
    DeleteFile(FragmentFile);
end;

// ---------------------------------------------------------------
// Install / uninstall hooks
// ---------------------------------------------------------------

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then begin
    if WizardIsTaskSelected('addtopath') then
      if NeedsAddPath(ExpandConstant('{app}\bin')) then
        RegWriteExpandStringValue(
          HKEY_LOCAL_MACHINE,
          'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
          'Path',
          ExpandConstant('{app}\bin') + ';{olddata}');
    if WizardIsTaskSelected('windowsterminal') then
      CreateWindowsTerminalFragment();
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then begin
    RemovePath(ExpandConstant('{app}\bin'));
    RemoveWindowsTerminalFragment();
  end;
end;
