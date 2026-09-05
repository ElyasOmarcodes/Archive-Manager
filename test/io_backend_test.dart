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
import 'package:archive_manager/features/editor/html_builder.dart';

/// د ریښتیني فایل سیسټم پر سر ازموینه — د پیښې فولډر جوړول،
/// `metadata.json` لیکل/لوستل، بیا سکن او لټون.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('arv_test_'));
  tearDown(() => root.deleteSync(recursive: true));

  /// د اتومات حالت فولډر — دقیقاً هغه منطق چې IoBackend یې کاروي.
  String autoFolder(String base, TriDate d, String title) => p.join(
        base,
        '${d.shamsi.year}',
        PashtoMonths.shamsiDari[d.shamsi.month - 1],
        '${d.shamsi.day}',
        title,
      );

  test('auto folder layout matches the requested E:\\Arvitch\\1405\\سنبله\\13 shape',
      () {
    final d = TriDate.fromShamsi(1405, 6, 13);
    final folder = autoFolder(root.path, d, 'د کابل او چین تړون');
    Directory(folder).createSync(recursive: true);

    final rel = p.relative(folder, from: root.path);
    expect(p.split(rel), ['1405', 'سنبله', '13', 'د کابل او چین تړون']);
    expect(Directory(folder).existsSync(), isTrue);
  });

  test('event round-trips through metadata.json and the index', () async {
    final d = TriDate.fromShamsi(1405, 6, 13);
    final folder = autoFolder(root.path, d, 'د کابل او چین تړون');
    Directory(p.join(folder, 'attachments')).createSync(recursive: true);

    // یو ریښتینی ضمیمه فایل جوړوو
    final att = File(p.join(folder, 'attachments', 'evidence_img_01.jpg'))
      ..writeAsBytesSync(List.filled(2048, 7));

    final event = EventMetadata(
      id: 'ev-1',
      title: 'د کابل او چین تړون',
      folderPath: folder,
      date: d,
      category: 'سیاسي',
      summary: 'مهم تړون لاسلیک شو',
      rating: 5,
      colorTag: ColorTag.red,
      keywords: ['تړون', 'چین'],
      persons: ['حامد کرزی'],
      attachments: [
        Attachment(
          name: 'evidence_img_01.jpg',
          relativePath: 'attachments/evidence_img_01.jpg',
          kind: MediaKind.image,
          sizeBytes: att.lengthSync(),
        ),
      ],
      blocks: [
        Block(id: 'b1', kind: BlockKind.heading, text: 'سریزه', level: 2),
        Block(
            id: 'b2',
            kind: BlockKind.image,
            source: 'attachments/evidence_img_01.jpg',
            caption: 'د غونډې انځور'),
      ],
    );

    // ── پر ډیسک لیکل: metadata.json + index.html ──
    File(p.join(folder, 'metadata.json')).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(event.toJson()));
    File(p.join(folder, 'index.html'))
        .writeAsStringSync(buildEventHtml(event));

    expect(File(p.join(folder, 'metadata.json')).existsSync(), isTrue);
    expect(File(p.join(folder, 'index.html')).existsSync(), isTrue);

    // د جوړ شوي HTML دننه ریښتیني نسبي مسیر وي — نو براوزر یې مومي
    final html = File(p.join(folder, 'index.html')).readAsStringSync();
    expect(html, contains('src="attachments/evidence_img_01.jpg"'));

    // ── بیا لوستل (هغه څه چې سکن کوي) ──
    final reread = EventMetadata.fromJson(
      jsonDecode(File(p.join(folder, 'metadata.json')).readAsStringSync())
          as Map<String, dynamic>,
      folderPath: folder,
    );
    expect(reread.title, event.title);
    expect(reread.date.jdn, event.date.jdn);
    expect(reread.date.shamsi.year, 1405);
    expect(reread.keywords, event.keywords);
    expect(reread.persons, event.persons);
    expect(reread.rating, 5);
    expect(reread.colorTag, ColorTag.red);
    expect(reread.attachments.single.sizeBytes, 2048);
    expect(reread.blocks.length, 2);

    // ── ایندکس ته ورکول او لټون ──
    final db = IndexDb.open(p.join(root.path, 'index.db'));
    db.upsertAll([reread]);

    expect(db.search(const EventQuery(text: 'کابل')).single.id, 'ev-1');
    expect(db.search(EventQuery(keywords: {'چین'})).length, 1);
    expect(db.search(EventQuery(persons: {'حامد کرزی'})).length, 1);
    expect(
        db.search(EventQuery(
          fromJdn: TriDate.fromShamsi(1405, 1, 1).jdn,
          toJdn: TriDate.fromShamsi(1405, 12, 29).jdn,
        )).length,
        1);
    expect(db.stats().totalBytes, 2048);
    db.dispose();

    // ډیټابیس ریښتیا پر ډیسک جوړ شو
    expect(File(p.join(root.path, 'index.db')).existsSync(), isTrue);
  });

  test('the index rebuilds itself from metadata.json files alone', () {
    // درې پیښې پر ډیسک جوړوو — هیڅ ډیټابیس نشته
    for (var i = 0; i < 3; i++) {
      final d = TriDate.fromShamsi(1405, 6, 10 + i);
      final folder = autoFolder(root.path, d, 'پیښه $i');
      Directory(folder).createSync(recursive: true);
      final e = EventMetadata(
        id: 'e$i',
        title: 'پیښه $i',
        folderPath: folder,
        date: d,
        category: 'سیاسي',
        keywords: ['ازموینه'],
      );
      File(p.join(folder, 'metadata.json'))
          .writeAsStringSync(jsonEncode(e.toJson()));
    }

    // سکن: ټول metadata.json فایلونه ومومه
    final found = <EventMetadata>[];
    for (final f in root.listSync(recursive: true)) {
      if (f is File && p.basename(f.path) == 'metadata.json') {
        found.add(EventMetadata.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
            folderPath: p.dirname(f.path)));
      }
    }
    expect(found.length, 3);

    final db = IndexDb.openMemory();
    db.upsertAll(found);
    expect(db.count(const EventQuery()), 3);
    expect(db.search(EventQuery(keywords: {'ازموینه'})).length, 3);
    db.dispose();
  });

  test('windows-illegal characters are stripped from folder names', () {
    // همغه منطق چې IoBackend._sanitize یې کاروي
    String sanitize(String name) {
      var s = name.trim().replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ');
      s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      s = s.replaceAll(RegExp(r'[. ]+$'), '');
      if (s.isEmpty) s = 'بې‌نومه پیښه';
      return s.length > 120 ? s.substring(0, 120) : s;
    }

    expect(sanitize('د کابل: تړون/۲۰۲۶'), 'د کابل تړون ۲۰۲۶');
    expect(sanitize('a<b>c|d?e*f'), 'a b c d e f');
    expect(sanitize('نوم.'), 'نوم');
    expect(sanitize('   '), 'بې‌نومه پیښه');
    expect(sanitize('x' * 200).length, 120);

    // او دا نومونه ریښتیا پر ډیسک جوړېدی شي
    final dir = Directory(p.join(root.path, sanitize('د کابل: تړون/۲۰۲۶')));
    dir.createSync(recursive: true);
    expect(dir.existsSync(), isTrue);
  });
}
