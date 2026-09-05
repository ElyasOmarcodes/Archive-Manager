// د نمونې آرشیف جوړونکی.
// ignore_for_file: avoid_print
@TestOn('linux || mac-os || windows')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/theme/tokens.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/features/editor/html_builder.dart';

/// **د نمونې آرشیف جوړونکی.**
///
/// د پروګرام له ریښتینو ماډلونو (`EventMetadata`, `buildEventHtml`) کار
/// اخلي — نو د `metadata.json` بڼه دقیقاً هغه ده چې پروګرام یې لولي.
/// که سکیما بدله شي، دا فایل هم پخپله ورسره سم راځي.
///
/// چلول:
/// ```
/// MEDIA=<dir> OUT=<dir> COUNT=3000 HTML=300 \
///   flutter test tool/make_sample_archive.dart
/// ```
void main() {
  test('build sample archive', () {
    final media = Platform.environment['MEDIA']!;
    final out = Directory(Platform.environment['OUT']!);
    final count = int.parse(Platform.environment['COUNT'] ?? '3000');
    final htmlCount = int.parse(Platform.environment['HTML'] ?? '300');

    if (out.existsSync()) out.deleteSync(recursive: true);
    out.createSync(recursive: true);

    // د تصادف تخم ثابت دی — نو هر ځل هماغه آرشیف جوړیږي.
    final rnd = Random(20260905);

    // ── د مېډیا حوض ──
    final pool = <MediaKind, List<String>>{
      MediaKind.image: [for (var i = 1; i <= 6; i++) 'img$i.png'],
      MediaKind.video: [for (var i = 1; i <= 3; i++) 'video$i.mp4'],
      MediaKind.audio: [for (var i = 1; i <= 2; i++) 'audio$i.wav'],
      MediaKind.document: ['report.pdf', 'note.txt'],
      MediaKind.sheet: ['data.csv'],
    };
    final poolBytes = {
      for (final e in pool.entries)
        for (final f in e.value) f: File(p.join(media, f)).readAsBytesSync(),
    };

    // ── د پیښو د جوړولو مواد ──
    const cats = ['سیاسي', 'امنیتي', 'اقتصادي', 'ټولنیز', 'کلتوري',
                  'ورزشي', 'طبیعي پېښه', 'روغتیا', 'ښوونه او روزنه'];
    const kws = ['تړون','چین','امنیت','پارلمان','ولسمشر','بریدونه','سوله',
                 'کډوال','بودیجه','زلزله','لوبې','ښوونځی','روغتیا','بند',
                 'معدن','انرژي','اوبه','کرنه','ښار','سرحد','لاریون',
                 'انتخابات','مرستې','ترانسپورت','سیلاب','واکسین'];
    const ppl = ['حامد کرزی','اشرف غني','عبدالله عبدالله','محمد نبي احمدزی',
                 'زرمینه کریمي','نجیبه رحیمي','راشد خان','ډاکټر سمیع الله',
                 'پوهاند رحمت','انجنیر شفیق','ډاکټره فرشته','محمد کریم'];
    const places = ['کابل','کندهار','هرات','بلخ','ننګرهار','بدخشان','هلمند',
                    'بامیان','کنړ','پکتیا','غزني','فاریاب','لغمان','تخار'];
    const forms = ['راپور','غونډه','پېښه','څېړنه','مرکه','اعلامیه','لاریون',
                   'مراسم','تړون','کنفرانس'];

    var totalAtt = 0, totalBytes = 0;
    final byYear = <int, int>{};

    for (var i = 0; i < count; i++) {
      // نېټې په ۱۰ کلونو کې خپرې دي
      final d = TriDate.fromJdn(
          TriDate.fromShamsi(1396, 1, 1).jdn + rnd.nextInt(3650));
      byYear[d.shamsi.year] = (byYear[d.shamsi.year] ?? 0) + 1;

      final place = places[rnd.nextInt(places.length)];
      final form = forms[rnd.nextInt(forms.length)];
      final cat = cats[rnd.nextInt(cats.length)];
      final title = 'د $place د $form پېښه ${i + 1}';

      final folder = p.join(
        out.path,
        '${d.shamsi.year}',
        PashtoMonths.shamsiDari[d.shamsi.month - 1],
        '${d.shamsi.day}',
        title,
      );
      final attDir = Directory(p.join(folder, 'attachments'));
      attDir.createSync(recursive: true);

      // ── ضمیمې: ۱..۴ ریښتیني فایلونه ──
      final atts = <Attachment>[];
      final n = 1 + rnd.nextInt(4);
      for (var k = 0; k < n; k++) {
        // انځورونه ډېر عام دي، بیا ویډیو/غږ، بیا سندونه
        final r = rnd.nextInt(100);
        final kind = r < 45
            ? MediaKind.image
            : r < 68
                ? MediaKind.video
                : r < 84
                    ? MediaKind.audio
                    : r < 95
                        ? MediaKind.document
                        : MediaKind.sheet;
        final src = pool[kind]![rnd.nextInt(pool[kind]!.length)];
        final ext = p.extension(src);
        final name = switch (kind) {
          MediaKind.image => 'evidence_img_${k + 1}$ext',
          MediaKind.video => 'doc_video_${k + 1}$ext',
          MediaKind.audio => 'statement_audio_${k + 1}$ext',
          MediaKind.sheet => 'data_${k + 1}$ext',
          _ => 'report_${k + 1}$ext',
        };
        final bytes = poolBytes[src]!;
        File(p.join(attDir.path, name)).writeAsBytesSync(bytes);
        atts.add(Attachment(
          name: name,
          relativePath: 'attachments/$name',
          kind: kind,
          sizeBytes: bytes.length,
        ));
        totalBytes += bytes.length;
      }
      totalAtt += atts.length;

      // ── کیورډونه او اشخاص ──
      final kw = <String>{};
      for (var j = 0; j < 2 + rnd.nextInt(3); j++) {
        kw.add(kws[rnd.nextInt(kws.length)]);
      }
      final ps = <String>{};
      for (var j = 0; j < 1 + rnd.nextInt(2); j++) {
        ps.add(ppl[rnd.nextInt(ppl.length)]);
      }

      // ── بلاکونه ──
      final blocks = <Block>[
        Block(id: 'b1', kind: BlockKind.heading, text: title, level: 1),
        Block(
            id: 'b2',
            kind: BlockKind.paragraph,
            text: 'د $place په سیمه کې د $cat په برخه کې دا $form '
                'ترسره شو. لاندې د پېښې تصویري، صوتي او سندي شواهد '
                'راټول شوي دي.'),
        if (ps.isNotEmpty)
          Block(
              id: 'b3',
              kind: BlockKind.quote,
              text: 'دا پېښه د سیمې د خلکو لپاره ډېره مهمه ده او '
                  'مونږ یې ټول اړخونه څېړو.',
              author: ps.first),
        for (var k = 0; k < atts.length; k++)
          Block(
            id: 'b${4 + k}',
            kind: switch (atts[k].kind) {
              MediaKind.image => BlockKind.image,
              MediaKind.video => BlockKind.video,
              MediaKind.audio => BlockKind.audio,
              _ => BlockKind.file,
            },
            source: atts[k].relativePath,
            caption: '${atts[k].kind.label} — $place',
          ),
      ];

      final e = EventMetadata(
        id: 'sample-${i.toString().padLeft(5, '0')}',
        title: title,
        summary: 'د $place په $form کې د $cat اړوند بشپړ راپور، '
            'د سترګو لیدونکو نقل قولونه او لومړني شواهد.',
        folderPath: folder,
        date: d,
        category: cat,
        rating: rnd.nextInt(6),
        colorTag: ColorTag.values[rnd.nextInt(ColorTag.values.length)],
        keywords: kw.toList(),
        persons: ps.toList(),
        attachments: atts,
        blocks: blocks,
      );

      File(p.join(folder, 'metadata.json')).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(e.toJson()));

      // ── index.html یوازې د یوې برخې لپاره (د حجم د کمولو لپاره) ──
      if (i < htmlCount) {
        final rel = p.relative(p.join(out.path, '_arvitch', 'fonts'),
            from: folder).replaceAll(r'\', '/');
        File(p.join(folder, 'index.html'))
            .writeAsStringSync(buildEventHtml(e, fontDir: rel));
      }
    }

    print('EVENTS=$count ATTACHMENTS=$totalAtt BYTES=$totalBytes');
    print('YEARS=${(byYear.keys.toList()..sort()).join(",")}');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
