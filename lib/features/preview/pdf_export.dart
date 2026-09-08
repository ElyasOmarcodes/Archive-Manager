import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import '../../core/app_info.dart';
import '../../core/date/pashto_calendar.dart';
import '../../core/text/pashto_text.dart';
import '../../data/models/models.dart';

/// **د پیښې رسمي PDF جوړونکی.**
///
/// ## بڼه
///
/// دا یو **رسمي سند** دی، نه یوه رنګینه پاڼه: سپینه ځمکه، تور
/// متن، نرۍ خړې کرښې، او یو تک شین لهجه‌رنګ (`_ink`) یوازې د
/// سرلیکونو او کرښو لپاره. هره برخه شمېره لري (۱، ۲، ۳…)، او
/// معلومات په **چوکاټ لرونکو جدولونو** کې راځي — لکه چې یو
/// رسمي راپور یا محضر ولیکل شي.
///
/// ```
///   د آرشیف چټک مدیر                       سند: kabul-china
///   ─────────────────────────────────────────────────────
///                  د کابل او چین اقتصادي تړون
///   ┌───────────┬─────────────────────────────────────┐
///   │ کټګوري    │ سیاسي                               │
///   │ نېټه      │ ۱۳ سنبله ۱۴۰۵ · ۲۲ ربیع‌الاول ۱۴۴۸ │
///   └───────────┴─────────────────────────────────────┘
///   ۱. لنډیز
///   ۲. متن
///   ۳. ضمیمې            (جدول)
///   ۴. میټاډیټا         (جدول، وروستۍ پاڼه)
/// ```
///
/// ## او د ویډیو/غږ لپاره؟
///
/// PDF ویډیو یا غږ نه چلوي، نو د هغو پرځای یوه **جدولي کرښه**
/// راځي: ډول، نوم، حجم او نسبي مسیر. نو څوک چې PDF لولي پوهیږي
/// چې کوم شواهد شته او چېرې دي.
///
/// ## میټاډیټا — درې ځایه
///
/// ۱. **XMP** (`/Metadata`) — د صنعت معیار. Acrobat, Bridge,
///    Windows Explorer او د آرشیف سیسټمونه یې پخپله لولي.
/// ۲. **ضمیمه** (`/EmbeddedFiles`) — اصلي `metadata.json` او
///    `content.json` د فایل دننه، نو پیښه له PDF نه بیا جوړېدلی
///    شي.
/// ۳. **جدول** — د وروستۍ پاڼې پر مخ، نو انسان یې هم ولولي.
class EventPdf {
  EventPdf._();

  // ── د سند رنګونه: رسمي، نه رنګین ──
  static const _ink = PdfColor.fromInt(0xFF1A2B4A); // تک شین — سرلیکونه
  static const _rule = PdfColor.fromInt(0xFF9AA4B2); // د جدول کرښې
  static const _soft = PdfColor.fromInt(0xFFF2F4F7); // د جدول د سر ډکون
  static const _muted = PdfColor.fromInt(0xFF56616F); // دوهم درجه متن

  /// د پښتو فونټونه — یو ځل لوستل کیږي، بیا بیا نه.
  static pw.Font? _regular, _bold;

  static Future<void> _loadFonts() async {
    if (_regular != null) return;
    _regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    _bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
  }

  /// د پیښې PDF جوړوي او د بایټونو په بڼه یې راګرځوي.
  ///
  /// [images] هغه انځورونه دي چې له ډیسکه لوستل شوي — کیلي یې د
  /// ضمیمې نسبي مسیر دی. که یو انځور ونه موندل شي، پرځای یې یوه
  /// جدولي کرښه راځي (نه یوه ماته پاڼه).
  ///
  /// [compress] یوازې ازموینې ورسره لوبې کوي: که غلط وي، د پاڼې
  /// د رسم کرښې (content stream) لوستل کېدونکې پاتې کیږي، نو
  /// ازموینه کولی شي وګوري چې هیڅ رسم د پاڼې له پولې بهر نه ځي.
  static Future<Uint8List> build(
    EventMetadata e, {
    Map<String, Uint8List> images = const {},
    bool compress = true,
  }) async {
    await _loadFonts();

    final theme = pw.ThemeData.withFont(base: _regular!, bold: _bold!);
    final doc = pw.Document(
      compress: compress,
      title: _t(e.title),
      author: e.persons.isEmpty ? kAppName : e.persons.map(_t).join('، '),
      subject: e.category.isEmpty ? 'د آرشیف پیښه' : _t(e.category),
      keywords: e.keywords.map(_t).join('، '),
      creator: '$kAppName · Arvitch v$kAppVersion',
      producer: 'Arvitch',
      // ── ۱) XMP: میټاډیټا د فایل دننه، د معیار له مخې ──
      metadata: _xmp(e),
      theme: theme,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 52),
        header: (_) => _letterhead(e),
        footer: (c) => _footer(c, e),
        build: (context) => [
          _titleBlock(e),
          pw.SizedBox(height: 14),
          _identityTable(e),
          if (e.summary.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _sectionTitle('۱', 'لنډیز'),
            pw.Paragraph(
              text: _t(e.summary),
              style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 4),
              margin: const pw.EdgeInsets.only(bottom: 2),
            ),
          ],
          if (e.blocks.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle(e.summary.isEmpty ? '۱' : '۲', 'د پیښې متن'),
            ..._blocks(e, images),
          ],
          if (e.attachments.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _sectionTitle(_nextNo(e, 'attachments'), 'ضمیمې'),
            _attachments(e),
          ],
        ],
      ),
    );

    // ── ۳) میټاډیټا جدول — یوازې پر خپله، وروستۍ پاڼه ──
    //
    // ولې جلا پاڼه؟ ځکه دا د سند «رسمي ضمیمه» ده: یو څوک چې غواړي
    // د پیښې اصلي ثبت وګوري، هغه پاڼه چاپوي — نه ټول سند.
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 52),
        header: (_) => _letterhead(e),
        footer: (c) => _footer(c, e),
        build: (context) => [
          _sectionTitle(_nextNo(e, 'metadata'), 'میټاډیټا (metadata.json)'),
          pw.Paragraph(
            text: 'لاندې جدول د پیښې ټول ثبت شوي ډګرونه ښیي. اصلي '
                'فایل د همدې PDF دننه دوه ځایه ضمیمه دی: د XMP په '
                'بڼه، او د PDF د ضمیمو (Embedded Files) په بڼه — نو '
                'له همدې یوې دوسیې نه پیښه بیا جوړېدلی شي.',
            style: const pw.TextStyle(
                fontSize: 9.5, lineSpacing: 3.5, color: _muted),
          ),
          pw.SizedBox(height: 6),
          _metadataTable(e),
        ],
      ),
    );

    // ── ۲) اصلي فایلونه د PDF ریښتینې ضمیمې ──
    PdfaAttachedFiles(doc.document, [
      PdfaAttachedFile(
        name: 'metadata.json',
        data: const JsonEncoder.withIndent('  ').convert(e.toJson()),
        subType: '/application/json',
        afRelationship: '/Source',
      ),
      if (e.blocks.isNotEmpty || e.attachments.isNotEmpty)
        PdfaAttachedFile(
          name: 'content.json',
          data: const JsonEncoder.withIndent('  ').convert(e.toContentJson()),
          subType: '/application/json',
          afRelationship: '/Supplement',
        ),
    ]);

    return doc.save();
  }

  // ═════════════════════════════════════════════════════════
  //  XMP
  // ═════════════════════════════════════════════════════════

  /// **د XMP بسته.**
  ///
  /// معیاري ډګرونه (`dc:*`, `xmp:*`, `pdf:*`) هغه دي چې هر
  /// لوستونکی یې پېژني. سربېره پر هغو، یو خپل نوم‌ځای
  /// (`arvitch:`) هم ورزیاتوو چې **بشپړ `metadata.json`** پکې
  /// پروت وي — نو هیڅ ډګر نه ورکیږي، آن هغه چې XMP یې معیاري
  /// معادل نه لري (لکه `jdn` یا د رنګ ټګ).
  static XmlDocument _xmp(EventMetadata e) {
    final json = const JsonEncoder.withIndent('  ').convert(e.toJson());
    final b = XmlBuilder();
    b.processing('xpacket', 'begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"');
    b.element('x:xmpmeta', nest: () {
      b.attribute('xmlns:x', 'adobe:ns:meta/');
      b.attribute('x:xmptk', 'Arvitch $kAppVersion');
      b.element('rdf:RDF', nest: () {
        b.attribute(
            'xmlns:rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#');
        b.element('rdf:Description', nest: () {
          b.attribute('rdf:about', '');
          b.attribute('xmlns:dc', 'http://purl.org/dc/elements/1.1/');
          b.attribute('xmlns:xmp', 'http://ns.adobe.com/xap/1.0/');
          b.attribute('xmlns:pdf', 'http://ns.adobe.com/pdf/1.3/');
          b.attribute('xmlns:arvitch', 'https://arvitch.local/ns/1.0/');

          _xmpAlt(b, 'dc:title', _t(e.title));
          if (e.summary.isNotEmpty) {
            _xmpAlt(b, 'dc:description', _t(e.summary));
          }
          if (e.persons.isNotEmpty) {
            _xmpSeq(b, 'dc:creator', e.persons.map(_t).toList());
          }
          if (e.keywords.isNotEmpty) {
            _xmpBag(b, 'dc:subject', e.keywords.map(_t).toList());
          }
          if (e.category.isNotEmpty) {
            _xmpBag(b, 'dc:type', [_t(e.category)]);
          }
          b.element('dc:format', nest: 'application/pdf');
          b.element('dc:language', nest: 'ps');

          b.element('xmp:CreatorTool', nest: 'Arvitch $kAppVersion');
          b.element('xmp:CreateDate',
              nest: e.createdAt.toUtc().toIso8601String());
          b.element('xmp:ModifyDate',
              nest: e.updatedAt.toUtc().toIso8601String());
          b.element('xmp:MetadataDate',
              nest: DateTime.now().toUtc().toIso8601String());
          b.element('pdf:Producer', nest: 'Arvitch');

          // ── د آرشیف خپل ډګرونه ──
          b.element('arvitch:id', nest: e.id);
          b.element('arvitch:jdn', nest: '${e.date.jdn}');
          b.element('arvitch:shamsi', nest: _t(e.date.shamsiText));
          b.element('arvitch:qamari', nest: _t(e.date.qamariText));
          b.element('arvitch:miladi', nest: _t(e.date.miladiText));
          b.element('arvitch:rating', nest: '${e.rating}');
          b.element('arvitch:colorTag', nest: e.colorTag.name);
          b.element('arvitch:files', nest: '${e.attachmentCount}');
          b.element('arvitch:bytes', nest: '${e.totalBytes}');
          // بشپړ ثبت — نو هیڅ ډګر نه ورکیږي
          b.element('arvitch:metadataJson', nest: json);
        });
      });
    });
    b.processing('xpacket', 'end="w"');
    return b.buildDocument();
  }

  static void _xmpAlt(XmlBuilder b, String tag, String value) {
    b.element(tag, nest: () {
      b.element('rdf:Alt', nest: () {
        b.element('rdf:li', nest: () {
          b.attribute('xml:lang', 'x-default');
          b.text(value);
        });
      });
    });
  }

  static void _xmpSeq(XmlBuilder b, String tag, List<String> values) =>
      _xmpList(b, tag, 'rdf:Seq', values);

  static void _xmpBag(XmlBuilder b, String tag, List<String> values) =>
      _xmpList(b, tag, 'rdf:Bag', values);

  static void _xmpList(
      XmlBuilder b, String tag, String kind, List<String> values) {
    b.element(tag, nest: () {
      b.element(kind, nest: () {
        for (final v in values) {
          b.element('rdf:li', nest: v);
        }
      });
    });
  }

  // ═════════════════════════════════════════════════════════
  //  د پاڼې برخې
  // ═════════════════════════════════════════════════════════

  /// د رسمي سند سرلیک‌کرښه — پر هره پاڼه.
  static pw.Widget _letterhead(EventMetadata e) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.only(bottom: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
              bottom: pw.BorderSide(color: _ink, width: 0.9)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(kAppName,
                style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink)),
            pw.Expanded(child: pw.SizedBox()),
            pw.Text('سند: ${_t(_docRef(e))}',
                style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
      );

  static pw.Widget _footer(pw.Context c, EventMetadata e) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        padding: const pw.EdgeInsets.only(top: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(color: _rule, width: 0.5)),
        ),
        child: pw.Row(
          children: [
            pw.Text(_t(e.title),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: const pw.TextStyle(fontSize: 8, color: _muted)),
            pw.Expanded(child: pw.SizedBox()),
            pw.Text(
              'مخ ${PashtoDigits.to(c.pageNumber)} له '
              '${PashtoDigits.to(c.pagesCount)}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
      );

  /// د سند شمېره — د پوښۍ نوم، یا که هغه نه وي، د پیښې `id`.
  static String _docRef(EventMetadata e) {
    final parts = e.folderPath
        .split(RegExp(r'[\\/]'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? e.id : parts.last;
  }

  static pw.Widget _titleBlock(EventMetadata e) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('د آرشیف سند',
              style: const pw.TextStyle(
                  fontSize: 8.5, letterSpacing: 1.4, color: _muted)),
          pw.SizedBox(height: 5),
          pw.Text(
            _t(e.title),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 17, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
          pw.SizedBox(height: 7),
          // نرۍ منځنۍ کرښه — د رسمي سند نښه
          pw.Container(width: 90, height: 1.4, color: _ink),
        ],
      );

  /// **د پېژندنې جدول** — هغه څه چې فلټر پرې کار کوي.
  static pw.Widget _identityTable(EventMetadata e) {
    final rows = <(String, String)>[
      if (e.category.isNotEmpty) ('کټګوري', _t(e.category)),
      ('نېټه (هجري لمریز)', _t(e.date.shamsiText)),
      ('نېټه (هجري قمري)', _t(e.date.qamariText)),
      ('نېټه (میلادي)', _t(e.date.miladiText)),
      ('درجه', '${PashtoDigits.to(e.rating)} له ۵'),
      ('رنګ ټګ', '${e.colorTag.label} — ${e.colorTag.meaning}'),
      if (e.keywords.isNotEmpty)
        ('کیوردونه', e.keywords.map(_t).join('، ')),
      if (e.persons.isNotEmpty) ('شخصیتونه', e.persons.map(_t).join('، ')),
      ('ضمیمې', '${PashtoDigits.to(e.attachmentCount)} فایله  ·  '
          '${_bytes(e.totalBytes)}'),
      ('د پوښۍ مسیر', e.folderPath),
    ];

    return _table(
      header: const ['ډګر', 'ارزښت'],
      widths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2.6)},
      rows: [
        for (final r in rows) [r.$1, r.$2],
      ],
      // **مسیر ولې RTL؟** ځکه پکې د پښتو پوښۍ نومونه دي
      // (`…\سنبله\د کابل تړون`). که چپ‌څخه‌ښي یې ښیو، پښتو برخه
      // یې چپه رسمیږي — او هغه هغه څه دي چې کاروونکی یې لولي.
      ltrCell: (row, col) => false,
    );
  }

  static pw.Widget _sectionTitle(String no, String text) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8, top: 2),
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: const pw.BoxDecoration(
          border:
              pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.5)),
        ),
        child: pw.Text(_t('$no.  $text'),
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink)),
      );

  /// د برخو شمېرې پخپله حسابوي — نو که لنډیز یا متن نه وي، شمېرې
  /// نه ماتیږي («۱، ۳، ۴» نه راځي).
  static String _nextNo(EventMetadata e, String which) {
    var n = 0;
    if (e.summary.isNotEmpty) n++;
    if (e.blocks.isNotEmpty) n++;
    if (which == 'attachments') return PashtoDigits.to(n + 1);
    if (e.attachments.isNotEmpty) n++;
    return PashtoDigits.to(n + 1);
  }

  // ── د پاڼې بلاکونه ──

  static List<pw.Widget> _blocks(
      EventMetadata e, Map<String, Uint8List> images) {
    final out = <pw.Widget>[];
    for (final b in e.blocks) {
      switch (b.kind) {
        case BlockKind.heading:
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
            child: pw.Text(_t(b.text),
                style: pw.TextStyle(
                    fontSize: b.level <= 1 ? 13 : 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink)),
          ));

        case BlockKind.paragraph:
          if (b.text.trim().isEmpty) break;
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: _linked(b.text),
          ));

        case BlockKind.quote:
          // **پام: د یوې خوا کرښه + `borderRadius` سره نه ځایږي**
          // (د pdf کتابتون یې نه مني)، او `CrossAxisAlignment
          // .stretch` په `MultiPage` کې «Infinity height» ورکوي.
          // نو کرښه له `Border` څخه راځي — هغه پخپله د اولاد په
          // اندازه وي.
          out.add(pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 7),
            padding: const pw.EdgeInsets.fromLTRB(14, 9, 14, 9),
            decoration: const pw.BoxDecoration(
              color: _soft,
              // RTL: کرښه ښي لور ته
              border: pw.Border(
                right: pw.BorderSide(color: _ink, width: 2.2),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _linked(b.text, size: 10.5),
                if (b.author.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('— ${_t(b.author)}',
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: _muted,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ],
            ),
          ));

        case BlockKind.divider:
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 9),
            child: pw.Divider(color: _rule, height: 0.5),
          ));

        case BlockKind.image:
          final bytes = images[b.source];
          if (bytes == null) {
            out.add(_missingRow('انځور', b.source, _t(b.caption)));
            break;
          }
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _rule, width: 0.5),
                  ),
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Image(pw.MemoryImage(bytes),
                      fit: pw.BoxFit.contain, height: 250),
                ),
                if (b.caption.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(_t(b.caption),
                      style: const pw.TextStyle(fontSize: 9, color: _muted)),
                ],
              ],
            ),
          ));

        // ── ویډیو، غږ، نور فایلونه ──
        case BlockKind.video:
          out.add(_missingRow('ویډیو', b.source, _t(b.caption)));
        case BlockKind.audio:
          out.add(_missingRow('غږ', b.source, _t(b.caption)));
        case BlockKind.file:
          out.add(_missingRow('فایلونه', b.source, _t(b.caption)));
      }
    }
    return out;
  }

  /// هغه شواهد چې په PDF کې نه چلیږي — یوه رسمي جدولي کرښه.
  static pw.Widget _missingRow(String kind, String source, String caption) =>
      pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _rule, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              color: _soft,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: pw.Text(
                caption.isEmpty ? kind : '$kind — $caption',
                style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink),
              ),
            ),
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(source,
                      textDirection: pw.TextDirection.ltr,
                      style:
                          const pw.TextStyle(fontSize: 9, color: _muted)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'دا ډول فایل په PDF کې نه چلیږي — اصلي فایل د '
                    'پیښې په پوښۍ کې وګورئ.',
                    style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  static pw.Widget _attachments(EventMetadata e) => _table(
        header: const ['#', 'نوم', 'ډول', 'اندازه', 'نسبي مسیر'],
        widths: const {
          0: pw.FixedColumnWidth(26),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1),
          4: pw.FlexColumnWidth(3),
        },
        rows: [
          for (var i = 0; i < e.attachments.length; i++)
            [
              PashtoDigits.to(i + 1),
              e.attachments[i].name,
              e.attachments[i].kind.label,
              _bytes(e.attachments[i].sizeBytes),
              e.attachments[i].relativePath,
            ],
        ],
        ltrCell: (row, col) => col == 1 || col == 4,
      );

  /// د میټاډیټا کرښې — د جدول سرچینه.
  ///
  /// ازموینه یې مستقیم ګوري: د رسم شوي PDF متن راایستل د فونټ د
  /// ToUnicode جدول له لارې کیږي، چې ډېر نازک دی. دلته اصلي ډیټا
  /// ازمویو — هغه چې جدول یې ښیي.
  @visibleForTesting
  static List<MapEntry<String, String>> metadataRows(EventMetadata e) {
    final j = e.toJson();
    j.remove('text'); // اوږد متن پخپله پورته دی
    return [for (final x in j.entries) MapEntry(x.key, '${x.value}')];
  }

  /// **د نه‌لیدونکو تورو پاکونکی** — د ازموینې لپاره ښکاره.
  @visibleForTesting
  static String cleanText(String s) => _t(s);

  static pw.Widget _metadataTable(EventMetadata e) => _table(
        header: const ['ډګر', 'ارزښت'],
        widths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2.6)},
        rows: [
          // **پام:** ارزښتونه دلته هم پاکیږي. جدول د **لوستلو**
          // لپاره دی — که ZWNJ پکې پاتې شي، «پ‌ښ‌تو» ټوټې ښکاري.
          // اصلي، بې‌لاسوهنې بڼه یې په XMP او ضمیمه کې ده.
          for (final r in metadataRows(e)) [r.key, _t(r.value)],
        ],
        // کیلي ټولې لاتیني دي
        ltrCell: (row, col) => col == 0,
      );

  // ═════════════════════════════════════════════════════════
  //  مرستندویې
  // ═════════════════════════════════════════════════════════

  /// **یو رسمي جدول** — چوکاټ لرونکی، له سر‑کرښې سره.
  ///
  /// د `pw.Table.fromTextArray` پرځای خپل جوړوو، ځکه هغه د هرې
  /// حجرې لور (RTL/LTR) نه پرېږدي — او مونږ ته پکار ده: پښتو
  /// ښي‌څخه‌کیڼ، مسیرونه او کیلي کیڼ‌څخه‌ښي.
  static pw.Widget _table({
    required List<String> header,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? widths,
    bool Function(int row, int col)? ltrCell,
  }) {
    pw.Widget cell(String text,
            {required bool head, required bool ltr}) =>
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          alignment: ltr
              ? pw.Alignment.centerLeft
              : pw.Alignment.centerRight,
          // **هره حجره دلته پاکیږي** — نه د هر ویلونکي پر غاړه.
          // یو ځای دفاع تر لسو ځایو هېرېدو غوره ده.
          child: pw.Text(
            _t(text),
            textDirection:
                ltr ? pw.TextDirection.ltr : pw.TextDirection.rtl,
            style: pw.TextStyle(
              fontSize: head ? 9 : 9.5,
              fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: head ? _ink : PdfColors.black,
              lineSpacing: 2,
            ),
          ),
        );

    // **`pw.Table` په RTL کې کالمې نه اړوي.**
    //
    // د متن لور یې سم دی، خو کالمې تل له چپه ښي ته ږدي — نو
    // «ډګر | ارزښت» چپ ته ولوېد، او پښتو لوستونکی لومړی ارزښت
    // ویني. نو مونږ یې پخپله اړوو: کالمې برعکس، او پلنوالی هم
    // ورسره. ویلونکی خپله منطقي بڼه ساتي (لومړی ډګر، بیا ارزښت).
    final n = header.length;
    pw.Table rtl(List<List<pw.Widget>> body) => pw.Table(
          border: pw.TableBorder.all(color: _rule, width: 0.5),
          columnWidths: widths == null
              ? null
              : {
                  for (final k in widths.keys) n - 1 - k: widths[k]!,
                },
          children: [
            for (var i = 0; i < body.length; i++)
              pw.TableRow(
                decoration: i == 0
                    ? const pw.BoxDecoration(color: _soft)
                    : null,
                children: body[i].reversed.toList(),
              ),
          ],
        );

    return rtl([
      [for (final h in header) cell(h, head: true, ltr: false)],
      for (var r = 0; r < rows.length; r++)
        [
          for (var c = 0; c < rows[r].length; c++)
            cell(rows[r][c], head: false, ltr: ltrCell?.call(r, c) ?? false),
        ],
    ]);
  }

  /// **د نه‌لیدونکو تورو پاکونکی.**
  ///
  /// د پروګرام متن کې ZWNJ (`U+200C`) او د بایډي نښې (`U+200E`،
  /// `U+202B` …) عادي دي — فلټر یې سم پوهیږي او هیڅ نه ښیي. د
  /// `pdf` کتابتون شکل‌ورکوونکی یې نه پېژني: د یوه عادي توري په
  /// څېر یې چلوي، نو ټکي یې سره بېلوي — «پ‌ښ‌تو» → «پ ښ تو».
  ///
  /// **نو غورځوو یې، نه چې تشه ورکړو.** (پخوا مې تشه ورکوله، نو
  /// هره کلمه چې ZWNJ پکې و، ماتېده: «پ ښ تو».) د میاشتو نوم
  /// «ربیع + ZWNJ + الاول» → «ربیعالاول» — دا سم لوستل کیږي.
  static final _invisible = RegExp(
      '[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');

  static String _t(String s) => s.replaceAll(_invisible, '');

  /// لینکونه په PDF کې هم کلیک‌کېدونکي کوي.
  static pw.Widget _linked(String raw, {double size = 10.5}) {
    final text = _t(raw);
    final chunks = linkify(text);
    if (!chunks.any((c) => c.isLink)) {
      return pw.Text(text,
          style: pw.TextStyle(fontSize: size, lineSpacing: 4));
    }
    return pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(fontSize: size, lineSpacing: 4),
        children: [
          for (final c in chunks)
            if (c.isLink && isSafeUrl(c.url!))
              pw.TextSpan(
                text: c.text,
                style: const pw.TextStyle(
                    color: _ink, decoration: pw.TextDecoration.underline),
                annotation: pw.AnnotationUrl(c.url!),
              )
            else
              pw.TextSpan(text: c.text),
        ],
      ),
    );
  }

  static String _bytes(int b) {
    if (b <= 0) return '۰';
    const units = ['B', 'KB', 'MB', 'GB'];
    var v = b.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${PashtoDigits.to(v.toStringAsFixed(v < 10 && i > 0 ? 1 : 0))}'
        ' ${units[i]}';
  }
}
