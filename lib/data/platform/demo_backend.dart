import 'dart:async';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../index/memory_index.dart';
import '../models/models.dart';
import '../models/query.dart';
import 'backend.dart';

/// **د نندارې بک‌اینډ** — ویب او ازموینې.
///
/// همغه ریښتینی `IndexDb` کاروي (نو د لټون چلند سل په سلو کې یو شان دی)،
/// خو د ډیسک پرځای د یادښت دننه نمونه ډیټا لري.
class DemoBackend implements ArchiveBackend {
  DemoBackend({this.seeded = true});

  final bool seeded;
  final MemoryIndex _db = MemoryIndex();
  AppSettings _settings = AppSettings(
    archiveRoot: r'E:\Arvitch',
    onboarded: true,
  );
  bool _ready = false;

  @override
  bool get isReal => false;

  static const _root = r'E:\Arvitch';

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings s) async => _settings = s;

  @override
  Future<bool> pathExists(String path) async => true;

  // د نندارې لپاره یو ۸TB هارډ چې ۳٫۱TB یې ډک دی.
  @override
  Future<DiskSpace> diskSpace(String path) async => const DiskSpace(
        totalBytes: 8 * 1024 * 1024 * 1024 * 1024,
        freeBytes: 4900 * 1024 * 1024 * 1024,
      );

  @override
  Future<String?> pickDirectory({String? initial}) async => _root;

  @override
  Future<List<String>> pickFiles({List<String>? extensions}) async => const [];

  @override
  Future<void> openIndex(String root) async {
    if (_ready) return;
    if (seeded) _db.upsertAll(_seed());
    _ready = true;
  }

  @override
  Stream<ScanProgress> rescan(String root) async* {
    await openIndex(root);
    final n = _db.count(const EventQuery());
    for (var i = 0; i <= n; i += 3) {
      await Future.delayed(const Duration(milliseconds: 30));
      yield ScanProgress(scanned: i * 4, found: i, currentPath: '$root\\...');
    }
    yield ScanProgress(scanned: n * 4, found: n, done: true);
  }

  @override
  Future<List<EventMetadata>> search(EventQuery q) async => _db.search(q);
  @override
  Future<FacetCounts> facets(EventQuery q) async => _db.facets(q);
  @override
  Future<ArchiveStats> stats() async => _db.stats();
  @override
  Future<EventMetadata?> eventById(String id) async => _db.byId(id);

  final Map<String, String> _html = {};

  /// په ډیمو کې محتوا په حافظه کې ده، نو څه لوستلو ته اړتیا نشته.
  @override
  Future<EventMetadata> loadContent(EventMetadata e) async {
    if (!e.contentLoaded) e.applyContent(const {});
    return e;
  }

  @override
  Future<void> saveEvent(EventMetadata e, {String? html}) async {
    if (html != null) _html[e.folderPath] = html;
    _db.upsert(e);
  }

  @override
  Future<void> deleteEvent(String id, {bool deleteFiles = false}) async =>
      _db.remove(id);

  @override
  Future<String> prepareEventFolder({
    required String root,
    required String title,
    required dateJdn,
    bool auto = true,
    String? manualParent,
  }) async {
    final d = TriDate.fromJdn(dateJdn as int);
    final safe = title.trim().isEmpty ? 'بې‌نومه پیښه' : title.trim();
    return auto
        ? '$root\\${d.shamsi.year}\\'
            '${PashtoMonths.shamsiDari[d.shamsi.month - 1]}\\'
            '${d.shamsi.day}\\$safe'
        : '${manualParent ?? root}\\$safe';
  }

  @override
  Future<Attachment> attachFile({
    required String eventFolder,
    required String sourcePath,
    bool move = true,
  }) async {
    final name = sourcePath.split(RegExp(r'[/\\]')).last;
    return Attachment(
      name: name,
      relativePath: 'attachments/$name',
      kind: MediaKind.ofPath(name),
      sizeBytes: 1024 * 1024 * 4,
    );
  }

  @override
  Future<List<VocabTerm>> vocab(VocabKind kind) async => _db.vocab(kind);
  @override
  Future<void> addVocab(VocabKind kind, VocabTerm term) async =>
      _db.addVocab(kind, term);
  @override
  Future<void> deleteVocab(VocabKind kind, String name) async =>
      _db.deleteVocabRow(kind, name);

  @override
  Future<int> renameVocab(VocabKind kind, String from, String to) async {
    final affected = _db.eventsUsing(kind, from);
    final updated = affected.map((e) => switch (kind) {
          VocabKind.keyword => e.copyWith(
              keywords: e.keywords.map((x) => x == from ? to : x).toSet().toList()),
          VocabKind.person => e.copyWith(
              persons: e.persons.map((x) => x == from ? to : x).toSet().toList()),
          VocabKind.category => e.copyWith(category: to),
        });
    _db.upsertAll(updated);
    _db.deleteVocabRow(kind, from);
    _db.addVocab(kind, VocabTerm(name: to));
    return affected.length;
  }

  // ── نمونه فایل سیسټم ───────────────────────────────────

  @override
  Future<List<FsEntry>> listDirectory(String path) async {
    await Future.delayed(const Duration(milliseconds: 60));
    final norm = path.replaceAll('/', r'\');
    final depth = norm.split(r'\').where((s) => s.isNotEmpty).length;

    if (depth <= 2) {
      return [
        for (final y in ['1405', '1404', '1403'])
          FsEntry(
              name: y,
              path: '$norm\\$y',
              isDirectory: true,
              modified: DateTime.now().subtract(Duration(days: 30 * depth))),
      ];
    }
    if (depth == 3) {
      return [
        for (final m in ['سنبله', 'اسد', 'سرطان', 'جوزا'])
          FsEntry(
              name: m,
              path: '$norm\\$m',
              isDirectory: true,
              modified: DateTime.now().subtract(const Duration(days: 20))),
      ];
    }
    if (depth == 4) {
      return [
        for (final d in ['13', '11', '7', '2'])
          FsEntry(
              name: d,
              path: '$norm\\$d',
              isDirectory: true,
              modified: DateTime.now().subtract(const Duration(days: 9))),
      ];
    }
    if (depth == 5) {
      final events = _db.search(const EventQuery(limit: 4));
      return [
        for (final e in events)
          FsEntry(
              name: e.title,
              path: '$norm\\${e.title}',
              isDirectory: true,
              isEventFolder: true,
              modified: e.updatedAt),
      ];
    }
    return [
      const FsEntry(
          name: 'attachments', path: '', isDirectory: true, childCount: 6),
      FsEntry(
          name: 'index.html',
          path: '$norm\\index.html',
          isDirectory: false,
          sizeBytes: 18442,
          modified: DateTime.now()),
      FsEntry(
          name: 'metadata.json',
          path: '$norm\\metadata.json',
          isDirectory: false,
          sizeBytes: 2317,
          modified: DateTime.now()),
    ];
  }

  @override
  Future<List<String>> rootDrives() async => [r'E:\', r'C:\', r'D:\'];

  @override
  Future<void> createFolder(String parent, String name) async {}
  @override
  Future<void> renameEntry(String path, String newName) async {}
  @override
  Future<void> deleteEntries(List<String> paths) async {}
  @override
  Future<void> copyEntries(List<String> paths, String destination,
      {bool move = false}) async {}
  @override
  Future<void> openExternally(String path) async {}
  @override
  Future<void> revealInFileManager(String path) async {}
  @override
  Future<String?> readHtml(String eventFolder) async => _html[eventFolder];

  // د نندارې نسخه پر ډیسک هیڅ نه لیکي، نو فونټ فولډر هم نشته.
  @override
  Future<String?> webFontDirFor(String eventFolder) async => null;
  @override
  Future<List<int>?> readBytes(String path) async => null;

  /// ویب کې فایل سیسټم نشته.
  @override
  Future<String?> writeBytes(String path, List<int> bytes) async => null;

  // د نندارې نسخه فایل سیسټم نه لري — نو ډایلوګ هم نشته.
  @override
  Future<String?> saveFileAs({
    required String fileName,
    required List<int> bytes,
    String? initialDirectory,
    String mimeType = 'application/octet-stream',
  }) async =>
      null;

  // ═══════════════════════════════════════════════════════
  //  نمونه ډیټا
  // ═══════════════════════════════════════════════════════

  static List<EventMetadata> _seed() {
    final rows = <(String, String, int, int, int, String, int, ColorTag,
        List<String>, List<String>, List<MediaKind>)>[
      ('د کابل او چین اقتصادي تړون', 'د دواړو هیوادونو ترمنځ د معدنونو '
          'په برخه کې مهم تړون لاسلیک شو.', 1405, 6, 13, 'سیاسي', 5,
          ColorTag.red, ['تړون', 'چین', 'اقتصاد', 'معدن'],
          ['حامد کرزی', 'لي جیانګ'],
          [MediaKind.video, MediaKind.image, MediaKind.image, MediaKind.audio]),
      ('د کندهار د امنیتي پیښې راپور', 'د کندهار ښار په مرکز کې د پېښې '
          'بشپړ راپور او د سترګو لیدونکو نقل قولونه.', 1405, 6, 11, 'امنیتي', 4,
          ColorTag.orange, ['امنیت', 'کندهار', 'راپور'],
          ['محمد نبي احمدزی'],
          [MediaKind.video, MediaKind.audio, MediaKind.document]),
      ('د ملي بودیجې غونډه', 'د پارلمان په ولسي جرګه کې د راتلونکي کال '
          'د بودیجې د تصویب غونډه.', 1405, 6, 7, 'اقتصادي', 3,
          ColorTag.yellow, ['بودیجه', 'پارلمان', 'اقتصاد'],
          ['عبدالله عبدالله', 'زرمینه کریمي'],
          [MediaKind.video, MediaKind.sheet, MediaKind.image]),
      ('د هرات زلزله — لومړني شواهد', 'د زلزلې له پېښېدو وروسته لومړني '
          'تصویري او صوتي شواهد.', 1405, 5, 28, 'طبیعي پېښه', 5,
          ColorTag.red, ['زلزله', 'هرات', 'بیړني حالت'],
          ['ډاکټر سمیع الله'],
          [MediaKind.video, MediaKind.video, MediaKind.image, MediaKind.image,
           MediaKind.image, MediaKind.audio]),
      ('د بلخ د کډوالو ستونزې', 'د بلخ ولایت کې د راستنېدونکو کډوالو '
          'د حالت راپور.', 1405, 5, 14, 'ټولنیز', 3,
          ColorTag.green, ['کډوال', 'بلخ', 'بشري مرستې'],
          ['نجیبه رحیمي'],
          [MediaKind.image, MediaKind.image, MediaKind.document]),
      ('د ښوونځیو د پرانیستې مراسم', 'په ننګرهار کې د نویو ښوونځیو '
          'د پرانیستې مراسم.', 1405, 4, 22, 'کلتوري', 2,
          ColorTag.blue, ['ښوونځی', 'ننګرهار', 'زده‌کړه'],
          ['محمد کریم'],
          [MediaKind.image, MediaKind.video]),
      ('د کرکټ ملي لوبډلې بریا', 'د ملي لوبډلې د نړیوالې سیالۍ بریا '
          'او د لوبغاړو نقل قولونه.', 1405, 3, 9, 'ورزشي', 4,
          ColorTag.purple, ['کرکټ', 'ورزش', 'بریا'],
          ['راشد خان'],
          [MediaKind.video, MediaKind.image, MediaKind.image, MediaKind.audio]),
      ('د روغتیایي خدماتو پراختیا', 'د بدخشان په لرې پرتو سیمو کې '
          'د روغتیایي کلینیکونو پراختیا.', 1404, 11, 18, 'ټولنیز', 3,
          ColorTag.green, ['روغتیا', 'بدخشان', 'کلینیک'],
          ['ډاکټره فرشته'],
          [MediaKind.image, MediaKind.document, MediaKind.sheet]),
      ('د سولې خبرو اترو پړاو', 'د سولې د خبرو اترو د نوي پړاو '
          'پیل او د ګډونوالو څرګندونې.', 1404, 9, 20, 'سیاسي', 5,
          ColorTag.red, ['سوله', 'خبرې اترې', 'سیاست'],
          ['اشرف غني', 'عبدالله عبدالله'],
          [MediaKind.video, MediaKind.audio, MediaKind.audio, MediaKind.image]),
      ('د بند د جوړولو پروژه', 'د کجکي بند د دویم پړاو د کار پیل.',
          1404, 7, 5, 'اقتصادي', 4, ColorTag.yellow,
          ['بند', 'انرژي', 'پروژه'], ['انجنیر شفیق'],
          [MediaKind.video, MediaKind.image, MediaKind.sheet]),
      ('د کلتوري میراث ساتنه', 'د بامیانو د تاریخي آثارو د ساتنې پروګرام.',
          1404, 5, 12, 'کلتوري', 4, ColorTag.purple,
          ['میراث', 'بامیان', 'تاریخ'], ['پوهاند رحمت'],
          [MediaKind.image, MediaKind.image, MediaKind.video]),
      ('د اوبو د سرچینو څېړنه', 'د هلمند د سیند د اوبو د کچې څېړنیز راپور.',
          1403, 12, 3, 'طبیعي پېښه', 2, ColorTag.none,
          ['اوبه', 'هلمند', 'څېړنه'], ['ډاکټر نصیر'],
          [MediaKind.sheet, MediaKind.document]),
    ];

    return [
      for (var i = 0; i < rows.length; i++)
        () {
          final r = rows[i];
          final d = TriDate.fromShamsi(r.$3, r.$4, r.$5);
          final folder = '$_root\\${d.shamsi.year}\\'
              '${PashtoMonths.shamsiDari[d.shamsi.month - 1]}\\'
              '${d.shamsi.day}\\${r.$1}';
          return EventMetadata(
            id: 'demo-$i',
            title: r.$1,
            summary: r.$2,
            folderPath: folder,
            date: d,
            category: r.$6,
            rating: r.$7,
            colorTag: r.$8,
            keywords: r.$9,
            persons: r.$10,
            attachments: [
              for (var k = 0; k < r.$11.length; k++)
                Attachment(
                  name: switch (r.$11[k]) {
                    MediaKind.video => 'doc_video_${k + 1}.mp4',
                    MediaKind.image => 'evidence_img_${k + 1}.jpg',
                    MediaKind.audio => 'statement_audio_${k + 1}.wav',
                    MediaKind.sheet => 'data_${k + 1}.xlsx',
                    _ => 'report_${k + 1}.pdf',
                  },
                  relativePath: 'attachments/file_${k + 1}',
                  kind: r.$11[k],
                  sizeBytes: switch (r.$11[k]) {
                    MediaKind.video => 380 * 1024 * 1024,
                    MediaKind.image => 4 * 1024 * 1024,
                    MediaKind.audio => 22 * 1024 * 1024,
                    _ => 900 * 1024,
                  },
                ),
            ],
            blocks: [
              Block(
                  id: 'b1-$i',
                  kind: BlockKind.heading,
                  text: r.$1,
                  level: 1),
              Block(id: 'b2-$i', kind: BlockKind.paragraph, text: r.$2),
              if (r.$10.isNotEmpty)
                Block(
                    id: 'b3-$i',
                    kind: BlockKind.quote,
                    text: 'دا پېښه د هیواد لپاره یو مهم پړاو دی او '
                        'مونږ یې ټول اړخونه څېړو.',
                    author: r.$10.first),
            ],
          );
        }()
    ];
  }
}
