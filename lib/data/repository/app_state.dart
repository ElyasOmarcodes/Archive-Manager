import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/date/pashto_calendar.dart';
import '../models/models.dart';
import '../models/query.dart';
import '../platform/backend.dart';
import '../platform/demo_backend.dart';

/// د پروګرام هغه پاڼې چې سایډبار کې ښکاري.
enum AppPage {
  dashboard('ډاشبورډ', Icons.space_dashboard_rounded),
  events('ټولې پیښې', Icons.auto_awesome_mosaic_rounded),
  explorer('فایل اکسپلورر', Icons.folder_open_rounded),
  keywords('د کیورډونو مدیریت', Icons.sell_rounded),
  persons('د اشخاصو مدیریت', Icons.groups_rounded),
  categories('د کټګوریو مدیریت', Icons.category_rounded),
  settings('تنظیمات', Icons.settings_rounded);

  const AppPage(this.title, this.icon);
  final String title;
  final IconData icon;
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

  // ── ډیټا ────────────────────────────────────────────────
  ArchiveStats stats = const ArchiveStats();
  List<EventMetadata> events = const [];
  FacetCounts facets = FacetCounts.empty;
  EventQuery query = const EventQuery();
  bool loading = false;

  ScanProgress? scan;

  // ═══════════════════════════════════════════════════════
  //  پیل
  // ═══════════════════════════════════════════════════════

  Future<void> boot() async {
    settings = await backend.loadSettings();
    final root = settings.archiveRoot;

    if (settings.onboarded && root != null) {
      if (await backend.pathExists(root)) {
        await _openRoot(root, rescan: backend.isReal);
      } else {
        rootMissing = true;
        missingPath = root;
      }
    }
    booting = false;
    notifyListeners();
  }

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
    if (root == null) return;
    await for (final p in backend.rescan(root)) {
      scan = p;
      notifyListeners();
    }
    scan = null;
    await refresh();
  }

  // ═══════════════════════════════════════════════════════
  //  تازه کول
  // ═══════════════════════════════════════════════════════

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    stats = await backend.stats();
    events = await backend.search(query);
    facets = await backend.facets(query);
    loading = false;
    notifyListeners();
  }

  Future<void> setQuery(EventQuery q) async {
    query = q;
    await refresh();
  }

  Future<void> clearFilters() => setQuery(query.cleared());

  // ═══════════════════════════════════════════════════════
  //  ناوبري
  // ═══════════════════════════════════════════════════════

  void go(AppPage p) {
    page = p;
    editing = null;
    previewMode = false;
    notifyListeners();
  }

  void toggleSidebar() {
    sidebarExpanded = !sidebarExpanded;
    notifyListeners();
  }

  void openEditor(EventMetadata e, {bool preview = false}) {
    editing = e;
    previewMode = preview;
    notifyListeners();
  }

  void closeEditor() {
    editing = null;
    previewMode = false;
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
