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

    // ── پر ډیسک لیکل: metadata.json + content.json + index.html ──
    File(p.join(folder, 'metadata.json'))
        .writeAsStringSync(jsonEncode(event.toJson()));
    File(p.join(folder, 'content.json'))
        .writeAsStringSync(jsonEncode(event.toContentJson()));
    File(p.join(folder, 'index.html'))
        .writeAsStringSync(buildEventHtml(event));

    expect(File(p.join(folder, 'metadata.json')).existsSync(), isTrue);
    expect(File(p.join(folder, 'content.json')).existsSync(), isTrue);
    expect(File(p.join(folder, 'index.html')).existsSync(), isTrue);

    // `metadata.json` باید یوازې د فلټر ډګرونه ولري — نه بلاکونه، نه ضمیمې.
    final metaJson = jsonDecode(
        File(p.join(folder, 'metadata.json')).readAsStringSync()) as Map;
    expect(metaJson.containsKey('blocks'), isFalse);
    expect(metaJson.containsKey('attachments'), isFalse);
    expect(metaJson['jdn'], event.date.jdn);

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
    // لنډیز په `metadata.json` کې پاتې دی، نو کارتونه او فلټر بې محتوا کار کوي.
    expect(reread.contentLoaded, isFalse);
    expect(reread.attachmentCount, 1);
    expect(reread.totalBytes, 2048);
    expect(reread.mediaBreakdown[MediaKind.image], 1);

    // بشپړه محتوا یوازې پر غوښتنه راځي.
    reread.applyContent(jsonDecode(
        File(p.join(folder, 'content.json')).readAsStringSync())
        as Map<String, dynamic>);
    expect(reread.contentLoaded, isTrue);
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

  test('legacy v1 metadata.json still loads and upgrades on save', () {
    // د پروګرام زړې نسخې دا بڼه لیکله — محتوا دننه، نېټه درې واره.
    final legacy = {
      'schemaVersion': 1,
      'id': 'old-1',
      'title': 'زړه پیښه',
      'category': 'امنیتي',
      'summary': 'لنډیز',
      'date': TriDate.fromShamsi(1403, 5, 12).toJson(),
      'rating': 4,
      'colorTag': 'green',
      'keywords': ['کابل'],
      'persons': ['احمد'],
      'links': ['https://example.com'],
      'blocks': [
        {'id': 'b1', 'kind': 'paragraph', 'text': 'د زړې بڼې متن'},
      ],
      'attachments': [
        {
          'name': 'a.jpg',
          'path': 'attachments/a.jpg',
          'kind': 'image',
          'size': 512,
        },
      ],
      'createdAt': DateTime(2024, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2024, 1, 2).toIso8601String(),
    };

    final folder = p.join(root.path, 'legacy');
    Directory(folder).createSync(recursive: true);
    File(p.join(folder, 'metadata.json'))
        .writeAsStringSync(jsonEncode(legacy));

    final e = EventMetadata.fromJson(
        jsonDecode(File(p.join(folder, 'metadata.json')).readAsStringSync())
            as Map<String, dynamic>,
        folderPath: folder);

    // هیڅ ډیټا نه ده ورکه شوې
    expect(e.title, 'زړه پیښه');
    expect(e.date.shamsi.year, 1403);
    expect(e.date.shamsi.month, 5);
    expect(e.rating, 4);
    expect(e.colorTag, ColorTag.green);
    expect(e.blocks.single.text, 'د زړې بڼې متن');
    expect(e.attachments.single.sizeBytes, 512);
    expect(e.contentLoaded, isTrue);

    // او د بیا‌ثبت پر مهال پخپله نوې بڼې ته اوړي
    final upgraded = jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>;
    expect(upgraded['v'], EventMetadata.currentSchema);
    expect(upgraded.containsKey('blocks'), isFalse);
    expect(upgraded['jdn'], e.date.jdn);
    expect(upgraded['files'], 1);
    expect(upgraded['bytes'], 512);
    expect(upgraded['media'], {'image': 1});
    expect(upgraded['text'], contains('د زړې بڼې متن'));
  });

  test('the slim metadata.json is much smaller than the old whole-event form',
      () {
    final e = EventMetadata(
      id: 'sz-1',
      title: 'د اندازې ازموینه',
      folderPath: root.path,
      date: TriDate.fromShamsi(1405, 6, 13),
      category: 'سیاسي',
      summary: 'د پېښې لنډیز چې په کارت کې ښکاري.',
      rating: 3,
      colorTag: ColorTag.blue,
      keywords: const ['کابل', 'چین', 'تړون'],
      persons: const ['حامد کرزی'],
      blocks: [
        for (var i = 0; i < 6; i++)
          Block(
              id: 'b$i',
              kind: i.isEven ? BlockKind.paragraph : BlockKind.image,
              text: i.isEven ? 'د پېښې د متن پیرګراف شمېره $i' : '',
              source: i.isEven ? '' : 'attachments/p$i.jpg',
              caption: i.isEven ? '' : 'د انځور سرلیک $i'),
      ],
      attachments: [
        for (var i = 0; i < 4; i++)
          Attachment(
              name: 'f$i.jpg',
              relativePath: 'attachments/f$i.jpg',
              kind: MediaKind.image,
              sizeBytes: 1024 * (i + 1)),
      ],
    );

    final slim = jsonEncode(e.toJson());
    final content = jsonEncode(e.toContentJson());

    // ټول‌شموله بڼه = هغه څه چې پخوا په یوه فایل کې و
    final whole = jsonEncode({
      ...jsonDecode(slim) as Map<String, dynamic>,
      ...jsonDecode(content) as Map<String, dynamic>,
      'date': e.date.toJson(),
    });

    // د فلټر فایل باید د پخوانۍ بڼې نیمایي هم نه وي
    expect(slim.length, lessThan(whole.length ~/ 2));
    // او یوه کرښه وي، نه سلګونه
    expect('\n'.allMatches(slim).length, 0);
  });
}
