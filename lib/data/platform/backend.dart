import '../models/models.dart';
import '../models/query.dart';

/// یو فایل یا فولډر — د اکسپلورر لپاره.
class FsEntry {
  const FsEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.sizeBytes = 0,
    this.modified,
    this.childCount,
    this.isEventFolder = false,
    this.isHidden = false,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int sizeBytes;
  final DateTime? modified;

  /// د فولډرونو لپاره د توکو شمېر (که محاسبه شوی وي).
  final int? childCount;

  /// آیا دا فولډر یوه ثبت شوې پیښه ده؟ (`metadata.json` لري)
  final bool isEventFolder;

  /// آیا دا توکی پټ دی؟ (د وینډوز پټ صفت، یا د پروګرام خپل ثبت
  /// فایلونه). اکسپلورر یې یوازې هغه وخت ښیي چې «پټ فایلونه
  /// وښایه» فعال وي.
  final bool isHidden;

  MediaKind get kind => isDirectory ? MediaKind.other : MediaKind.ofPath(name);

  String get extension {
    final i = name.lastIndexOf('.');
    return i <= 0 ? '' : name.substring(i + 1).toLowerCase();
  }
}

/// د یوه ډرایو د ځای حالت — د سایډبار د پای بار لپاره.
///
/// د ۵TB بهرني هارډ لپاره دا مهم دی: کاروونکی باید وویني چې څومره
/// ځای پاتې دی، مخکې تر دې چې ډرایو ډک شي.
class DiskSpace {
  const DiskSpace({required this.totalBytes, required this.freeBytes});

  final int totalBytes;
  final int freeBytes;

  int get usedBytes => totalBytes - freeBytes;

  /// ۰٫۰ … ۱٫۰
  double get usedRatio =>
      totalBytes <= 0 ? 0 : (usedBytes / totalBytes).clamp(0.0, 1.0);

  bool get isValid => totalBytes > 0;

  static const unknown = DiskSpace(totalBytes: 0, freeBytes: 0);
}

/// د سکن پرمختګ راپور.
class ScanProgress {
  const ScanProgress({
    required this.scanned,
    required this.found,
    this.currentPath = '',
    this.done = false,
  });
  final int scanned;
  final int found;
  final String currentPath;
  final bool done;
}

/// د ډاشبورډ لنډیز.
class ArchiveStats {
  const ArchiveStats({
    this.eventCount = 0,
    this.attachmentCount = 0,
    this.totalBytes = 0,
    this.keywordCount = 0,
    this.personCount = 0,
    this.categoryCount = 0,
    this.mediaBreakdown = const {},
    this.weeklyActivity = const [],
    this.recentEvents = const [],
    this.ratingSpread = const {},
  });

  final int eventCount;
  final int attachmentCount;
  final int totalBytes;
  final int keywordCount;
  final int personCount;
  final int categoryCount;

  /// د فایلونو ډول → شمېر.
  final Map<MediaKind, int> mediaBreakdown;

  /// د تېرو ۷ ورځو فعالیت (د پیښو شمېر فی ورځ، زوړ تر نوي).
  final List<int> weeklyActivity;

  final List<EventMetadata> recentEvents;
  final Map<int, int> ratingSpread;
}

// ═══════════════════════════════════════════════════════════
//  د پلیټ‌فارم انتزاع
// ═══════════════════════════════════════════════════════════

/// **د پروګرام د ټولې ډیټا یوازینۍ دروازه.**
///
/// دوه تطبیقونه لري:
/// * `IoBackend` — وینډوز/لینکس: ریښتینی فایل سیسټم + SQLite FTS5
/// * `DemoBackend` — ویب: د یادښت دننه ډیټا، یوازې د نندارې لپاره
///
/// UI هیڅکله مستقیم `dart:io` نه کاروي — نو ازموینه او د ویب نندارې
/// دواړه اسانه دي.
abstract class ArchiveBackend {
  /// آیا دا تطبیق ریښتینی فایل سیسټم لري؟ (ویب کې `false`)
  bool get isReal;

  // ── تنظیمات ─────────────────────────────────────────────
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings s);

  // ── د آرشیف ریښه ────────────────────────────────────────
  /// آیا دا مسیر شته او لوستل کیږي؟
  Future<bool> pathExists(String path);

  /// د دې مسیر د ډرایو ټول/پاتې ځای. که معلوم نه شي، `DiskSpace.unknown`.
  Future<DiskSpace> diskSpace(String path);

  /// د کاروونکي څخه د فولډر غوښتنه (native picker).
  Future<String?> pickDirectory({String? initial});

  /// د کاروونکي څخه د فایلونو غوښتنه.
  Future<List<String>> pickFiles({List<String>? extensions});

  // ── ایندکس ──────────────────────────────────────────────
  /// د آرشیف بشپړ سکن او د ایندکس بیا جوړول.
  Stream<ScanProgress> rescan(String root);

  /// د ایندکس پرانیستل / جوړول.
  Future<void> openIndex(String root);

  /// دا آرشیف وروستی ځل کله سکن شوی؟ که هیڅکله، `null`.
  ///
  /// **ولې پکار ده؟** ځکه پروګرام باید **هر ځل** سکن ونه کړي.
  /// کاروونکي وویل: «یو ځل چې لومړي کې اسکن شي، بیا اسکن باید
  /// ضرورت نه وي — ترڅو چټک وي». نو پیل یوازې هغه وخت سکن کوي
  /// چې دا `null` وي؛ نور وخت ایندکس سیده کارول کیږي.
  Future<DateTime?> lastScanAt(String root);

  // ── پوښتنې ──────────────────────────────────────────────
  Future<List<EventMetadata>> search(EventQuery q);
  Future<FacetCounts> facets(EventQuery q);
  Future<ArchiveStats> stats();
  Future<EventMetadata?> eventById(String id);

  /// د پیښې محتوا (`content.json`) پر غوښتنه راولي — بلاکونه، فایلونه، لینکونه.
  ///
  /// د لټون او فلټر پر مهال دې ته اړتیا نشته، نو یوازې هغه وخت لوستل کیږي
  /// چې کاروونکی پیښه پرانیزي. که مخکې لوستل شوې وي، بیا نه لوستل کیږي.
  Future<EventMetadata> loadContent(EventMetadata e);

  // ── لیکل ────────────────────────────────────────────────
  /// یوه پیښه پر ډیسک ولیکه (`metadata.json` + `index.html`) او ایندکس تازه کړه.
  Future<void> saveEvent(EventMetadata e, {String? html});

  Future<void> deleteEvent(String id, {bool deleteFiles = false});

  /// د اتومات حالت لپاره د کال/میاشتې/ورځې فولډرونه جوړوي
  /// او د پیښې فولډر بېرته راګرځوي.
  Future<String> prepareEventFolder({
    required String root,
    required String title,
    required dateJdn,
    bool auto = true,
    String? manualParent,
  });

  /// یو فایل `attachments/` ته انتقالوي او نسبي مسیر یې راګرځوي.
  Future<Attachment> attachFile({
    required String eventFolder,
    required String sourcePath,
    bool move = true,
  });

  // ── لغتونه ──────────────────────────────────────────────
  Future<List<VocabTerm>> vocab(VocabKind kind);
  Future<void> addVocab(VocabKind kind, VocabTerm term);
  Future<void> deleteVocab(VocabKind kind, String name);

  /// یو نوم په ټوله میټاډیټا کې بدلوي — چټک او یو‌ځایي.
  Future<int> renameVocab(VocabKind kind, String from, String to);

  // ── فایل اکسپلورر ───────────────────────────────────────
  Future<List<FsEntry>> listDirectory(String path);
  Future<List<String>> rootDrives();
  Future<void> createFolder(String parent, String name);
  Future<void> renameEntry(String path, String newName);
  Future<void> deleteEntries(List<String> paths);
  Future<void> copyEntries(List<String> paths, String destination, {bool move = false});
  Future<void> openExternally(String path);
  Future<void> revealInFileManager(String path);

  /// د پیښې د پاڼې HTML لوستل (د پریویو لپاره).
  Future<String?> readHtml(String eventFolder);

  /// د جوړې شوې `index.html` لپاره د وزیر متن فونټ نسبي مسیر.
  ///
  /// فونټونه یو ځل د آرشیف ریښې کې ساتل کیږي، نه په هره پاڼه کې —
  /// نو زرګونه پیښې هم یوازې یو ځل ~۲۰۰KB نیسي. که چیرې و نه شي
  /// جوړېدای، `null` راګرځي او پاڼه د سیسټم فونټ کاروي.
  Future<String?> webFontDirFor(String eventFolder);

  /// د یوه فایل بایټونه — د انځور د پریویو لپاره.
  Future<List<int>?> readBytes(String path);

  /// بایټونه یوې لارې ته لیکي او هغه لار راګرځوي.
  ///
  /// د PDF اکسپورټ یې کاروي. په ویب کې کار نه کوي (فایل سیسټم
  /// نشته)، نو `null` راګرځوي.
  Future<String?> writeBytes(String path, List<int> bytes);

  /// **د اکسپورټ ډیفالټ پوښۍ** — که کاروونکي لا کوم مسیر نه وي
  /// ټاکلی.
  ///
  /// کاروونکي وویل: «اوسنی ډیفالټ مسیر باید د ډاکمنټ فولډر دننه
  /// «د آرشیف نهایي فایلونه» وي». پوښۍ که نه وي، جوړیږي.
  Future<String?> defaultExportDir();

  /// **د وینډوز خپل «Save As» ډایلوګ** — کاروونکی مسیر او نوم
  /// ټاکي، بیا فایل هلته لیکل کیږي.
  ///
  /// کاروونکي وویل: «کله چې اکسپورټ کوو نو د وینډوز د ثبت پاڼه
  /// راشي چې چیرته یې ثبت کړم». پخوا دوسیه چوپه د پیښې فولډر ته
  /// تله — او کاروونکي به نه پوهېده چیرې لاړه.
  ///
  /// راګرځي: د ثبت شوې دوسیې مسیر، یا `null` که کاروونکي لغوه
  /// کړه (یا په ویب کې چې ډایلوګ نشته).
  Future<String?> saveFileAs({
    required String fileName,
    required List<int> bytes,
    String? initialDirectory,
    String mimeType = 'application/octet-stream',
  });
}

// ═══════════════════════════════════════════════════════════
//  تنظیمات
// ═══════════════════════════════════════════════════════════

enum ThemeChoice {
  light('سپین'),
  dark('تیاره'),
  system('د سیستم مطابق');

  const ThemeChoice(this.label);
  final String label;

  static ThemeChoice fromName(String? n) => ThemeChoice.values
      .firstWhere((e) => e.name == n, orElse: () => ThemeChoice.system);
}

class AppSettings {
  AppSettings({
    this.archiveRoot,
    this.theme = ThemeChoice.system,
    this.calendar = 'shamsi',
    this.onboarded = false,
    this.gridSize = 3,
    this.showHiddenFiles = false,
    this.pashtoMonthNames = false,
    this.uiScale = 1.0,
    this.exportDir,
    this.licenseLocked = false,
    this.licenseLockedAt,
  });

  String? archiveRoot;
  ThemeChoice theme;

  /// `shamsi` | `qamari` | `miladi` — ډیفالټ نندارې تقویم.
  String calendar;

  bool onboarded;
  int gridSize;
  bool showHiddenFiles;

  /// د افغاني (وری/غویی) پرځای د دري (حمل/ثور) نومونه.
  bool pashtoMonthNames;

  /// **د پروګرام د هر څه اندازه.**
  ///
  /// ۱.۰ = عادي. تر یو ښکته یعنې هر څه وړوکي کیږي او په پرده کې
  /// زیات شیان ځای نیسي — لکه چې پر لوی سکرین یې ګورئ. تر یو
  /// پورته د لوستلو لپاره اسانه، خو لږ شیان ښکاري.
  double uiScale;

  /// **د اکسپورټ وروستی مسیر.**
  ///
  /// کاروونکي وویل: «کله چې د وينډوز اکسپلورر پرانیستل شي او
  /// کاروونکی یو مسیر انتخاب کړي، راتلونکی کې باید هماغه مسیر په
  /// ډیفالټ بڼه وي». که تش وي، `defaultExportDir()` کارول کیږي.
  String? exportDir;

  /// **آیا پروګرام تړل شوی دی؟**
  ///
  /// د کنټرول فایل (وګورئ `LicenseGate`) دا ټاکي. دلته یې ساتو، نو
  /// چې یو ځل تړل شو، بیا پرانیستل یې نه خلاصوي — یوازې د سرور
  /// نوې اجازه یې خلاصوي.
  bool licenseLocked;

  /// کله تړل شو؟ (ISO)
  String? licenseLockedAt;

  /// د منلو وړ کچې — د تنظیماتو پاڼه یې کاروي.
  static const List<(double, String)> scaleOptions = [
    (0.80, 'ډېر کوچنی'),
    (0.90, 'کوچنی'),
    (1.00, 'عادي'),
    (1.10, 'لوی'),
    (1.25, 'ډېر لوی'),
  ];

  Map<String, dynamic> toJson() => {
        'archiveRoot': archiveRoot,
        'theme': theme.name,
        'calendar': calendar,
        'onboarded': onboarded,
        'gridSize': gridSize,
        'showHiddenFiles': showHiddenFiles,
        'pashtoMonthNames': pashtoMonthNames,
        'uiScale': uiScale,
        'exportDir': exportDir,
        'licenseLocked': licenseLocked,
        'licenseLockedAt': licenseLockedAt,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        archiveRoot: j['archiveRoot'] as String?,
        theme: ThemeChoice.fromName(j['theme'] as String?),
        calendar: j['calendar'] as String? ?? 'shamsi',
        onboarded: j['onboarded'] as bool? ?? false,
        gridSize: (j['gridSize'] as num?)?.toInt() ?? 3,
        showHiddenFiles: j['showHiddenFiles'] as bool? ?? false,
        pashtoMonthNames: j['pashtoMonthNames'] as bool? ?? false,
        // د زړو تنظیماتو فایلونو لپاره ډیفالټ، او د ناسمو ارزښتونو
        // پر وړاندې ساتنه — ګنې یو ناسم عدد ټول UI ناکاره کوي.
        uiScale: ((j['uiScale'] as num?)?.toDouble() ?? 1.0).clamp(0.6, 1.6),
        exportDir: j['exportDir'] as String?,
        licenseLocked: j['licenseLocked'] as bool? ?? false,
        licenseLockedAt: j['licenseLockedAt'] as String?,
      );
}
