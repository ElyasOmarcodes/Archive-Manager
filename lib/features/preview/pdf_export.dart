import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibEncoder;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import '../../core/app_info.dart';
import '../../core/date/pashto_calendar.dart';
import '../../core/text/pashto_pdf_forms.g.dart';
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
///   ۳. میټاډیټا         (جدول، وروستۍ پاڼه)
/// ```
///
/// ## او د ویډیو/غږ لپاره؟
///
/// PDF ویډیو یا غږ نه چلوي، نو د هغو پرځای یوه **کوچنۍ، پاکه
/// نښه** راځي: یو رسم شوی شکل او د مېډیا پښتو نوم — بس. نه د
/// فایل انګلیسی نوم، نه پسوند، نه توضیحي جمله. کاروونکي وویل چې
/// سند باید «صفا وي او د لوستونکي فکر او سترګې خلل نکړي».
///
/// اصلي فایلونه بایللي نه دي: هغه د PDF **دننه ضمیمه** دي، او د
/// وروستۍ پاڼې جدول یې شمېر او ټول حجم ښیي.
///
/// ## میټاډیټا — درې ځایه
///
/// ۱. **XMP** (`/Metadata`) — د صنعت معیار. Acrobat, Bridge,
///    Windows Explorer او د آرشیف سیسټمونه یې پخپله لولي.
/// ۲. **ضمیمه** (`/EmbeddedFiles`) — اصلي `metadata.json` او
///    `content.json` د فایل دننه، نو پیښه له PDF نه بیا جوړېدلی
///    شي.
/// ۳. **جدول** — د وروستۍ پاڼې پر مخ، نو انسان یې هم ولولي.
/// د یوې مېډیا ډول — یوازې د نښې د رسمولو لپاره.
enum _Mark { video, audio, image, file }

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
      // د کاپي کولو لپاره — وګورئ [_fixToUnicode]
      deflate: _fixToUnicode,
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
        // ډیفالټ ۲۰ دی — یو اوږد راپور یې په اسانه تېروي.
        maxPages: 500,
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 52),
        header: (_) => _letterhead(e),
        footer: (c) => _footer(c, e),
        build: (context) => [
          _titleBlock(e),
          if (e.summary.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('۱', 'لنډیز'),
            // **مستقیم اولاد، نه په `Padding` کې.** `MultiPage`
            // یوازې هغه ویجټ پر پاڼو ویشي چې **سیده** یې اولاد وي
            // او `SpanningWidget` وي. که یې په `Padding` یا
            // `Column` کې وتړو، بیا نه ویشل کیږي — او یو اوږد
            // لنډیز ټول اکسپورټ ماتوي.
            pw.Text(_t(e.summary),
                overflow: pw.TextOverflow.span,
                style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 4)),
          ],
          if (e.blocks.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle(e.summary.isEmpty ? '۱' : '۲', 'د پیښې متن'),
            ..._blocks(e, images),
          ],
          // **د ضمیمو جدول دلته نشته.** کاروونکي وویل: «په خروجي
          // PDF کې د ضمیمې جدول باید نه وي … باید صفا وي او د
          // لوستونکي فکر او سترګې خلل نکړي». د فایلونو شمېر او
          // ټول حجم لا هم د وروستۍ پاڼې په جدول کې دي، او اصلي
          // فایلونه د PDF **دننه** ضمیمه شوي دي.
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
        // ډیفالټ ۲۰ دی — یو اوږد راپور یې په اسانه تېروي.
        maxPages: 500,
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 52),
        header: (_) => _letterhead(e),
        footer: (c) => _footer(c, e),
        // **پر دې پاڼه یوازې جدول.** کاروونکي وویل: «اخیري پاڼه
        // کې فقط د میټاډیټا جدول وي». نو هیڅ توضیح، هیڅ بل جدول —
        // یو سرلیک او یو جدول.
        build: (context) => [
          _sectionTitle(_nextNo(e, 'metadata'), 'میټاډیټا'),
          pw.SizedBox(height: 10),
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
            pw.Text(_t(kAppName),
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
              _t('مخ ${PashtoDigits.to(c.pageNumber)} له '
                  '${PashtoDigits.to(c.pagesCount)}'),
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

  /// **د سند مخ.**
  ///
  /// رسمي سند له یوه پاک سرلیک څخه پیل کیږي: د سند ډول، بیا
  /// عنوان، بیا یوه نرۍ کرښه، او تر هغې لاندې یوه **یوه‑کرښیزه**
  /// پېژندنه (نېټه · کټګوري · درجه). ټول جدولونه وروستۍ پاڼې ته
  /// ولېږدېدل — نو لومړۍ پاڼه د لوستلو ده، نه د ډیټا.
  static pw.Widget _titleBlock(EventMetadata e) {
    final strip = <String>[
      _t(e.date.shamsiText),
      if (e.category.isNotEmpty) _t(e.category),
      '${PashtoDigits.to(e.rating)}/۵',
    ].join('   ·   ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 6),
        pw.Text(_t('د آرشیف سند'),
            style: const pw.TextStyle(fontSize: 9, color: _muted)),
        pw.SizedBox(height: 8),
        pw.Text(
          _t(e.title),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink),
        ),
        pw.SizedBox(height: 9),
        pw.Container(width: 110, height: 1.2, color: _ink),
        pw.SizedBox(height: 9),
        pw.Text(strip,
            style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
        pw.SizedBox(height: 4),
        pw.Divider(color: _rule, height: 0.5),
      ],
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
          // فاصله جلا ویجټ ده — نو متن پخپله سیده اولاد پاتې شي
          // او د پاڼو تر منځ وویشل شي.
          out.add(_linked(b.text));
          out.add(pw.SizedBox(height: 8));

        case BlockKind.quote:
          // **ولې دوه بڼې؟**
          //
          // چوکاټ (`Container`) د پاڼې پر څنډه نه ماتیږي — که
          // نقل قول تر یوې پاڼې اوږد شي، ټول اکسپورټ ناکام کیږي.
          // نو اوږد نقل قول ساده، ماتېدونکې بڼه نیسي: د پیل
          // ژورتیا + «» نښې، چې د پاڼو تر منځ دوام کولی شي.
          if (_t(b.text).length > 700) {
            out.add(pw.SizedBox(height: 6));
            out.add(pw.Text('«${_t(b.text)}»',
                overflow: pw.TextOverflow.span,
                style: const pw.TextStyle(
                    fontSize: 10.5, lineSpacing: 4, color: _muted)));
            if (b.author.isNotEmpty) {
              out.add(pw.SizedBox(height: 4));
              out.add(pw.Text('— ${_t(b.author)}',
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: _muted,
                      fontWeight: pw.FontWeight.bold)));
            }
            out.add(pw.SizedBox(height: 6));
            break;
          }
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
            out.add(_mediaMark(_Mark.image, b.caption));
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
          out.add(_mediaMark(_Mark.video, b.caption));
        case BlockKind.audio:
          out.add(_mediaMark(_Mark.audio, b.caption));
        case BlockKind.file:
          out.add(_mediaMark(_Mark.file, b.caption));
      }
    }
    return out;
  }

  /// **د یوې مېډیا نښه — ساده، پاکه، بې‌انګلیسي.**
  ///
  /// کاروونکي وویل:
  ///
  /// > د ویډیو او غږیزو فایلونو نښه په PDF کې یو څه ښکلې او ساده
  /// > جوړه کړه … اوس د PDF منځ کې د ویډیو په نښه کې انګلیسي
  /// > کلمات او هر څه وي، نو د لوستونکي فکر ته زیات خلل کوي.
  ///
  /// نو نښه اوس یوازې دا لري: یو کوچنی رسم شوی شکل، د مېډیا
  /// **پښتو** نوم، او — که وي — د کاروونکي خپل سرلیک. **نه** د
  /// فایل نوم، **نه** پسوند، **نه** د توضیح جمله.
  ///
  /// د فایل بشپړ نوم او مسیر بایللی نه دی: اصلي فایل د همدې PDF
  /// **دننه ضمیمه** دی، او د ZIP اکسپورټ کې هم راځي.
  static pw.Widget _mediaMark(_Mark m, String caption) {
    final text = markText(m.name, caption);

    return pw.Center(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 9),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: pw.BoxDecoration(
          color: _soft,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: _rule, width: 0.4),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(_t(text),
                style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
            pw.SizedBox(width: 7),
            pw.CustomPaint(
              size: const PdfPoint(11, 11),
              painter: (canvas, size) => _paintMark(canvas, m),
            ),
          ],
        ),
      ),
    );
  }

  /// **هغه متن چې د مېډیا په نښه کې لیکل کیږي** — د ازموینې لپاره
  /// ښکاره دی، نو ثابته شي چې د فایل نوم/پسوند پکې نه راځي.
  @visibleForTesting
  static String markText(String kind, String caption) {
    final label = switch (kind) {
      'video' => 'ویډیو',
      'audio' => 'غږیز فایل',
      'image' => 'انځور',
      _ => 'ضمیمه',
    };
    final c = caption.trim();
    return c.isEmpty ? label : '$label  ·  $c';
  }

  /// **د سند د برخو لیست** — د ازموینې لپاره ښکاره.
  ///
  /// نو ثابته شي چې «ضمیمې» نور یوه برخه نه ده، او شمېرې یې سمې
  /// پاتې دي.
  @visibleForTesting
  static List<String> sections(EventMetadata e) => [
        if (e.summary.isNotEmpty) 'لنډیز',
        if (e.blocks.isNotEmpty) 'د پیښې متن',
        'میټاډیټا',
      ];

  /// د نښې کوچنی شکل — پخپله رسمیږي، نو هیڅ فونټ/ایموجي ته اړتیا
  /// نشته او په هر چاپګر کې یو شان راځي.
  static void _paintMark(PdfGraphics c, _Mark m) {
    c.setColor(_muted);
    switch (m) {
      case _Mark.video:
        // یوه کوچنۍ «چلولو» مثلثه
        c
          ..moveTo(2, 1.5)
          ..lineTo(9.5, 5.5)
          ..lineTo(2, 9.5)
          ..closePath()
          ..fillPath();
      case _Mark.audio:
        // د غږ څپې — څلور نري ستنې
        const hs = [3.0, 6.5, 9.0, 5.0];
        for (var i = 0; i < hs.length; i++) {
          final h = hs[i];
          c.drawRect(1.0 + i * 2.7, (11 - h) / 2, 1.5, h);
        }
        c.fillPath();
      case _Mark.image:
        // د انځور چوکاټ + یو غر
        c
          ..drawRect(0.8, 1.5, 9.4, 8)
          ..strokePath();
        c
          ..moveTo(2.2, 3.2)
          ..lineTo(5, 7)
          ..lineTo(8.8, 3.2)
          ..closePath()
          ..fillPath();
      case _Mark.file:
        // یوه پاڼه چې کونج یې تاوېدلی
        c
          ..moveTo(1.5, 0.8)
          ..lineTo(7, 0.8)
          ..lineTo(9.5, 3.3)
          ..lineTo(9.5, 10.2)
          ..lineTo(1.5, 10.2)
          ..closePath()
          ..strokePath();
        c
          ..moveTo(7, 0.8)
          ..lineTo(7, 3.3)
          ..lineTo(9.5, 3.3)
          ..strokePath();
    }
  }

  @visibleForTesting
  static List<MapEntry<String, String>> metadataRows(EventMetadata e) {
    String cut(String v) =>
        v.length <= 220 ? v : '${v.substring(0, 220)}…';

    return [
      MapEntry('د سند شمېره', e.id),
      MapEntry('سرلیک', cut(e.title)),
      if (e.category.isNotEmpty) MapEntry('کټګوري', e.category),
      MapEntry('نېټه (هجري لمریز)', e.date.shamsiText),
      MapEntry('نېټه (هجري قمري)', e.date.qamariText),
      MapEntry('نېټه (میلادي)', e.date.miladiText),
      MapEntry('د ورځې شمېره (JDN)', '${e.date.jdn}'),
      MapEntry('درجه', '${PashtoDigits.to(e.rating)} له ۵'),
      MapEntry('رنګ ټګ', '${e.colorTag.label} — ${e.colorTag.meaning}'),
      if (e.keywords.isNotEmpty)
        MapEntry('کیوردونه', cut(e.keywords.join('، '))),
      if (e.persons.isNotEmpty)
        MapEntry('شخصیتونه', cut(e.persons.join('، '))),
      MapEntry('ضمیمې',
          '${PashtoDigits.to(e.attachmentCount)} فایله  ·  ${_bytes(e.totalBytes)}'),
      if (e.summary.isNotEmpty) MapEntry('لنډیز', cut(e.summary)),
      MapEntry('د پوښۍ مسیر', e.folderPath),
      MapEntry('ثبت شوې', _stamp(e.createdAt)),
      MapEntry('وروستی بدلون', _stamp(e.updatedAt)),
    ];
  }

  static String _stamp(DateTime d) {
    final t = TriDate.fromDateTime(d);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${t.shamsiText}  ·  ${PashtoDigits.to('$hh:$mm')}';
  }

  /// **د نه‌لیدونکو تورو پاکونکی** — د ازموینې لپاره ښکاره.
  @visibleForTesting
  static String cleanText(String s) => _t(s);

  static pw.Widget _metadataTable(EventMetadata e) => _table(
        header: const ['برخه', 'ارزښت'],
        widths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2.2)},
        rows: [
          for (final r in metadataRows(e)) [r.key, _t(r.value)],
        ],
        ltrCell: (row, col) =>
            col == 1 && metadataRows(e)[row].key == 'د سند شمېره',
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

  /// **پاکونکی + د پور تورو بدلونکی.**
  ///
  /// دوه کاره کوي:
  ///
  /// ۱. نه‌لیدونکي توري (ZWNJ او د بایډي نښې) غورځوي — هغه د
  ///    PDF کتابتون د یوه عادي توري په څېر چلوي، نو کلمه
  ///    ماتوي: «پ‌ښ‌تو» → «پ ښ تو».
  ///
  /// ۲. د پښتو هغه لس توري چې کتابتون یې **نه پېژني** (ټ ځ څ ډ
  ///    ړ ږ ښ ګ ڼ ۍ) خپلو **پوروړو** ته اړوي. ولې؟ ځکه کتابتون
  ///    یوازې هغه توري تړي چې خپل جدول کې یې ولري؛ نور یې
  ///    بې‌تړلې پرېږدي او د هغو ګاونډیان هم ماتوي:
  ///
  ///        چټک → چ ټ ک        کټګوري → ک ټ ګوري
  ///
  ///    پوروړی توری هغه اردو/سندي توری دی چې کتابتون یې پېژني،
  ///    د تړلو ډول یې هماغه دی، او پښتو یې هیڅکله نه کاروي. فونټ
  ///    بیا د پوروړي د بڼو پر ځای د پښتو ګلیفونه رسموي
  ///    (`tool/font/add_pashto_pdf_forms.py`).
  ///
  ///    او د کاپي کولو لپاره؟ د PDF `ToUnicode` جدول بېرته
  ///    سمیږي — وګورئ [_fixToUnicode].
  static String _t(String s) {
    final clean = s.replaceAll(_invisible, '');
    if (clean.isEmpty) return clean;
    return String.fromCharCodes(
        clean.runes.map((r) => kPashtoDonor[r] ?? r));
  }

  /// **د کاپي کولو سموونکی.**
  ///
  /// PDF د هر ګلیف لپاره یو `ToUnicode` جدول لري — هغه چې
  /// کاپي/لټون پرې ولاړ دی. زمونږ د پور تورو له امله هلته اردو
  /// توري لیکل کیږي، نو دلته یې بېرته اصلي پښتو ته اړوو.
  ///
  /// دا د `deflate` له لارې کیږي: کتابتون هر جریان مونږ ته
  /// راکوي چې کمپرس یې کړو — نو مخکې تر کمپرس یې سموو.
  static List<int> _fixToUnicode(List<int> raw) {
    // یوازې د CMap جریانونه — نور بې‌لاسوهنې کمپرس کیږي.
    const marker = 'begincmap';
    if (raw.length > 24 && raw.length < 1 << 20) {
      final text = latin1.decode(raw, allowInvalid: true);
      if (text.contains(marker)) {
        final fixed = text.replaceAllMapped(
          RegExp(r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]{4})>'),
          (m) {
            final to = int.parse(m[2]!, radix: 16);
            final real = kDonorFormToPashto[to];
            if (real == null) return m[0]!;
            return '<${m[1]}> <${real.toRadixString(16).toUpperCase().padLeft(4, '0')}>';
          },
        );
        return const ZLibEncoder().encode(latin1.encode(fixed));
      }
    }
    return const ZLibEncoder().encode(raw);
  }

  /// لینکونه په PDF کې هم کلیک‌کېدونکي کوي.
  static pw.Widget _linked(String raw, {double size = 10.5}) {
    // **لومړی لینکفای، بیا بدلون.** که برعکس یې وکړو، د لینک
    // پېژندونکی به بدل شوي توري ونه پېژني او پته به مات شي.
    final text = raw.replaceAll(_invisible, '');
    final chunks = linkify(text);
    if (!chunks.any((c) => c.isLink)) {
      return pw.Text(_t(text),
          // **`span` اړین دی.** بې له هغه یوه اوږده پاراګراف چې
          // د یوې پاڼې تر لوړوالي ډېره شي، ټول اکسپورټ ماتوي:
          // «Widget won't fit into the page as its height (3269)
          // exceed a page height». اوس پخپله راتلونکې پاڼې ته
          // دوام ورکوي.
          overflow: pw.TextOverflow.span,
          style: pw.TextStyle(fontSize: size, lineSpacing: 4));
    }
    return pw.RichText(
      overflow: pw.TextOverflow.span,
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
              pw.TextSpan(text: _t(c.text)),
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
