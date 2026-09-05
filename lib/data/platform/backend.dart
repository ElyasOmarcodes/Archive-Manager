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

  // ── پوښتنې ──────────────────────────────────────────────
  Future<List<EventMetadata>> search(EventQuery q);
  Future<FacetCounts> facets(EventQuery q);
  Future<ArchiveStats> stats();
  Future<EventMetadata?> eventById(String id);

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

  Map<String, dynamic> toJson() => {
        'archiveRoot': archiveRoot,
        'theme': theme.name,
        'calendar': calendar,
        'onboarded': onboarded,
        'gridSize': gridSize,
        'showHiddenFiles': showHiddenFiles,
        'pashtoMonthNames': pashtoMonthNames,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        archiveRoot: j['archiveRoot'] as String?,
        theme: ThemeChoice.fromName(j['theme'] as String?),
        calendar: j['calendar'] as String? ?? 'shamsi',
        onboarded: j['onboarded'] as bool? ?? false,
        gridSize: (j['gridSize'] as num?)?.toInt() ?? 3,
        showHiddenFiles: j['showHiddenFiles'] as bool? ?? false,
        pashtoMonthNames: j['pashtoMonthNames'] as bool? ?? false,
      );
}
