#define MyAppName "Bnwasal Admin"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Bnwasal"
#define MyAppURL "https://bnwasal.com"
#define MyAppExeName "admin_bnwasal.exe"

[Setup]
; معرف فريد للمثبت لضمان تسجيله بشكل صحيح في نظام الويندوز
AppId={{9FDF9B7A-E5F6-4F1A-B47A-362B2C1B4DF1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; إظهار أيقونة التطبيق في لوحة التحكم عند إلغاء التثبيت
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=..\build\windows\installer
OutputBaseFilename=BnwasalAdminInstaller
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.ShortcutName=Bnwasal Admin
arabic.ShortcutName=بنواصل أدمن
english.LaunchApp=Launch Bnwasal Admin
arabic.LaunchApp=تشغيل بنواصل أدمن

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{cm:ShortcutName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{cm:ShortcutName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchApp}"; Flags: nowait postinstall skipifsilent
