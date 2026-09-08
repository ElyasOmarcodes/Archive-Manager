import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/license/license_gate.dart';
import '../../core/theme/tokens.dart';
import '../models/models.dart';
import '../models/query.dart';
import '../platform/backend.dart';
import '../platform/demo_backend.dart';

/// د پروګرام هغه پاڼې چې سایډبار کې ښکاري.
///
/// هر یو خپل رنګ لري — نو سایډبار کې د آیکن کاشۍ رنګینه وي او
/// کاروونکی یې په یوه نظر وپېژني.
enum AppPage {
  dashboard('ډاشبورډ', Icons.space_dashboard_rounded, TileTone.blue),
  // د ډاشبورډ ایکن هم د پینلونو ګریډ و — دواړه یو شان ښکارېدل.
  // «پیښې» اوس د خبري پیښې خپل ایکن لري.
  events('پیښې', Icons.newspaper_rounded, TileTone.orange),
  explorer('اکسپلورر', Icons.folder_open_rounded, TileTone.green),
  keywords('کلیدي کلمې', Icons.sell_rounded, TileTone.teal),
  categories('کټګورۍ', Icons.category_rounded, TileTone.pink),
  persons('اشخاص', Icons.groups_rounded, TileTone.purple),
  settings('تنظیمات', Icons.settings_rounded, TileTone.slate);

  const AppPage(this.title, this.icon, this.tone);
  final String title;
  final IconData icon;
  final TileTone tone;
}

/// د پروګرام د حالت مرکز — UI له همدې لوستل کوي.
class AppState extends ChangeNotifier {
  AppState(this.backend);

  final ArchiveBackend backend;

  // ── تنظیمات ─────────────────────────────────────────────
  AppSettings settings = AppSettings();

  ThemeMode get themeMode => switch (settings.theme) {
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
        ThemeChoice.system => ThemeMode.system,
      };

  CalendarKind get calendar => CalendarKind.values.firstWhere(
      (c) => c.name == settings.calendar,
      orElse: () => CalendarKind.shamsi);

  // ── د فعالېدو دروازه ────────────────────────────────────
  //
  // پروګرام په پس‌منظر کې د کنټرول فایل څاري. که هلته `false`
  // ولیکل شي، سمدلاسه د اکسپایر پاڼې ته ځي — او تړلی پاتې کیږي تر
  // څو چې بیا اجازه ورنکړل شي.
  late final LicenseGate license = LicenseGate(onChanged: _saveLock)
    ..addListener(notifyListeners);

  /// د سکرین‌شاټ/ډیزاین لپاره:
  /// `flutter build web --dart-define=FORCE_LOCKED=true`
  static const bool _forceLocked = bool.fromEnvironment('FORCE_LOCKED');

  bool get locked => license.locked || _forceLocked;

  Future<void> _saveLock(bool locked, DateTime? at) async {
    settings.licenseLocked = locked;
    settings.licenseLockedAt = at?.toIso8601String();
    await backend.saveSettings(settings);
  }

  // ── د پیل حالت ──────────────────────────────────────────
  bool booting = true;

  /// آیا مخکینی مسیر ورک دی؟ (د بیا هڅې پاڼه)
  bool rootMissing = false;
  String? missingPath;

  // ── ناوبري ──────────────────────────────────────────────
  AppPage page = AppPage.dashboard;
  bool sidebarExpanded = true;

  /// که ناستې (non-null) وي، د پیښې ایډیټر پرانیستل شوی دی.
  EventMetadata? editing;
  bool previewMode = false;

  /// کله چې د بلې پاڼې څخه اکسپلورر ته ځو، دا هغه فولډر دی چې
  /// اکسپلورر باید پرې پرانیستل شي.
  String? explorerTarget;

  // ── ډیټا ────────────────────────────────────────────────
  ArchiveStats stats = const ArchiveStats();
  List<EventMetadata> events = const [];
  FacetCounts facets = FacetCounts.empty;
  EventQuery query = const EventQuery();
  bool loading = false;

  ScanProgress? scan;

  /// د آرشیف د ډرایو ځای — د سایډبار د پای بار لپاره.
  DiskSpace disk = DiskSpace.unknown;

  // ═══════════════════════════════════════════════════════
  //  پیل
  // ═══════════════════════════════════════════════════════

  /// د پیل اوسنی ګام — د پیل پاڼه یې ښیي، نو کاروونکی پوهیږي چې
  /// پروګرام ژوندی دی او څه کوي.
  String bootStep = 'پیلیږي…';

  /// که پیل ناکام شي، دلته یې دلیل پروت وي — نه چې پروګرام
  /// چوپ‌چاپ ودریږي.
  String? bootError;

  void _step(String s) {
    bootStep = s;
    notifyListeners();
  }

  /// **د پروګرام پیل.**
  ///
  /// ## دوه قاعدې چې دلته ماتې شوې وې
  ///
  /// **۱. پیل هیڅکله د سکن انتظار نه کوي.** پخوا یې د آرشیف
  /// بشپړ رسکن ته انتظار کاوه: د ۵٬۰۰۰ پیښو آرشیف کې دا دقیقې
  /// نیسي، او د پیل پاڼه ټول هغه وخت بې‌حرکته ولاړه وه — لکه
  /// پروګرام چې هنګ شوی وي. اوس ایندکس پرانیستل کیږي (چټک دی)،
  /// موجوده ډیټا سمدلاسه ښکاره کیږي، او **سکن پس‌منظر ته ځي** —
  /// پرمختګ یې د سایډبار په پایښت کې ښکاري.
  ///
  /// **۲. هره تېروتنه نیول کیږي.** پخوا که ایندکس خراب و یا کوم
  /// فایل نه لوستل کېده، استثنا به پورته تللې وه او `booting`
  /// به هیڅکله غلط نه و — یعنې **د پیل پاڼه تلپاتې**. اوس هر
  /// ګام په `try` کې دی: پروګرام پرانیستل کیږي، او تېروتنه
  /// کاروونکي ته ښودل کیږي.
  Future<void> boot() async {
    try {
      _step('تنظیمات لوستل کیږي…');
      settings = await backend.loadSettings();

      // ساتل شوی لاک — که تړل شوی و، سمدلاسه تړلی پیلیږي.
      license.restore(
        locked: settings.licenseLocked,
        at: DateTime.tryParse(settings.licenseLockedAt ?? ''),
      );

      final root = settings.archiveRoot;

      if (settings.onboarded && root != null) {
        _step('د آرشیف مسیر ګورو…');
        if (await backend.pathExists(root)) {
          _step('ایندکس پرانیستل کیږي…');
          await _openRoot(root, rescan: false);
        } else {
          rootMissing = true;
          missingPath = root;
        }
      }
    } catch (e, st) {
      // پروګرام باید پرانیستل شي — که هر څه هم پېښ شوي وي.
      bootError = '$e';
      debugPrint('ARCHIVE-BOOT-ERROR: $e\n$st');
    }

    booting = false;
    notifyListeners();

    // د کنټرول فایل څارنه — چوپه، په پس‌منظر کې.
    if (!LicenseGate.isTestEnvironment) license.start();

    // ── سکن — یوازې که اړتیا وي ──
    //
    // کاروونکي وویل: «ولې هر ځل چې پروګرام خلاصوو ټول ډیټابیس
    // اسکن کیږي؟ … یو ځل چې لومړي کې اسکن شي، بیا اسکن باید
    // ضرورت نه وي، ترڅو چټک وي».
    //
    // سمه خبره ده. ایندکس **پر ډیسک** پاتې کیږي، نو دویم ځل یې
    // پرانیستل بس دي. نو:
    //
    // * **لومړی ځل** (یا نوی مسیر) → بشپړ سکن، په پس‌منظر کې
    // * **وروسته** → هیڅ سکن نه؛ پروګرام سمدلاسه چمتو دی
    // * کاروونکی هر وخت د ټایټل بار له تڼۍ سکن کولی شي — او
    //   هغه سکن هم پرګمنټ دی (یوازې بدل شوي فولډرونه لولي)
    final root = settings.archiveRoot;
    if (backend.isReal && !rootMissing && root != null) {
      lastScan = await backend.lastScanAt(root);
      if (lastScan == null) {
        unawaited(rescanArchive());
      } else {
        notifyListeners();
      }
    }
  }

  /// دا آرشیف وروستی ځل کله سکن شو؟ (د ټایټل بار د تڼۍ لپاره)
  DateTime? lastScan;

  Future<void> _openRoot(String root, {bool rescan = true}) async {
    await backend.openIndex(root);
    if (rescan) {
      await for (final p in backend.rescan(root)) {
        scan = p;
        notifyListeners();
      }
      scan = null;
    }
    await refresh();
  }

  /// د آرشیف ریښه ټاکي او پروګرام ته ننوځي.
  Future<void> setArchiveRoot(String root) async {
    settings.archiveRoot = root;
    settings.onboarded = true;
    rootMissing = false;
    missingPath = null;
    await backend.saveSettings(settings);
    notifyListeners();
    await _openRoot(root);
  }

  /// د «بیا هڅه» تڼۍ — ګورو چې آیا مسیر بېرته راغی.
  Future<bool> retryMissingRoot() async {
    final root = missingPath;
    if (root == null) return false;
    if (await backend.pathExists(root)) {
      await setArchiveRoot(root);
      return true;
    }
    notifyListeners();
    return false;
  }

  Future<void> rescanArchive() async {
    final root = settings.archiveRoot;
    if (root == null || scan != null) return;
    await for (final p in backend.rescan(root)) {
      scan = p;
      notifyListeners();
    }
    scan = null;
    lastScan = await backend.lastScanAt(root);
    await refresh();
  }

  // ═══════════════════════════════════════════════════════
  //  تازه کول
  // ═══════════════════════════════════════════════════════

  /// د یوې پاڼې کچه — څومره پیښې یو ځل راوړل کیږي.
  ///
  /// **ولې محدودیت شته؟** ځکه چې د ۵۰,۰۰۰ پیښو ټول لیست راوړل
  /// یعنې ۵۰,۰۰۰ ځله JSON پارس کول (~۸ ثانیې). خو محدودیت یوازې
  /// د **راوړلو** لپاره دی، نه د **ترتیب** لپاره — ترتیب د
  /// ډیټابیس دننه پر ټولو پایلو پلې کیږي، بیا یې لومړۍ پاڼه راځي.
  /// کله چې کاروونکی ښکته سکرول کړي، راتلونکې پاڼه پخپله راځي.
  static const int pageSize = 200;

  /// آیا لا نورې پایلې پاتې دي؟
  bool get hasMore => events.length < facets.total;

  /// د راتلونکې پاڼې بارول روان دي؟
  bool loadingMore = false;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    stats = await backend.stats();
    events = await backend.search(query.copyWith(limit: pageSize, offset: 0));
    facets = await backend.facets(query);
    final root = settings.archiveRoot;
    if (root != null) disk = await backend.diskSpace(root);
    loading = false;
    notifyListeners();
  }

  /// **راتلونکې پاڼه** — کله چې کاروونکی د لیست پای ته نږدې شي.
  ///
  /// ترتیب او فیلټر هماغه دي، یوازې `offset` مخته ځي — نو د لیست
  /// پرله‌پسې والی نه ماتیږي.
  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    final next = await backend
        .search(query.copyWith(limit: pageSize, offset: events.length));
    // د بارولو پر مهال کاروونکي فیلټر بدل کړی وي — پایله وغورځوه.
    if (loadingMore) {
      events = [...events, ...next];
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> setQuery(EventQuery q) async {
    query = q;
    loadingMore = false;
    await refresh();
  }

  Future<void> clearFilters() => setQuery(query.cleared());

  // ═══════════════════════════════════════════════════════
  //  ناوبري
  // ═══════════════════════════════════════════════════════

  /// اکسپلورر په ټاکلي فولډر کې پرانیزي — د پریویو له «داخلي» تڼۍ.
  void openInExplorer(String folder) {
    explorerTarget = folder;
    editing = null;
    previewMode = false;
    page = AppPage.explorer;
    notifyListeners();
  }

  /// اکسپلورر یې مصرفوي، نو بیا بیا نه پلې کیږي.
  String? consumeExplorerTarget() {
    final t = explorerTarget;
    explorerTarget = null;
    return t;
  }

  void go(AppPage p) {
    page = p;
    editing = null;
    previewMode = false;
    notifyListeners();
  }

  /// د تنظیماتو کومه ډله پرانیستې ده (۰ = بڼه … ۵ = جوړونکی).
  ///
  /// دلته یې ساتو، نه د پاڼې دننه: نو د ټایټل بار «په اړه» تڼۍ
  /// کولی شي مستقیم د جوړونکي ډلې ته ولاړه شي.
  int settingsSection = 0;

  /// تنظیمات پرانیزي — او که ووایې، سیده یوې ټاکلې ډلې ته.
  void openSettings([int section = 0]) {
    settingsSection = section;
    go(AppPage.settings);
  }

  void setSettingsSection(int i) {
    if (settingsSection == i) return;
    settingsSection = i;
    notifyListeners();
  }

  /// د اکسپلورر «پټ فایلونه وښایه» افشن.
  Future<void> toggleHiddenFiles() async {
    settings.showHiddenFiles = !settings.showHiddenFiles;
    notifyListeners();
    await backend.saveSettings(settings);
  }

  /// د اکسپورټ وروستی مسیر ساتي — نو راتلونکی ځل هماغه پرانیستل شي.
  Future<void> rememberExportDir(String dir) async {
    if (settings.exportDir == dir) return;
    settings.exportDir = dir;
    await backend.saveSettings(settings);
  }

  void toggleSidebar() {
    sidebarExpanded = !sidebarExpanded;
    notifyListeners();
  }

  /// د پیښې محتوا لا نه ده لوستل شوې (`content.json` پر لاره ده).
  bool editorLoading = false;

  /// پیښه پرانیزي. د پاڼې بدلون سمدستي کیږي — محتوا وروسته راځي،
  /// نو په سایډبار او کارتونو کلیک هېڅکله نه ځنډیږي.
  /// پیښه مستقیم په **پریویو** کې پرانیستل شوې (له کارت څخه)؟
  ///
  /// که هو، د پریویو «بېرته» تڼۍ باید سمدستي د پیښو پاڼې ته ولاړه
  /// شي — نه ایډیټ حالت ته. پخوا داسې و چې کاروونکی له پریویو
  /// څخه ایډیټ ته لوېده او دویم ځل یې «بېرته» وهله.
  bool previewEntry = false;

  void openEditor(EventMetadata e, {bool preview = false}) {
    editing = e;
    previewMode = preview;
    previewEntry = preview;
    if (e.contentLoaded) {
      editorLoading = false;
      notifyListeners();
      return;
    }
    editorLoading = true;
    notifyListeners();
    backend.loadContent(e).then((_) {
      if (editing != e) return; // کاروونکی مخکې لاړ
      editorLoading = false;
      notifyListeners();
    });
  }

  void closeEditor() {
    editing = null;
    editorLoading = false;
    previewMode = false;
    previewEntry = false;
    notifyListeners();
    refresh();
  }

  void setPreview(bool v) {
    previewMode = v;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  //  تنظیمات
  // ═══════════════════════════════════════════════════════

  Future<void> setTheme(ThemeChoice t) async {
    settings.theme = t;
    await backend.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setCalendar(CalendarKind c) async {
    settings.calendar = c.name;
    await backend.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setPashtoMonths(bool v) async {
    settings.pashtoMonthNames = v;
    await backend.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setGridSize(int n) async {
    settings.gridSize = n;
    await backend.saveSettings(settings);
    notifyListeners();
  }

  /// **د پروګرام د هر څه اندازه.**
  Future<void> setUiScale(double v) async {
    settings.uiScale = v.clamp(0.6, 1.6);
    await backend.saveSettings(settings);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  //  پیښې
  // ═══════════════════════════════════════════════════════

  Future<void> saveEvent(EventMetadata e, {String? html}) async {
    await backend.saveEvent(e, html: html);
    await refresh();
  }

  Future<void> deleteEvent(String id, {bool files = false}) async {
    await backend.deleteEvent(id, deleteFiles: files);
    if (editing?.id == id) editing = null;
    await refresh();
  }

  // ── لغتونه ─────────────────────────────────────────────
  Future<List<VocabTerm>> vocab(VocabKind k) => backend.vocab(k);

  Future<void> addVocab(VocabKind k, String name) async {
    if (name.trim().isEmpty) return;
    await backend.addVocab(k, VocabTerm(name: name.trim()));
    notifyListeners();
  }

  Future<void> deleteVocab(VocabKind k, String name) async {
    await backend.deleteVocab(k, name);
    await refresh();
  }

  Future<int> renameVocab(VocabKind k, String from, String to) async {
    final n = await backend.renameVocab(k, from, to);
    await refresh();
    return n;
  }

  /// د نندارې لپاره — آیا دا د ډیمو نسخه ده؟
  bool get isDemo => backend is DemoBackend || kIsWeb;

  /// د تاریخ متن د کاروونکي د غوره شوي تقویم مطابق.
  String dateText(TriDate d) {
    if (settings.pashtoMonthNames && calendar == CalendarKind.shamsi) {
      return d.shamsiTextPashto;
    }
    return d.textFor(calendar);
  }
}
