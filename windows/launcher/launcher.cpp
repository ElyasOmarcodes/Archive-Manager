// ═══════════════════════════════════════════════════════════════
//  د آرشیف چټک مدیر — یو واحد فایل لانچر
// ═══════════════════════════════════════════════════════════════
//
// **ولې دا فایل شته؟**
//
// Flutter د وینډوز لپاره یو فولډر جوړوي: `ArchiveManager.exe` +
// څو DLL + یو `data/` فولډر. که کاروونکی یوازې .exe کاپي کړي،
// پروګرام نه چلیږي. کاروونکي وغوښتل چې **یو واحد فایل** وي.
//
// **څنګه کار کوي؟**
//
// دا کوچنی پروګرام د اصلي پروګرام ټوله بسته (یو ZIP) خپل ځان
// دننه لري — د وینډوز د «resource» په بڼه. کله چې وچلیږي:
//
//   ۱. ګوري چې آیا مخکې یې ځان‌پرځای کړی دی
//      (`%LOCALAPPDATA%\Arvitch\<نسخه>`).
//   ۲. که نه وي: ZIP یو موقت ځای ته لیکي، د وینډوز خپل
//      `tar.exe` (وینډوز ۱۰ ۱۸۰۳+ کې شته) پرې چلوي، بیا موقت
//      فایل غورځوي.
//   ۳. اصلي `.exe` چلوي او پخپله وځي.
//
// **لومړی ځل** څو ثانیې نیسي؛ **له هغه روسته** سمدستي پیلیږي،
// ځکه بیا ځان‌پرځای کولو ته اړتیا نشته.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>

#include <string>

// د جوړونې پر مهال ټاکل کیږي (‎/D APP_VERSION=...)
#ifndef APP_VERSION
#define APP_VERSION "0.0.0"
#endif
#ifndef APP_EXE
#define APP_EXE "ArchiveManager.exe"
#endif

// د کمانډ‌لاین څخه راغلي متنونه باریک (narrow) دي، خو دلته هر څه
// پراخ (wide) دي — نو یې اړوو. دوه پوړه اړین دي، ګنې `L` به پر
// خپله د ماکرو پر نوم ولګیږي، نه پر ارزښت یې.
#define WIDEN2(x) L##x
#define WIDEN(x) WIDEN2(x)
#define W_APP_VERSION WIDEN(APP_VERSION)
#define W_APP_EXE WIDEN(APP_EXE)

static void Fail(const wchar_t* msg) {
  MessageBoxW(nullptr, msg, L"د آرشیف چټک مدیر", MB_ICONERROR | MB_OK);
}

/// `%LOCALAPPDATA%\Arvitch\<نسخه>`
static std::wstring InstallDir() {
  PWSTR base = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &base))) {
    return L"";
  }
  std::wstring dir(base);
  CoTaskMemFree(base);
  dir += L"\\Arvitch\\v";
  dir += W_APP_VERSION;
  return dir;
}

static bool FileExists(const std::wstring& p) {
  DWORD a = GetFileAttributesW(p.c_str());
  return a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY);
}

/// `%LOCALAPPDATA%\Arvitch` — د ټولو نسخو پلار فولډر.
static std::wstring BaseDir() {
  PWSTR base = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &base))) {
    return L"";
  }
  std::wstring dir(base);
  CoTaskMemFree(base);
  dir += L"\\Arvitch";
  return dir;
}

/// یو فولډر له ټولو محتویاتو سره غورځوي (پرته له پوښتنې).
static void DeleteTree(const std::wstring& dir) {
  // `SHFileOperationW` دوه‌ځله-صفر پای ته اړتیا لري.
  std::wstring from = dir;
  from.push_back(L'\0');
  SHFILEOPSTRUCTW op{};
  op.wFunc = FO_DELETE;
  op.pFrom = from.c_str();
  op.fFlags = FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT;
  SHFileOperationW(&op);
}

/// **زاړه نسخې پاکوي.**
///
/// هر ځل چې نوې نسخه ځان‌پرځای کوي، یو نوی `v<نسخه>` فولډر
/// جوړیږي. پرته له دې، به هره اپډیټ ~۴۰MB پاتې شونې پرېښوده.
/// نو د نوې نسخې تر بریالي ځای‌پرځای کولو **روسته**، نور یې
/// غورځوو — ډیټا او تنظیمات دلته نه دي (هغه په `%APPDATA%` او د
/// آرشیف پر ډرایو کې دي)، نو هیڅ نه ورکیږي.
static void CleanupOldVersions(const std::wstring& keep) {
  const std::wstring base = BaseDir();
  if (base.empty()) return;

  WIN32_FIND_DATAW fd{};
  HANDLE h = FindFirstFileW((base + L"\\*").c_str(), &fd);
  if (h == INVALID_HANDLE_VALUE) return;
  do {
    if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;
    const std::wstring name = fd.cFileName;
    if (name == L"." || name == L".." || name == keep) continue;
    if (name.empty() || name[0] != L'v') continue;  // یوازې د نسخو فولډرونه
    DeleteTree(base + L"\\" + name);
  } while (FindNextFileW(h, &fd));
  FindClose(h);
}

/// د ټولو منځنیو فولډرونو سره لار جوړوي.
static bool MakeDirs(const std::wstring& path) {
  for (size_t i = 3; i <= path.size(); ++i) {
    if (i == path.size() || path[i] == L'\\') {
      std::wstring part = path.substr(0, i);
      if (!CreateDirectoryW(part.c_str(), nullptr) &&
          GetLastError() != ERROR_ALREADY_EXISTS) {
        return false;
      }
    }
  }
  return true;
}

/// دننه پروت ZIP یوې لارې ته لیکي.
static bool WritePayload(const std::wstring& to) {
  // **پام:** `RT_RCDATA` د `MAKEINTRESOURCE(10)` په بڼه تعریف
  // شوی، او هغه پخپله د `UNICODE` له تعریف سره تړلی دی. که
  // `UNICODE` تعریف نه وي، ANSI بڼه راځي او `FindResourceW`
  // یې نه مني. نو پراخه بڼه یې په ښکاره ډول کاروو.
  HRSRC res = FindResourceW(nullptr, MAKEINTRESOURCEW(1),
                            MAKEINTRESOURCEW(10));  // RT_RCDATA
  if (!res) return false;
  HGLOBAL h = LoadResource(nullptr, res);
  if (!h) return false;
  void* data = LockResource(h);
  DWORD size = SizeofResource(nullptr, res);
  if (!data || size == 0) return false;

  HANDLE f = CreateFileW(to.c_str(), GENERIC_WRITE, 0, nullptr,
                         CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE) return false;
  DWORD wrote = 0;
  BOOL ok = WriteFile(f, data, size, &wrote, nullptr);
  CloseHandle(f);
  return ok && wrote == size;
}

/// یو پروګرام پټ چلوي او د پای انتظار کوي.
static bool RunHidden(const std::wstring& cmd) {
  STARTUPINFOW si{};
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESHOWWINDOW;
  si.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION pi{};

  // `CreateProcessW` دویم دلیل بدلولی شي، نو باید بدلېدونکی وي.
  // په C++14 کې `.data()` یو `const wchar_t*` راګرځوي، نو
  // `&buf[0]` کاروو — هغه په هره نسخه کې کار کوي.
  std::wstring mutable_cmd = cmd;
  if (!CreateProcessW(nullptr, &mutable_cmd[0], nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
    return false;
  }
  WaitForSingleObject(pi.hProcess, INFINITE);
  DWORD code = 1;
  GetExitCodeProcess(pi.hProcess, &code);
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  return code == 0;
}

int APIENTRY wWinMain(HINSTANCE, HINSTANCE, LPWSTR lpCmdLine, int) {
  const std::wstring dir = InstallDir();
  if (dir.empty()) {
    Fail(L"د AppData لار ونه موندل شوه.");
    return 1;
  }
  const std::wstring exe = dir + L"\\" + W_APP_EXE;

  // ── لومړی ځل: ځان‌پرځای کول ──
  if (!FileExists(exe)) {
    if (!MakeDirs(dir)) {
      Fail(L"د ځای‌پرځای کولو فولډر جوړ نه شو.");
      return 1;
    }

    wchar_t tmpDir[MAX_PATH];
    GetTempPathW(MAX_PATH, tmpDir);
    wchar_t tmpFile[MAX_PATH];
    if (!GetTempFileNameW(tmpDir, L"arv", 0, tmpFile)) {
      Fail(L"موقت فایل جوړ نه شو.");
      return 1;
    }
    std::wstring zip(tmpFile);

    if (!WritePayload(zip)) {
      DeleteFileW(zip.c_str());
      Fail(L"دننه پروته بسته ولیکل نه شوه.");
      return 1;
    }

    // د وینډوز خپل tar (bsdtar) ZIP هم پېژني.
    std::wstring cmd = L"tar.exe -xf \"" + zip + L"\" -C \"" + dir + L"\"";
    const bool ok = RunHidden(cmd);
    DeleteFileW(zip.c_str());

    if (!ok || !FileExists(exe)) {
      Fail(L"بسته راوویستل نه شوه.\n\n"
           L"دا پروګرام وینډوز ۱۰ (۱۸۰۳) یا نوې ته اړتیا لري.");
      return 1;
    }

    // نوې نسخه چمتو ده — زاړه یې اوس غورځوو.
    CleanupOldVersions(std::wstring(L"v") + W_APP_VERSION);
  }

  // ── اصلي پروګرام چلوو ──
  //
  // د کاري فولډر یې د ځان‌پرځای شوې بستې دننه ټاکو، نو خپل
  // `data/` فولډر ومومي.
  std::wstring cmd = L"\"" + exe + L"\"";
  if (lpCmdLine && *lpCmdLine) {
    cmd += L" ";
    cmd += lpCmdLine;
  }

  STARTUPINFOW si{};
  si.cb = sizeof(si);
  PROCESS_INFORMATION pi{};
  if (!CreateProcessW(nullptr, &cmd[0], nullptr, nullptr, FALSE, 0,
                      nullptr, dir.c_str(), &si, &pi)) {
    Fail(L"پروګرام پیل نه شو.");
    return 1;
  }
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  return 0;
}
