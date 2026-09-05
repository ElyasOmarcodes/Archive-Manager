// د دې ازموینې موخه همدا ده چې پایلې چاپ کړي.
// ignore_for_file: avoid_print
@TestOn('linux || mac-os || windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/theme/tokens.dart';
import 'package:archive_manager/data/index/index_db.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/data/models/query.dart';

/// **ریښتینې ازموینه پر ریښتیني ډیسک.**
///
/// دا د یادښت دننه نمونه نه ده — دلته په ریښتیا سره پر ډیسک زرګونه
/// د پیښو فولډرونه او `metadata.json` فایلونه جوړیږي، بیا سکن کیږي،
/// او بیا پرې پلټنه کیږي. دقیقاً هغه لار چې پروګرام یې کاروي.
void main() {
  // دوه کچې: یوه ریښتیني اوسنۍ کچه، بله د راتلونکو کلونو لپاره.
  for (final eventCount in const [5000, 50000]) {
    _scaleTest(eventCount);
  }
}

void _scaleTest(int eventCount) {
  test('د $eventCount پیښو ریښتینې ازموینه', () async {
    final root = Directory.systemTemp.createTempSync('arv_scale_');
    addTearDown(() => root.deleteSync(recursive: true));

    final cats = ['سیاسي', 'امنیتي', 'اقتصادي', 'ټولنیز', 'کلتوري',
                  'ورزشي', 'طبیعي پېښه', 'روغتیا'];
    final kws = ['تړون','چین','امنیت','پارلمان','ولسمشر','بریدونه','سوله',
                 'کډوال','بودیجه','زلزله','لوبې','ښوونځی','روغتیا','بند',
                 'معدن','انرژي','اوبه','کرنه','ښار','سرحد'];
    final ppl = ['حامد کرزی','اشرف غني','عبدالله عبدالله','محمد نبي احمدزی',
                 'زرمینه کریمي','نجیبه رحیمي','راشد خان','ډاکټر سمیع الله'];
    final media = [MediaKind.video, MediaKind.image, MediaKind.audio,
                   MediaKind.document, MediaKind.sheet];
    final places = ['کابل','کندهار','هرات','بلخ','ننګرهار','بدخشان',
                    'هلمند','بامیان','کنړ','پکتیا'];

    // ═══ ۱) پر ډیسک جوړول ═══
    final sw = Stopwatch()..start();
    var totalBytes = 0;
    for (var i = 0; i < eventCount; i++) {
      final d = TriDate.fromJdn(
          TriDate.fromShamsi(1395, 1, 1).jdn + (i * 7919) % 4000);
      final title = 'د ${places[i % 10]} ${kws[i % 20]} پېښه ${i + 1}';
      final folder = p.join(
        root.path,
        '${d.shamsi.year}',
        PashtoMonths.shamsiDari[d.shamsi.month - 1],
        '${d.shamsi.day}',
        title,
      );
      Directory(p.join(folder, 'attachments')).createSync(recursive: true);

      final atts = [
        for (var k = 0; k <= i % 5; k++)
          Attachment(
            name: 'file_$k.${media[(i + k) % 5].extensions.first}',
            relativePath: 'attachments/file_$k',
            kind: media[(i + k) % 5],
            sizeBytes: 1024 * 1024 * (40 + (i + k) % 400),
          ),
      ];
      totalBytes += atts.fold(0, (a, b) => a + b.sizeBytes);

      final e = EventMetadata(
        id: 'ev-$i',
        title: title,
        summary: 'د ${places[i % 10]} په سیمه کې د ${cats[i % 8]} پېښې '
            'بشپړ راپور، د سترګو لیدونکو نقل قولونه او تصویري شواهد.',
        folderPath: folder,
        date: d,
        category: cats[i % 8],
        rating: i % 6,
        colorTag: ColorTag.values[i % ColorTag.values.length],
        keywords: {kws[i % 20], kws[(i * 7) % 20], kws[(i * 13) % 20]}.toList(),
        persons: {ppl[i % 8], ppl[(i * 3) % 8]}.toList(),
        attachments: atts,
        blocks: [
          Block(id: 'b1', kind: BlockKind.heading, text: title, level: 1),
          Block(id: 'b2', kind: BlockKind.paragraph,
              text: 'د دې پېښې تفصیلي راپور او شالید.'),
        ],
      );

      File(p.join(folder, 'metadata.json'))
          .writeAsStringSync(jsonEncode(e.toJson()));
    }
    final buildMs = sw.elapsedMilliseconds;

    // ═══ ۲) سکن — دقیقاً لکه پروګرام ═══
    sw.reset();
    final found = <EventMetadata>[];
    var dirsWalked = 0;
    final queue = <String>[root.path];
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      dirsWalked++;
      final meta = File(p.join(cur, 'metadata.json'));
      if (meta.existsSync()) {
        found.add(EventMetadata.fromJson(
            jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>,
            folderPath: cur));
        continue; // د پیښې دننه نه ګرځو
      }
      for (final e in Directory(cur).listSync(followLinks: false)) {
        if (e is Directory) queue.add(e.path);
      }
    }
    final scanMs = sw.elapsedMilliseconds;

    // ═══ ۳) ایندکس ═══
    final dbPath = p.join(root.path, 'index.db');
    sw.reset();
    final db = IndexDb.open(dbPath);
    db.upsertAll(found);
    final indexMs = sw.elapsedMilliseconds;
    final dbSize = File(dbPath).lengthSync();

    // ═══ ۴) پلټنې ═══
    final results = <(String, int, double)>[];
    void bench(String label, int Function() run) {
      run(); // تودوخه
      final s = Stopwatch()..start();
      const reps = 5;
      var n = 0;
      for (var i = 0; i < reps; i++) {
        n = run();
      }
      results.add((label, n, s.elapsedMicroseconds / 1000 / reps));
    }

    bench('بشپړ متن: «زلزله»',
        () => db.search(const EventQuery(text: 'زلزله', limit: 100)).length);
    bench('بشپړ متن: «کندهار امنیت»',
        () => db.search(const EventQuery(text: 'کندهار امنیت', limit: 100)).length);
    bench('لومړي حروف: «پارلم»',
        () => db.search(const EventQuery(text: 'پارلم', limit: 100)).length);
    // د فلټرونو ارزښتونه له یوې ریښتیني پیښې څخه اخلو، نو پلټنې
    // تل ریښتیني پایلې راولي — نه چې تش صفر.
    final sample = db.search(const EventQuery(limit: 1)).single;

    bench('درجه + رنګ',
        () => db.search(EventQuery(ratings: {sample.rating},
            colors: {sample.colorTag}, limit: 100)).length);
    bench('کټګوري + کیورډ',
        () => db.search(EventQuery(categories: {sample.category},
            keywords: {sample.keywords.first}, limit: 100)).length);
    bench('شخصیت',
        () => db.search(EventQuery(persons: {sample.persons.first},
            limit: 100)).length);
    bench('نېټه: ۱۴۰۴ کال (شمسي)',
        () => db.search(EventQuery(
            fromJdn: TriDate.fromShamsi(1404, 1, 1).jdn,
            toJdn: TriDate.fromShamsi(1404, 12, 29).jdn, limit: 100)).length);
    bench('نېټه: قمري ۱۴۴۵',
        () => db.search(EventQuery(
            fromJdn: TriDate.fromQamari(1445, 1, 1).jdn,
            toJdn: TriDate.fromQamari(1445, 12, 29).jdn, limit: 100)).length);
    bench('ویډیو لرونکې',
        () => db.search(EventQuery(mediaKinds: {MediaKind.video},
            limit: 100)).length);
    bench('ټول فلټرونه یوځای', () => db.search(EventQuery(
          text: 'راپور',
          ratings: {sample.rating},
          categories: {sample.category},
          keywords: {sample.keywords.first},
          persons: {sample.persons.first},
          fromJdn: TriDate.fromShamsi(1390, 1, 1).jdn,
          toJdn: TriDate.fromShamsi(1410, 12, 29).jdn,
          limit: 100,
        )).length);
    bench('ټولې فاسیټ شمېرې',
        () => db.facets(EventQuery(ratings: {sample.rating})).total);
    bench('د ډاشبورډ لنډیز', () => db.stats().eventCount);

    // ═══ راپور ═══
    final onDisk = _dirSize(root);
    print('');
    print('╔══════════════════════════════════════════════════════════╗');
    print('║  ریښتینې ازموینه — $eventCount پیښې پر ریښتیني ډیسک       ║');
    print('╚══════════════════════════════════════════════════════════╝');
    print('');
    print('  فرضي محتوا (د ضمیمو مجموعه):  ${_gb(totalBytes)}');
    print('  پر ډیسک ریښتینی حجم:          ${_mb(onDisk)}  '
        '(یوازې metadata.json)');
    print('  د ایندکس فایل:                ${_mb(dbSize)}');
    print('  فولډرونه چې وګرځول شول:       $dirsWalked');
    print('');
    print('  ── یو ځل (د پیل پر مهال) ──');
    print('  پر ډیسک جوړول:   ${buildMs}ms');
    print('  بشپړ سکن:        ${scanMs}ms   → ${found.length} پیښې');
    print('  ایندکس جوړول:    ${indexMs}ms');
    print('');
    print('  ── پلټنه (هر ځل چې کاروونکی لټوي) ──');
    for (final (label, n, ms) in results) {
      final bar = '█' * (ms.clamp(0, 40)).round();
      print('  ${label.padRight(26)}${ms.toStringAsFixed(1).padLeft(6)} ms  '
          '${n.toString().padLeft(4)} پایلې  $bar');
    }
    final slowest = results.map((r) => r.$3).reduce((a, b) => a > b ? a : b);
    print('');
    print('  ⇒ تر ټولو ورو پلټنه: ${slowest.toStringAsFixed(1)} ms');
    print('');

    db.dispose();

    // ── تایید ──
    expect(found.length, eventCount, reason: 'ټولې پیښې باید ومومل شي');
    expect(slowest, lessThan(1000),
        reason: 'هره پلټنه باید تر یوې ثانیې کمه وي');
  }, timeout: const Timeout(Duration(minutes: 30)));
}

int _dirSize(Directory d) {
  var n = 0;
  for (final e in d.listSync(recursive: true, followLinks: false)) {
    if (e is File) {
      try {
        n += e.lengthSync();
      } catch (_) {}
    }
  }
  return n;
}

String _mb(int b) => '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
String _gb(int b) => '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
