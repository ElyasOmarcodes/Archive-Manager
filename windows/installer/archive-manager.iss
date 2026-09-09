; ═══════════════════════════════════════════════════════════════
;  د آرشیف چټک مدیر — د وینډوز نصب کوونکی (Inno Setup)
; ═══════════════════════════════════════════════════════════════
;
; کاروونکي وویل: «د نهایي محصول لپاره د Installer-based Multi-File
; Distribution ماډل غواړو … باید د پرمختللو پروګرامونو په څېر نصب
; شي، لکه فوټوشاپ».
;
; دا سکریپټ هماغه کوي: د Flutter بشپړه پوښۍ (exe + DLLونه +
; `data/`) نصبوي، شارټ‌کټونه جوړوي، او یو ریښتینی «Uninstall»
; ورکوي چې د وینډوز په «Apps & features» کې ښکاري.
;
; ## د اپډیټ لپاره څه مهم دي؟
;
; ۱. **`AppId` هیڅکله نه بدلیږي.** وینډوز له همدې پېژني چې دا
;    «هماغه پروګرام» دی — نو نوې نسخه پر زړې **باندې** نصبیږي،
;    نه ترڅنګ یې.
; ۲. **`CloseApplications=yes`** — که پروګرام روان وي، نصب کوونکی
;    یې په ښه توګه بندوي، نه چې فایلونه ونه شي لیکل.
; ۳. **د کاروونکي ډیټا دلته نشته.** تنظیمات په `%APPDATA%` کې دي،
;    ایندکس هم هلته، او آرشیف پر خپل ډرایو — نو نه اپډیټ او نه
;    حذف کول یې لمس کوي.
;
; جوړول:
;   ISCC.exe /DMyAppVersion=1.0.0 /DPayloadDir=..\..\build\windows\x64\runner\Release archive-manager.iss

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef PayloadDir
  #define PayloadDir "..\..\build\windows\x64\runner\Release"
#endif

#define MyAppName "د آرشیف چټک مدیر"
#define MyAppNameEn "Arvitch Archive Manager"
#define MyAppPublisher "ElyasOmar"
#define MyAppExe "ArchiveManager.exe"

[Setup]
; **دا GUID هیڅکله مه بدلوئ** — د اپډیټ ټوله کیسه پرې ولاړه ده.
AppId={{8F3A6C21-4B7E-4E63-9E2A-0D1C7A5B9E41}
AppName={#MyAppNameEn}
AppVersion={#MyAppVersion}
AppVerName={#MyAppNameEn} {#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/ElyasOmarcodes/Archive-Manager
AppSupportURL=https://github.com/ElyasOmarcodes/Archive-Manager/issues
AppUpdatesURL=https://github.com/ElyasOmarcodes/Archive-Manager/releases

DefaultDirName={autopf}\Arvitch\Archive Manager
DefaultGroupName=Arvitch
DisableProgramGroupPage=yes
DisableDirPage=no
AllowNoIcons=yes

; **پرته له UAC هم نصبیږي.** ډیفالټ: یوازې زما لپاره
; (`%LOCALAPPDATA%\Programs`) — نو اپډیټ هم پرته له ادمین پاسورډه
; کیږي. څوک چې «د ټولو کاروونکو لپاره» غواړي، د لومړۍ پاڼې څخه یې
; ټاکلی شي (بیا Program Files ته ځي).
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763

OutputBaseFilename=ArchiveManager-Setup-{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
UninstallDisplayName={#MyAppNameEn} {#MyAppVersion}

Compression=lzma2/ultra64
SolidCompression=yes
LZMANumBlockThreads=4
WizardStyle=modern

; که پروګرام روان وي، په ښه توګه یې بندوي — نو اپډیټ نه ماتیږي.
CloseApplications=yes
CloseApplicationsFilter=*.exe,*.dll
RestartApplications=no

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; ټوله پوښۍ — د Flutter خروجي: exe + DLLونه + data\
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppNameEn}"; Filename: "{app}\{#MyAppExe}"
Name: "{group}\{cm:UninstallProgram,{#MyAppNameEn}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppNameEn}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "{cm:LaunchProgram,{#MyAppNameEn}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; د پروګرام خپل جوړ شوي فایلونه (لکه د لاګ فایل) — د کاروونکي
; ډیټا دلته نشته، هغه په `%APPDATA%` او د آرشیف پر ډرایو ده.
Type: filesandordirs; Name: "{app}\data\flutter_assets\.cache"
