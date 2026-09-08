@TestOn('linux || mac-os || windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'dart:typed_data';

import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/text/pashto_pdf_forms.g.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/features/preview/pdf_export.dart';

/// **د پښتو تورو تړل په PDF کې.**
///
/// کاروونکي دوه ځله راپور کړه چې «د پښتو حروف د pdf دننه مات شوی
/// دی» — یعنې کلمې نه تړل کیږي: «چټک» → «چ ټ ک».
///
/// علت: د PDF کتابتون (د خپلې `bidi` کڅوړې له لارې) یوازې ۷۸
/// عربي توري پېژني او تړي. د پښتو دا لس توري پکې نشته:
///
///     ټ ځ څ ډ ړ ږ ښ ګ ڼ ۍ
///
/// حل: هر یو ته یو **پوروړی** توری ورکوو چې کتابتون یې پېژني، او
/// فونټ د پوروړي د بڼو پر ځای د پښتو ګلیفونه رسموي.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('لس واړه پښتو توري پوروړی لري', () {
    const pashto = [
      ('ټ', 0x067C),
      ('ځ', 0x0681),
      ('څ', 0x0685),
      ('ډ', 0x0689),
      ('ړ', 0x0693),
      ('ږ', 0x0696),
      ('ښ', 0x069A),
      ('ګ', 0x06AB),
      ('ڼ', 0x06BC),
      ('ۍ', 0x06CD),
    ];
    for (final (ch, cp) in pashto) {
      expect(kPashtoDonor[cp], isNotNull, reason: '$ch پوروړی نه لري');
    }
    expect(kPashtoDonor.length, pashto.length);
  });

  test('د پوروړو بڼې فونټ کې شته', () {
    // که فونټ نوی شي او سکریپټ بیا ونه چلول شي، دلته نیول کیږي.
    for (final name in ['Vazirmatn-Regular', 'Vazirmatn-Bold']) {
      final f = File('assets/fonts/$name.ttf');
      expect(f.existsSync(), isTrue, reason: '$name نشته');
      final cmap =
          TtfParser(ByteData.sublistView(f.readAsBytesSync()))
              .charToGlyphIndexMap;
      for (final cp in kDonorFormToPashto.keys) {
        expect(cmap[cp], isNotNull,
            reason: '$name کې ${cp.toRadixString(16)} نشته — '
                'tool/font/add_pashto_pdf_forms.py وچله');
      }
    }
  });

  test('متن پوروړو ته اوړي — خو یوازې هغه لس توري', () {
    // «چټک»: ټ باید ٺ شي، چ او ک بې‌بدلونه پاتې شي
    final out = EventPdf.cleanText('چټک');
    expect(out.runes.toList(), [0x0686, 0x067A, 0x06A9]);

    // عادي عربي متن هیڅ نه بدلیږي
    expect(EventPdf.cleanText('د کابل تړون').runes.contains(0x0693), isFalse,
        reason: 'ړ باید پوروړي ته واوړي');
    expect(EventPdf.cleanText('سلام'), 'سلام');
    expect(EventPdf.cleanText('E:\\Arvitch'), 'E:\\Arvitch');
  });

  test('له PDF نه کاپي شوی متن ریښتینی پښتو دی', () async {
    // **دا مهمه ده.** پوروړي یوازې د **رسمولو** لپاره دي. که
    // `ToUnicode` جدول ونه سمول شي، له PDF نه کاپي شوی متن به
    // اردو توري ولري (ٺ پر ځای ټ) — او د آرشیف لپاره دا خرابي ده.
    final e = EventMetadata(
      id: 'x',
      title: 'چټک ښکلی ګل',
      folderPath: '/tmp/x',
      date: TriDate.now(),
    );
    final bytes = await EventPdf.build(e);
    final raw = String.fromCharCodes(bytes);

    // د پوروړو کوډپوینټونه باید په ToUnicode کې پاتې نه شي
    for (final cp in kDonorFormToPashto.keys) {
      final hex = cp.toRadixString(16).toUpperCase().padLeft(4, '0');
      expect(raw.contains('<$hex>'), isFalse,
          reason: 'ToUnicode کې $hex پاتې دی — کاپي به ناسمه وي');
    }
  });
}
