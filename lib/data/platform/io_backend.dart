import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/date/pashto_calendar.dart';
import '../index/index_db.dart';
import '../models/models.dart';
import '../models/query.dart';
import 'backend.dart';

/// **ریښتینی بک‌اینډ** — وینډوز او لینکس.
///
/// د فایل سیسټم ټولې چارې دلته دي. د درانه کار (سکن) لپاره یو جلا
/// `Isolate` کارول کیږي، نو د ۵TB ډرایو سکن هم UI نه ځنډوي.
class IoBackend implements ArchiveBackend {
  IndexDb? _index;
  String? _root;

  /// اوسنی د آرشیف ریښه (که پرانیستل شوې وي).
  String? get currentRoot => _root;

  @override
  bool get isReal => true;

  /// د پیښې د پېژندنې فایل — که یو فولډر دا ولري، پیښه ده.
  static const metaFile = 'metadata.json';

  /// د پاڼې محتوا — بلاکونه، ضمیمې، لینکونه. یوازې د پرانیستلو پر مهال
  /// لوستل کیږي، نو د لټون بار پرې نه لوېږي.
  static const contentFile = 'content.json';
  static const htmlFile = 'index.html';
  static const attachmentsDir = 'attachments';

  /// د پروګرام خپل فولډر د آرشیف ریښې دننه — فونټونه او راتلونکي
  /// ګډ فایلونه پکې ساتل کیږي. سکن یې پرېږدي.
  static const supportDir = '_arvitch';

  static const _fontWeights = ['Regular', 'SemiBold', 'Bold', 'ExtraBold'];

  // ═══════════════════════════════════════════════════════
  //  تنظیمات
  // ═══════════════════════════════════════════════════════

  Future<File> _settingsFile() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'settings.json'));
  }

  @override
  Future<AppSettings> loadSettings() async {
    try {
      final f = await _settingsFile();
      if (!await f.exists()) return AppSettings();
      return AppSettings.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  @override
  Future<void> saveSettings(AppSettings s) async {
    final f = await _settingsFile();
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(s.toJson()));
  }

  // ═══════════════════════════════════════════════════════
  //  مسیرونه
  // ═══════════════════════════════════════════════════════

  @override
  Future<bool> pathExists(String path) async {
    if (path.trim().isEmpty) return false;
    try {
      return await Directory(path).exists();
    } catch (_) {
      return false;
    }
  }

  /// **د ډرایو د ځای موندنه** — هر پلیټ‌فارم خپله لار لري.
  ///
  /// Dart دې لپاره جوړ API نه لري، نو د سیسټم خپل کمانډ کاروو.
  /// که هر څه ناکام شي، `unknown` راګرځي او UI یوازې دا برخه پټوي —
  /// پروګرام نه ودریږي.
  @override
  Future<DiskSpace> diskSpace(String path) async {
    if (path.trim().isEmpty) return DiskSpace.unknown;
    try {
      if (Platform.isWindows) return await _windowsDiskSpace(path);
      return await _posixDiskSpace(path);
    } catch (_) {
      return DiskSpace.unknown;
    }
  }

  static Future<DiskSpace> _windowsDiskSpace(String path) async {
    // د ډرایو توری: `E:\Arvitch\…` → `E:`
    final drive = p.rootPrefix(path).replaceAll(RegExp(r'[\\/]'), '');
    if (drive.isEmpty) return DiskSpace.unknown;

    final r = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "\$d = Get-PSDrive -Name '${drive.replaceAll(':', '')}' "
          '-ErrorAction Stop; '
          "Write-Output (\"\$(\$d.Used) \$(\$d.Free)\")",
    ]);
    if (r.exitCode != 0) return DiskSpace.unknown;

    final parts = '${r.stdout}'.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return DiskSpace.unknown;
    final used = int.tryParse(parts[0]) ?? 0;
    final free = int.tryParse(parts[1]) ?? 0;
    if (used + free <= 0) return DiskSpace.unknown;
    return DiskSpace(totalBytes: used + free, freeBytes: free);
  }

  static Future<DiskSpace> _posixDiskSpace(String path) async {
    // `df -k <path>` → د ۱K بلاکونو په واحد
    final r = await Process.run('df', ['-k', path]);
    if (r.exitCode != 0) return DiskSpace.unknown;

    final lines = '${r.stdout}'.trim().split('\n');
    if (lines.length < 2) return DiskSpace.unknown;
    final cols = lines.last.trim().split(RegExp(r'\s+'));
    if (cols.length < 4) return DiskSpace.unknown;

    final total = (int.tryParse(cols[1]) ?? 0) * 1024;
    final free = (int.tryParse(cols[3]) ?? 0) * 1024;
    if (total <= 0) return DiskSpace.unknown;
    return DiskSpace(totalBytes: total, freeBytes: free);
  }

  @override
  Future<String?> pickDirectory({String? initial}) =>
      FilePicker.getDirectoryPath(
        dialogTitle: 'د آرشیف فولډر وټاکئ',
        initialDirectory: initial,
      );

  @override
  Future<List<String>> pickFiles({List<String>? extensions}) async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'فایلونه وټاکئ',
      type: extensions == null ? FileType.any : FileType.custom,
      allowedExtensions: extensions,
    );
    return files.map((f) => f.path).whereType<String>().toList();
  }

  // ═══════════════════════════════════════════════════════
  //  ایندکس
  // ═══════════════════════════════════════════════════════

  @override
  Future<void> openIndex(String root) async {
    _root = root;
    _index?.dispose();
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    // هر آرشیف خپل ایندکس لري — نو د څو ډرایوونو بدلول ډیټا نه ګډوي.
    final key = root.hashCode.toRadixString(16);
    _index = IndexDb.open(p.join(dir.path, 'index_$key.db'));
  }

  IndexDb get _db {
    final i = _index;
    if (i == null) throw StateError('ایندکس لا نه دی پرانیستل شوی');
    return i;
  }

  /// **د بشپړ آرشیف سکن** — په جلا Isolate کې.
  ///
  /// د پرمختګ راپور ورکوي، نو کاروونکی د ۵TB ډرایو پر مهال هم
  /// ژوندی پرمختګ ویني.
  @override
  Stream<ScanProgress> rescan(String root) async* {
    final controller = StreamController<ScanProgress>();
    final rp = ReceivePort();
    final found = <EventMetadata>[];

    final iso = await Isolate.spawn(_scanIsolate, (rp.sendPort, root));

    rp.listen((msg) {
      if (msg is _ScanTick) {
        controller.add(ScanProgress(
            scanned: msg.scanned, found: msg.found, currentPath: msg.path));
      } else if (msg is _ScanResult) {
        found.addAll(msg.events.map((j) => EventMetadata.fromJson(
            j.meta, folderPath: j.folder)));
        controller.add(ScanProgress(
            scanned: msg.scanned, found: found.length, done: false));
        controller.close();
        rp.close();
        iso.kill(priority: Isolate.beforeNextEvent);
      }
    });

    yield* controller.stream;

    // ایندکس یوه معامله کې ډکوو — تر یو-یو ډېر چټک دی.
    _db.clear();
    _db.upsertAll(found);
    yield ScanProgress(scanned: found.length, found: found.length, done: true);
  }

  // ═══════════════════════════════════════════════════════
  //  پوښتنې
  // ═══════════════════════════════════════════════════════

  @override
  Future<List<EventMetadata>> search(EventQuery q) async => _db.search(q);

  @override
  Future<FacetCounts> facets(EventQuery q) async => _db.facets(q);

  @override
  Future<ArchiveStats> stats() async => _db.stats();

  @override
  Future<EventMetadata?> eventById(String id) async => _db.byId(id);

  // ═══════════════════════════════════════════════════════
  //  لیکل
  // ═══════════════════════════════════════════════════════

  /// د آرشیف ریښې کې فونټونه یو ځل جوړوي او بېرته یې مسیر راګرځوي.
  ///
  /// دا کار یوازې لومړی ځل ریښتینی لیکل کوي؛ وروسته یوازې ګوري چې
  /// فایلونه شته دي.
  /// عامه بڼه — AppState یې مخکې له HTML جوړولو غوښتنه کوي.
  @override
  Future<String?> webFontDirFor(String eventFolder) async {
    final root = _root;
    if (root == null) return null;
    return _relativeFontDir(await _ensureFonts(root), eventFolder);
  }

  Future<String?> _ensureFonts(String root) async {
    try {
      final dir = Directory(p.join(root, supportDir, 'fonts'));
      await dir.create(recursive: true);
      for (final w in _fontWeights) {
        final f = File(p.join(dir.path, 'Vazirmatn-$w.woff2'));
        if (!await f.exists()) {
          final data =
              await rootBundle.load('assets/webfonts/Vazirmatn-$w.woff2');
          await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
        }
      }
      return dir.path;
    } catch (_) {
      // که فونټ ونه لیکل شو، پاڼه بیا هم کار کوي — یوازې د سیسټم
      // فونټ کاروي. دا د ثبت د پرېښودو دلیل نه دی.
      return null;
    }
  }

  /// له پیښې څخه فونټ فولډر ته نسبي مسیر — نو پاڼه هر چیرې کار کوي،
  /// حتی که ټول آرشیف بل ډرایو ته ولېږدول شي.
  static String? _relativeFontDir(String? fontDir, String eventFolder) {
    if (fontDir == null) return null;
    try {
      return p.relative(fontDir, from: eventFolder).replaceAll(r'\', '/');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveEvent(EventMetadata e, {String? html}) async {
    final dir = Directory(e.folderPath);
    await dir.create(recursive: true);
    await Directory(p.join(e.folderPath, attachmentsDir)).create(recursive: true);

    e.updatedAt = DateTime.now();

    // ۱) حقیقت پر ډیسک — دوه فایله:
    //    metadata.json  → یوازې د فلټر ډګرونه (وړوکی، ژر لوستل کیږي)
    //    content.json   → د پاڼې محتوا (یوازې د پرانیستلو پر مهال)
    await File(p.join(e.folderPath, metaFile))
        .writeAsString(jsonEncode(e.toJson()), flush: true);

    if (e.contentLoaded) {
      await File(p.join(e.folderPath, contentFile))
          .writeAsString(jsonEncode(e.toContentJson()), flush: true);
    }

    if (html != null) {
      await File(p.join(e.folderPath, htmlFile))
          .writeAsString(html, flush: true);
    }

    // ۲) ایندکس تازه کړه
    _db.upsert(e);
  }

  @override
  Future<EventMetadata> loadContent(EventMetadata e) async {
    if (e.contentLoaded) return e;
    try {
      final f = File(p.join(e.folderPath, contentFile));
      if (await f.exists()) {
        e.applyContent(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>);
        return e;
      }
      // زړه بڼه: محتوا لا هم د `metadata.json` دننه ده.
      final m = File(p.join(e.folderPath, metaFile));
      if (await m.exists()) {
        final j = jsonDecode(await m.readAsString()) as Map<String, dynamic>;
        if (j.containsKey('blocks') || j.containsKey('attachments')) {
          e.applyContent(j);
          return e;
        }
      }
      // هیڅ محتوا نشته — تشه پاڼه ده.
      e.applyContent(const {});
    } catch (_) {
      // ناسم یا نه‑لوستل‑کېدونکی فایل. `contentLoaded` نه لګوو، نو
      // د ثبت پر مهال زوړ لنډیز نه ورکیږي.
    }
    return e;
  }

  @override
  Future<void> deleteEvent(String id, {bool deleteFiles = false}) async {
    final e = _db.byId(id);
    _db.remove(id);
    if (deleteFiles && e != null) {
      final d = Directory(e.folderPath);
      if (await d.exists()) await d.delete(recursive: true);
    }
  }

  @override
  Future<String> prepareEventFolder({
    required String root,
    required String title,
    required dateJdn,
    bool auto = true,
    String? manualParent,
  }) async {
    final safe = _sanitize(title);
    String parent;

    if (auto) {
      // اتومات: <ریښه>/<شمسي کال>/<شمسي میاشت>/<شمسي ورځ>/<د پیښې نوم>
      final d = TriDate.fromJdn(dateJdn as int);
      parent = p.join(
        root,
        '${d.shamsi.year}',
        PashtoMonths.shamsiDari[d.shamsi.month - 1],
        '${d.shamsi.day}',
      );
    } else {
      parent = manualParent ?? root;
    }

    await Directory(parent).create(recursive: true);

    // که همدا نوم مخکې موجود وي، شمېره ورسره کوو — هیڅ ډیټا نه بایلو.
    var folder = p.join(parent, safe);
    var n = 2;
    while (await Directory(folder).exists()) {
      folder = p.join(parent, '$safe ($n)');
      n++;
    }
    await Directory(folder).create(recursive: true);
    await Directory(p.join(folder, attachmentsDir)).create(recursive: true);
    return folder;
  }

  /// د وینډوز لپاره د فولډر نوم پاکول — منع شوي حروف لرې کوي.
  static String _sanitize(String name) {
    var s = name.trim().replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // وینډوز د نقطې یا تشې په پای کې نوم نه مني.
    s = s.replaceAll(RegExp(r'[. ]+$'), '');
    if (s.isEmpty) s = 'بې‌نومه پیښه';
    return s.length > 120 ? s.substring(0, 120) : s;
  }

  @override
  Future<Attachment> attachFile({
    required String eventFolder,
    required String sourcePath,
    bool move = true,
  }) async {
    final attDir = Directory(p.join(eventFolder, attachmentsDir));
    await attDir.create(recursive: true);

    final base = p.basename(sourcePath);
    var target = p.join(attDir.path, base);
    var n = 2;
    while (await File(target).exists()) {
      target = p.join(attDir.path,
          '${p.basenameWithoutExtension(base)} ($n)${p.extension(base)}');
      n++;
    }

    final src = File(sourcePath);
    File out;
    if (move) {
      try {
        out = await src.rename(target);
      } on FileSystemException {
        // بېل ډرایو — نو کاپي او بیا حذف.
        out = await src.copy(target);
        await src.delete();
      }
    } else {
      out = await src.copy(target);
    }

    return Attachment(
      name: p.basename(out.path),
      relativePath: '$attachmentsDir/${p.basename(out.path)}',
      kind: MediaKind.ofPath(out.path),
      sizeBytes: await out.length(),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  لغتونه
  // ═══════════════════════════════════════════════════════

  @override
  Future<List<VocabTerm>> vocab(VocabKind kind) async => _db.vocab(kind);

  @override
  Future<void> addVocab(VocabKind kind, VocabTerm term) async =>
      _db.addVocab(kind, term);

  @override
  Future<void> deleteVocab(VocabKind kind, String name) async =>
      _db.deleteVocabRow(kind, name);

  /// **یو لغت په ټول آرشیف کې بدلوي.**
  ///
  /// یوازې هغه پیښې بیا لیکل کیږي چې دا لغت کاروي — نو حتی په زرګونو
  /// پیښو کې هم دا کار په څو ثانیو کې بشپړیږي.
  @override
  Future<int> renameVocab(VocabKind kind, String from, String to) async {
    final affected = _db.eventsUsing(kind, from);
    final updated = <EventMetadata>[];

    for (final e in affected) {
      switch (kind) {
        case VocabKind.keyword:
          final k = e.keywords.map((x) => x == from ? to : x).toSet().toList();
          updated.add(e.copyWith(keywords: k));
        case VocabKind.person:
          final ps = e.persons.map((x) => x == from ? to : x).toSet().toList();
          updated.add(e.copyWith(persons: ps));
        case VocabKind.category:
          updated.add(e.copyWith(category: to));
      }
    }

    // پر ډیسک ولیکه
    for (final e in updated) {
      final f = File(p.join(e.folderPath, metaFile));
      if (await f.exists()) {
        await f.writeAsString(
            jsonEncode(e.toJson()));
      }
    }

    // بیا ایندکس یوه معامله کې
    _db.upsertAll(updated);
    _db.deleteVocabRow(kind, from);
    _db.addVocab(kind, VocabTerm(name: to));
    return updated.length;
  }

  // ═══════════════════════════════════════════════════════
  //  فایل اکسپلورر
  // ═══════════════════════════════════════════════════════

  @override
  Future<List<FsEntry>> listDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return const [];

    final out = <FsEntry>[];
    await for (final ent in dir.list(followLinks: false)) {
      try {
        final name = p.basename(ent.path);
        // د پروګرام خپل فولډر کاروونکي ته نه ښیو
        if (name.startsWith('.') || name == supportDir) continue;
        final st = await ent.stat();
        if (st.type == FileSystemEntityType.directory) {
          final isEvent =
              await File(p.join(ent.path, metaFile)).exists();
          out.add(FsEntry(
            name: name,
            path: ent.path,
            isDirectory: true,
            modified: st.modified,
            isEventFolder: isEvent,
          ));
        } else {
          out.add(FsEntry(
            name: name,
            path: ent.path,
            isDirectory: false,
            sizeBytes: st.size,
            modified: st.modified,
          ));
        }
      } catch (_) {
        // د لاسرسي نشتوالی — دا توکی پرېږده، سکن مه ودروه.
      }
    }

    out.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  @override
  Future<List<String>> rootDrives() async {
    if (Platform.isWindows) {
      final out = <String>[];
      for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
        if (await Directory('$c:\\').exists()) out.add('$c:\\');
      }
      return out;
    }
    return ['/', Platform.environment['HOME'] ?? '/home'];
  }

  @override
  Future<void> createFolder(String parent, String name) =>
      Directory(p.join(parent, _sanitize(name))).create(recursive: true);

  @override
  Future<void> renameEntry(String path, String newName) async {
    final target = p.join(p.dirname(path), _sanitize(newName));
    if (await Directory(path).exists()) {
      await Directory(path).rename(target);
    } else {
      await File(path).rename(target);
    }
  }

  @override
  Future<void> deleteEntries(List<String> paths) async {
    for (final path in paths) {
      try {
        if (await Directory(path).exists()) {
          await Directory(path).delete(recursive: true);
        } else if (await File(path).exists()) {
          await File(path).delete();
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> copyEntries(List<String> paths, String destination,
      {bool move = false}) async {
    for (final src in paths) {
      final target = await _uniqueTarget(destination, p.basename(src));
      if (await Directory(src).exists()) {
        await _copyDir(Directory(src), Directory(target));
        if (move) await Directory(src).delete(recursive: true);
      } else if (await File(src).exists()) {
        if (move) {
          try {
            await File(src).rename(target);
          } on FileSystemException {
            await File(src).copy(target);
            await File(src).delete();
          }
        } else {
          await File(src).copy(target);
        }
      }
    }
  }

  static Future<String> _uniqueTarget(String dir, String name) async {
    var t = p.join(dir, name);
    var n = 2;
    while (await File(t).exists() || await Directory(t).exists()) {
      t = p.join(dir,
          '${p.basenameWithoutExtension(name)} ($n)${p.extension(name)}');
      n++;
    }
    return t;
  }

  static Future<void> _copyDir(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    await for (final e in src.list(recursive: false, followLinks: false)) {
      final target = p.join(dst.path, p.basename(e.path));
      if (e is Directory) {
        await _copyDir(e, Directory(target));
      } else if (e is File) {
        await e.copy(target);
      }
    }
  }

  @override
  Future<void> openExternally(String path) async {
    final uri = Uri.file(path);
    if (!await launchUrl(uri)) {
      // بېرته پاتې لار — د سیسټم خپل کمانډ.
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      }
    }
  }

  @override
  Future<void> revealInFileManager(String path) async {
    if (Platform.isWindows) {
      final isDir = await Directory(path).exists();
      await Process.run(
          'explorer', isDir ? [path] : ['/select,', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open',
          [await Directory(path).exists() ? path : p.dirname(path)]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    }
  }

  @override
  Future<String?> readHtml(String eventFolder) async {
    final f = File(p.join(eventFolder, htmlFile));
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<List<int>?> readBytes(String path) async {
    final f = File(path);
    return await f.exists() ? f.readAsBytes() : null;
  }
}

// ═══════════════════════════════════════════════════════════
//  د سکن Isolate
// ═══════════════════════════════════════════════════════════

class _ScanTick {
  const _ScanTick(this.scanned, this.found, this.path);
  final int scanned;
  final int found;
  final String path;
}

class _FoundEvent {
  const _FoundEvent(this.folder, this.meta);
  final String folder;
  final Map<String, dynamic> meta;
}

class _ScanResult {
  const _ScanResult(this.scanned, this.events);
  final int scanned;
  final List<_FoundEvent> events;
}

/// په جلا Isolate کې چلیږي — نو د زرګونو فولډرونو ګرځېدل UI نه ځنډوي.
///
/// **مهمه اصلاح:** کله چې یو فولډر کې `metadata.json` وموندل شي،
/// د هغه دننه نور نه ګرځو (`attachments/` کې ممکن زرګونه فایلونه وي،
/// خو مونږ ورته اړتیا نه لرو). دا د سکن وخت ډراماتیک کموي.
Future<void> _scanIsolate((SendPort, String) args) async {
  final (send, root) = args;
  var scanned = 0;
  final events = <_FoundEvent>[];

  final queue = <String>[root];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    scanned++;

    if (scanned % 200 == 0) {
      send.send(_ScanTick(scanned, events.length, current));
    }

    try {
      final metaPath = p.join(current, IoBackend.metaFile);
      final metaFile = File(metaPath);

      if (await metaFile.exists()) {
        try {
          final json = jsonDecode(await metaFile.readAsString());
          if (json is Map<String, dynamic>) {
            events.add(_FoundEvent(current, json));
          }
        } catch (_) {
          // خراب JSON — دا پیښه پرېږده، سکن روان وساته.
        }
        continue; // د پیښې دننه نه ګرځو
      }

      await for (final e in Directory(current).list(followLinks: false)) {
        if (e is Directory) {
          final name = p.basename(e.path);
          if (name.startsWith('.') ||
              name == IoBackend.attachmentsDir ||
              name == IoBackend.supportDir) {
            continue;
          }
          queue.add(e.path);
        }
      }
    } catch (_) {
      // د لاسرسي نشتوالی یا اوږد مسیر — تېر شه.
    }
  }

  send.send(_ScanResult(scanned, events));
}
