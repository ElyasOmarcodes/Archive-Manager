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

    // ── فونټونه — دقیقاً هغه ځای چې پروګرام یې لیکي ──
    final fontDir = Directory(p.join(out.path, '_arvitch', 'fonts'))
      ..createSync(recursive: true);
    for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      final src = File('assets/webfonts/Vazirmatn-$w.woff2');
      if (src.existsSync()) {
        src.copySync(p.join(fontDir.path, 'Vazirmatn-$w.woff2'));
      }
    }

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
                  'ورزشي', 'طبیعي پېښه', 'روغتیا', 'ښوونه او روزنه',
                  'کرنه او مالداري', 'چاپېریال', 'ترانسپورت', 'رسنۍ',
                  'بشري حقونه', 'کډوال', 'ښاري پراختیا', 'انرژي',
                  'عدلي او قضایي', 'بهرني اړیکې', 'ټکنالوژي'];
    const kws = ['تړون','چین','امنیت','پارلمان','ولسمشر','بریدونه','سوله',
                 'کډوال','بودیجه','زلزله','لوبې','ښوونځی','روغتیا','بند',
                 'معدن','انرژي','اوبه','کرنه','ښار','سرحد','لاریون',
                 'انتخابات','مرستې','ترانسپورت','سیلاب','واکسین',
                 'وچکالي','لوېدنه','بیارغونه','پانګونه','سوداګري','ګمرک',
                 'پوهنتون','ښځې','ماشومان','معلولین','رسنۍ','خبریالان',
                 'قضاوت','زندان','پولیس','اردو','هوایي','سړک','پل',
                 'بریښنا','لمریزه','ګاز','تېل','نښتر','ځنګل','چاپېریال',
                 'اقلیم','واورې','باران','غنم','مڼې','زعفران','قالین',
                 'صادرات','واردات','بانک','افغانۍ','ډالر','نرخونه',
                 'روغتون','درملتون','ډاکټران','واکسین','ناروغي','ناروغان',
                 'کرکټ','فوټبال','پهلواني','المپیک','لوبغالی','ټیم',
                 'موسیقي','شعر','لیکوال','کتاب','نندارتون','میراث',
                 'آثار','جومات','زیارت','ژبه','پښتو','دري','ترجمه',
                 'انټرنیټ','ټلیفون','کمپیوټر','ټکنالوژي','مصنوعي ځیرکتیا'];
    const ppl = ['حامد کرزی','اشرف غني','عبدالله عبدالله','محمد نبي احمدزی',
                 'زرمینه کریمي','نجیبه رحیمي','راشد خان','ډاکټر سمیع الله',
                 'پوهاند رحمت','انجنیر شفیق','ډاکټره فرشته','محمد کریم',
                 'ښاغلی نصیر احمد','ښاغلې مریم صافي','پوهنمل عبدالباري',
                 'انجنیر زلمی','ډاکټر نجیب الله','استاد شریفه','حاجي ولي محمد',
                 'ښاغلی احسان الله','ښاغلې پروین حبیب','ډاکټر مجیب الرحمن',
                 'پوهاند سید عمر','انجنیره فرزانه','ښاغلی خالد نوري',
                 'ښاغلې سمیرا اکبري','ډاکټر شفیع الله','استاد نور محمد',
                 'ښاغلی جاوید احمدي','ښاغلې لیلا رسولي','محمد ابراهیم زدران',
                 'ډاکټره ماریا څپاند','پوهنیار عبدالحق','انجنیر مسعود',
                 'ښاغلی طاهر شاه','ښاغلې زرغونه ستانکزۍ','حاجي عبدالغني'];
    const places = ['کابل','کندهار','هرات','بلخ','ننګرهار','بدخشان','هلمند',
                    'بامیان','کنړ','پکتیا','غزني','فاریاب','لغمان','تخار',
                    'پکتیکا','خوست','لوګر','وردګ','پروان','کاپیسا','پنجشیر',
                    'بغلان','کندز','سمنګان','سرپل','جوزجان','بادغیس',
                    'غور','دایکندی','ارزګان','زابل','نیمروز','فراه','نورستان'];
    const forms = ['راپور','غونډه','پېښه','څېړنه','مرکه','اعلامیه','لاریون',
                   'مراسم','تړون','کنفرانس','سیمینار','ورکشاپ','نندارتون',
                   'پرانیستنه','لاسلیک','سفر','لیدنه','پرېکړه','ازموینه',
                   'سروې','ارزونه','بیارغونه','پیل','پای','یادونه'];

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
            // د متن جوړښت هم بدلیږي، نو ټولې پیښې یو شان نه ښکاري.
            // په ځینو کې لینک هم شته — د اتومات لینکفای ازموینه.
            text: switch (i % 4) {
              0 => 'د $place په سیمه کې د $cat په برخه کې دا $form '
                  'ترسره شو. لاندې د پېښې تصویري، صوتي او سندي شواهد '
                  'راټول شوي دي.',
              1 => 'دا $form د ${d.shamsiText} په نېټه په $place کې پیل '
                  'شو. د $cat اړوند مسؤولینو پکې برخه اخیستې وه. '
                  'بشپړ راپور: https://arvitch.example.af/$i',
              2 => 'زمونږ خبریال له $place څخه راپور ورکوي چې د $cat په '
                  'برخه کې یو مهم $form ترسره شو. د سیمې اوسېدونکو د '
                  'خپلو غوښتنو په اړه خبرې وکړې.',
              _ => 'د $cat په اړه دا $form د $place په مرکز کې جوړ شو. '
                  'د نورو معلوماتو لپاره: www.arvitch.example.af/$i '
                  'یا اړیکه: archive@arvitch.example.af',
            }),
        if (ps.isNotEmpty)
          Block(
              id: 'b3',
              kind: BlockKind.quote,
              text: switch (i % 3) {
                0 => 'دا پېښه د سیمې د خلکو لپاره ډېره مهمه ده او '
                    'مونږ یې ټول اړخونه څېړو.',
                1 => 'مونږ ژمن یو چې د $place خلکو ته سم او په وخت '
                    'معلومات ورسوو.',
                _ => 'دا لومړی ځل دی چې په دې برخه کې داسې یو ګام '
                    'اخیستل کیږي — او دا یوازې پیل دی.',
              },
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
        summary: switch (i % 3) {
          0 => 'د $place په $form کې د $cat اړوند بشپړ راپور، '
              'د سترګو لیدونکو نقل قولونه او لومړني شواهد.',
          1 => 'د $cat په برخه کې د $place پېښې لنډیز — سندونه، '
              'انځورونه او د ګډونوالو څرګندونې.',
          _ => 'دا دوسیه د $place د $form ټول اسناد راټولوي: '
              'تصویري، صوتي او لیکلي شواهد.',
        },
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

      // دوه فایله: وړوکی `metadata.json` (فلټر) + `content.json` (محتوا).
      File(p.join(folder, 'metadata.json'))
          .writeAsStringSync(jsonEncode(e.toJson()));
      File(p.join(folder, 'content.json'))
          .writeAsStringSync(jsonEncode(e.toContentJson()));

      // ── index.html یوازې د یوې برخې لپاره (د حجم د کمولو لپاره) ──
      if (i < htmlCount) {
        final rel = p.relative(p.join(out.path, '_arvitch', 'fonts'),
            from: folder).replaceAll(r'\', '/');
        File(p.join(folder, 'index.html'))
            .writeAsStringSync(buildEventHtml(e, fontDir: rel));
      }
    }

    // ── د کاروونکي لپاره لارښود ──
    final years = (byYear.keys.toList()..sort());
    String n(int v) => PashtoDigits.to(_thousands(v));
    File(p.join(out.path, 'README.txt')).writeAsStringSync('''
د آرشیف چټک مدیر — د ازموینې نمونه آرشیف
=========================================

دا یو **فرضي** آرشیف دی چې د پروګرام د ازموینې لپاره جوړ شوی.
هیڅ ریښتینې ډیټا پکې نشته — ټول نومونه، پېښې او اشخاص جوړ شوي دي.

څه پکې دي؟
-----------
  ${n(count).padLeft(7)}   پیښې (هره یوه خپل فولډر لري)
  ${n(totalAtt).padLeft(7)}   ضمیمې (ریښتیني انځور، ویډیو، غږ، PDF، CSV، متن)
  ${n(years.length).padLeft(7)}   کلونه (${PashtoDigits.to(years.first.toString())} — ${PashtoDigits.to(years.last.toString())} هجري لمریز)

د یوې پیښې جوړښت
------------------
  1405/سنبله/13/د کابل د راپور پېښه 1/
      metadata.json    ← یوازې د فلټر ډګرونه (~۱KB، یوه کرښه)
      content.json     ← د پاڼې محتوا — بلاکونه او ضمیمې
      index.html       ← ښکلې، خپلواکه پاڼه
      attachments/     ← ریښتیني فایلونه

  _arvitch/fonts/      ← د وزیرمتن فونټ (پروګرام یې پخپله کاروي)

ولې دوه JSON فایله؟
--------------------
د **لټون** پر مهال پروګرام یوازې `metadata.json` لولي — هغه کوچنی دی،
نو د زرګونو پیښو سکن په څو ثانیو کې پای ته رسیږي. `content.json`
یوازې هغه وخت لوستل کیږي چې تاسو پیښه پرانیزئ.

څنګه یې وازمویئ؟
-----------------
  ۱. آرشیف راوباسئ، بېلګه:  D:\\Arvitch-Sample
     (وینډوز کې:  tar -xf Arvitch-Sample-Archive.tar.xz)
  ۲. پروګرام وچلوئ او همدا فولډر د آرشیف په توګه وټاکئ
  ۳. پروګرام به یې سکن کړي (~۲–۳ ثانیې) او بیا لټون وکړئ:

     • «زلزله» یا «کندهار» ولیکئ         → بشپړ متن لټون
     • د درجې، رنګ او کټګورۍ فلټرونه     → د Adobe Bridge په څېر
     • د نېټې سلسله (شمسي/قمري/میلادي)   → درې واړه تقویمونه
     • یوه پیښه ووهئ                     → پریویو او ایډیټر

نوټونه
-------
• ضمیمې قصداً ډېرې کوچنۍ دي (۱–۴ KB) ترڅو ډانلوډ سپک وي.
  ستاسو په ریښتیني آرشیف کې به ویډیوګانې سلګونه MB وي — خو دا
  د لټون پر سرعت **هیڅ اغېز نه لري**، ځکه پروګرام د لټون پر مهال
  یوازې metadata.json لولي، نه مېډیا.

• **هره پیښه خپل `index.html` لري** — ټولې ${n(htmlCount)}. هره یوه
  خپلواکه ده: CSS/JS دننه دي، انټرنیټ ته اړتیا نشته، په هر براوزر
  کې پرانیستل کیږي.

• په ځینو پاراګرافونو کې لینکونه او بریښنالیکونه شته — هغه پخپله
  پېژندل شوي او کلیک‌کېدونکي دي (هم په پاڼه کې، هم د پروګرام
  دننه پریویو کې).

• **ولې tar.xz او نه zip؟** معیاري ZIP د فایلونو نومونه په CP437
  کې ساتي، نو وینډوز پښتو نومونه (سنبله، وږی، …) غلط لولي —
  «بې‌معنا کرکټر». tar خام بایټونه ساتي، نو نومونه سم پاتې کیږي.

• **څنګه یې راوباسئ؟** وینډوز ۱۰/۱۱ کې خپله لار:
      tar -xf Arvitch-Sample-Archive.tar.xz
  یا 7-Zip / WinRAR ورباندې دوه ځله کلیک وکړئ.
''');

    print('EVENTS=$count ATTACHMENTS=$totalAtt BYTES=$totalBytes');
    print('YEARS=${years.join(",")}');
  }, timeout: const Timeout(Duration(minutes: 30)));
}

/// ۳۰۰۰ → «۳,۰۰۰»
String _thousands(int v) {
  final s = '$v';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
