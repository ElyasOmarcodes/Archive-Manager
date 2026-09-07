@TestOn('linux || mac-os || windows')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show TtfParser;

import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/theme/tokens.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/features/preview/pdf_export.dart';

/// **د PDF اکسپورټ ازموینه.**
///
/// PDF یو دودیز بڼه ده — نو دلته یې ریښتیا جوړوو او پایله څېړو،
/// نه یوازې دا چې «استثنا یې ونه اچوله».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EventMetadata sample() => EventMetadata(
        id: 'pdf-1',
        title: 'د کابل او چین تړون',
        folderPath: '/tmp/x',
        date: TriDate.fromShamsi(1405, 6, 13),
        category: 'سیاسي',
        summary: 'د دواړو هیوادونو ترمنځ د اقتصادي همکارۍ تړون.',
        rating: 5,
        colorTag: ColorTag.red,
        keywords: const ['تړون', 'چین', 'اقتصاد'],
        persons: const ['حامد کرزی', 'لي جیانګ'],
        blocks: [
          Block(id: 'b1', kind: BlockKind.heading, text: 'پس‌منظر', level: 2),
          Block(
              id: 'b2',
              kind: BlockKind.paragraph,
              text: 'بشپړ راپور: https://arvitch.example.af/1 وګورئ.'),
          Block(
              id: 'b3',
              kind: BlockKind.quote,
              text: 'دا تړون د سیمې لپاره مهم دی.',
              author: 'حامد کرزی'),
          // دا درې په PDF کې نه چلیږي — یوازې کارت باید ورکړي
          Block(
              id: 'b4',
              kind: BlockKind.video,
              source: 'attachments/v1.mp4',
              caption: 'د لاسلیک ویډیو'),
          Block(
              id: 'b5',
              kind: BlockKind.audio,
              source: 'attachments/a1.wav',
              caption: 'د مرکې غږ'),
          Block(id: 'b6', kind: BlockKind.divider),
        ],
        attachments: const [
          Attachment(
              name: 'v1.mp4',
              relativePath: 'attachments/v1.mp4',
              kind: MediaKind.video,
              sizeBytes: 4200000),
          Attachment(
              name: 'a1.wav',
              relativePath: 'attachments/a1.wav',
              kind: MediaKind.audio,
              sizeBytes: 980000),
        ],
      );

  test('PDF جوړیږي او سم PDF فایل دی', () async {
    final bytes = await EventPdf.build(sample());

    expect(bytes.length, greaterThan(3000), reason: 'تش فایل نه دی');
    // د PDF لاسلیک
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // او سم پای لري
    final tail = String.fromCharCodes(bytes.skip(bytes.length - 32));
    expect(tail.contains('%%EOF'), isTrue, reason: 'بشپړ لیکل شوی');
  });

  test('میټاډیټا د فایل دننه ځای پر ځای کیږي', () async {
    final bytes = await EventPdf.build(sample());
    final raw = String.fromCharCodes(bytes);
    // د PDF خپل ډګرونه (کیدی شي کمپرس شوي وي، نو یوازې کلیدونه ګورو)
    expect(raw.contains('/Title') || raw.contains('/Info'), isTrue);
    expect(raw.contains('/Creator') || raw.contains('/Producer'), isTrue);
  });

  test('اصلي metadata.json د PDF ریښتینې ضمیمه ده', () async {
    // **دا تر رسمولو ډېر مهم دی.** که یوازې په پاڼه کې ولیکل
    // شي، بېرته یې نه شې راایستلی. دلته یې د PDF د ضمیمو
    // (`/EmbeddedFiles`) په بڼه ږدو — نو Acrobat او هر معیاري
    // لوستونکی یې د فایل په توګه راکوي، او پیښه له PDF نه بیا
    // جوړېدلی شي.
    final e = sample();
    final bytes = await EventPdf.build(e);
    final raw = String.fromCharCodes(bytes);

    expect(raw, contains('/EmbeddedFiles'));
    expect(raw, contains('/Filespec'));
    expect(raw, contains('metadata.json'));
    expect(raw, contains('content.json'));

    // د ضمیمې منځپانګه کمپرس شوې نه ده — نو ریښتیا یې ګورو.
    expect(raw, contains('"id": "${e.id}"'));
    expect(raw, contains('"jdn": ${e.date.jdn}'));
    // د بلاکونو منځپانګه هم
    expect(raw, contains('"kind": "quote"'));
  });

  test('د ویډیو/غږ لپاره یوازې کارت راځي — نه ماته پاڼه', () async {
    // که دا استثنا اچوله، دلته به ماته وخوري
    final bytes = await EventPdf.build(sample());
    expect(bytes.length, greaterThan(3000));
  });

  test('انځور چې ونه موندل شي، پاڼه نه ماتوي', () async {
    final e = sample()
      ..blocks.add(Block(
          id: 'b7',
          kind: BlockKind.image,
          source: 'attachments/missing.jpg',
          caption: 'ورک انځور'));
    final bytes = await EventPdf.build(e); // هیڅ انځور نه ورکوو
    expect(bytes.length, greaterThan(3000));
  });

  test('ریښتینی انځور پکې ځای پر ځای کیږي', () async {
    // یو کوچنی ریښتینی PNG جوړوو
    final png = File('tool/sample-media/img1.png');
    if (!png.existsSync()) return; // د نمونې مېډیا نشته

    final e = sample()
      ..blocks.add(Block(
          id: 'b8',
          kind: BlockKind.image,
          source: 'attachments/i.png',
          caption: 'بېلګه'));

    final without = await EventPdf.build(e);
    final with_ = await EventPdf.build(e,
        images: {'attachments/i.png': png.readAsBytesSync()});

    expect(with_.length, greaterThan(without.length),
        reason: 'انځور باید حجم زیات کړي');
  });

  test('تش پیښه هم PDF ورکوي', () async {
    final e = EventMetadata(
      id: 'e',
      title: 'تشه',
      folderPath: '/tmp/x',
      date: TriDate.now(),
    );
    final bytes = await EventPdf.build(e);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('هیڅ رسم د پاڼې له پولې بهر نه ځي', () async {
    // **ولې دا ازموینه؟**
    //
    // `pw.BorderRadius.circular(999)` په فلټر کې بې‌ضرره ده —
    // فلټر یې پخپله راکموي. د `pdf` کتابتون یې نه کموي: د ګردې
    // څنډې منحني د بکس له پولې سلګونه پوینټه بهر ځي، او پایله
    // یې دا وه چې یوه پلنه رنګه ساحه **د پاڼې پورتنۍ نیمه برخه
    // یې پوښله** — سرلیک، درې‌ګونې نېټه او ټګونه ټول پټ شول.
    //
    // بایټونه سم وو، متن یې هم راایستل کېده — نو یوازې «PDF جوړ
    // شو» ازموینې دا ونه نیوله. دلته د رسم اصلي کوردیناټونه
    // ګورو: هر رقم باید د A4 پاڼې دننه (یو څه رخصت سره) وي.
    final e = sample();
    final bytes = await EventPdf.build(e, compress: false);
    final text = String.fromCharCodes(bytes);

    // د رسم چلونه: m/l (ټکی)، c (بېزیه، درې ټکي)، re (مستطیل)
    final ops = RegExp(
        r'(-?\d+(?:\.\d+)?(?:\s+-?\d+(?:\.\d+)?)*)\s+(m|l|c|re)(?=[\s\n])');
    var checked = 0;
    for (final m in ops.allMatches(text)) {
      final nums = m
          .group(1)!
          .split(RegExp(r'\s+'))
          .map(double.parse)
          .toList(growable: false);
      // د A4 اندازه ۵۹۵×۸۴۲ ده؛ ۶۰ پوینټه رخصت ورکوو
      // (د سیوري او څنډې لپاره).
      for (final v in nums) {
        expect(v, greaterThan(-60),
            reason: 'د پاڼې له پولې بهر رسم: «${m.group(0)}»');
        expect(v, lessThan(902),
            reason: 'د پاڼې له پولې بهر رسم: «${m.group(0)}»');
      }
      checked++;
    }
    expect(checked, greaterThan(20),
        reason: 'که رسم ونه موندل شو، ازموینه بې‌معنا ده');
  });

  test('فونټ د پښتو «ې» پیشکش‌بڼې لري — ګنې PDF یې ماتوي', () {
    // **کیسه:** د `pdf` کتابتون خپل عربي شکل‌ورکوونکی لري چې هر
    // توری د خپل ځای له مخې یوې زړې Presentation Form ته اړوي
    // (ې → U+FBE4…FBE7)، بیا هغه کوډپوینټ په فونټ کې لټوي.
    // Vazirmatn (لکه ډېر عصري فونټونه) دا زړې بڼې نه لري — نو
    // «کې»، «ضمیمې»، «یې» ټول په PDF کې یو بې‌ربطه توری ښودل.
    //
    // `tool/font/add_pashto_pdf_forms.py` دا کرښې فونټ ته
    // ورزیاتوي. دا ازموینه ساتي چې د فونټ راتلونکی اپډیټ یې
    // بېرته ونه غورځوي.
    for (final name in ['Vazirmatn-Regular', 'Vazirmatn-Bold']) {
      final f = File('assets/fonts/$name.ttf');
      expect(f.existsSync(), isTrue, reason: '$name نشته');
      final cmap = TtfParser(ByteData.sublistView(f.readAsBytesSync())).charToGlyphIndexMap;
      for (final cp in [0xFBE4, 0xFBE5, 0xFBE6, 0xFBE7]) {
        expect(cmap[cp], isNotNull,
            reason: '$name کې د ې بڼه ${cp.toRadixString(16)} نشته — '
                'tool/font/add_pashto_pdf_forms.py وچله');
      }
    }
  });
}
