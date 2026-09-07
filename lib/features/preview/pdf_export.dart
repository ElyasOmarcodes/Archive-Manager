import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/date/pashto_calendar.dart';
import '../../core/text/pashto_text.dart';
import '../../data/models/models.dart';

/// **د پیښې PDF جوړونکی.**
///
/// ## څه پکې راځي؟
///
/// * سرلیک، کټګوري، درجه، رنګ ټګ، درې‌ګونې نېټه
/// * کیورډونه او شخصیتونه
/// * د پاڼې ټول بلاکونه: عنوانونه، پاراګرافونه، نقل قولونه،
///   انځورونه
/// * د ضمیمو بشپړ لیست
///
/// ## او د ویډیو/غږ لپاره؟
///
/// PDF ویډیو یا غږ نه چلوي — نو د هغو لپاره یوازې یو **کارت**
/// رسمیږي: ایکن، نوم، ډول، حجم، او د فایل نسبي مسیر. نو څوک چې
/// PDF لولي، پوهیږي چې کوم شواهد شته او چېرې دي، که څه هم هلته
/// یې نشي چلولی.
///
/// ## میټاډیټا د فایل دننه
///
/// د PDF خپل میټاډیټا ډګرونه (سرلیک، لیکوال، موضوع، کیورډونه)
/// ډکیږي، او سربېره پر دې **بشپړ `metadata.json`** د پاڼې په
/// پای کې د یوې ضمیمې په توګه راځي. نو دوسیه خپلواکه ده: که
/// څوک یوازې PDF ولري، ټول معلومات ورسره دي.
class EventPdf {
  EventPdf._();

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
  /// ضمیمې نسبي مسیر دی. که یو انځور ونه موندل شي، پرځای یې یو
  /// کارت راځي (نه یوه ماته پاڼه).
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
      title: e.title,
      author: e.persons.isEmpty ? 'د آرشیف چټک مدیر' : e.persons.join('، '),
      subject: e.category.isEmpty ? 'د آرشیف پیښه' : e.category,
      keywords: e.keywords.join('، '),
      creator: 'Arvitch — د آرشیف چټک مدیر',
      theme: theme,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 48),
        header: (_) => _header(e),
        footer: (c) => _footer(c, e),
        build: (context) => [
          _titleBlock(e),
          pw.SizedBox(height: 14),
          _metaTable(e),
          if (e.keywords.isNotEmpty || e.persons.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _tags(e),
          ],
          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.grey300, height: 1),
          pw.SizedBox(height: 18),
          ..._blocks(e, images),
          if (e.attachments.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _attachments(e),
          ],
          pw.SizedBox(height: 22),
          _rawMetadata(e),
        ],
      ),
    );

    // ── میټاډیټا **د فایل دننه** ──
    //
    // یوازې رسمول کافي نه دي: دلته اصلي `metadata.json` (او که
    // بلاکونه شته، `content.json`) د PDF **ریښتینې ضمیمې** په
    // توګه دننه ایښودل کیږي. نو څوک چې PDF په Acrobat یا هر
    // معیاري لوستونکي کې پرانیزي، په «Attachments» کې اصلي
    // فایلونه لري او بېرته یې راایستلی شي — پیښه له PDF نه
    // بیا جوړېدلی شي.
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

  // ── برخې ───────────────────────────────────────────────

  static pw.Widget _header(EventMetadata e) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.6)),
        ),
        child: pw.Text('د آرشیف چټک مدیر',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
      );

  static pw.Widget _footer(pw.Context c, EventMetadata e) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          '${_t(e.title)}  —  ${PashtoDigits.to(c.pageNumber)} / '
          '${PashtoDigits.to(c.pagesCount)}',
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
        ),
      );

  static pw.Widget _titleBlock(EventMetadata e) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (e.category.isNotEmpty)
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                // **پام: دلته ۹۹۹ مه لیکه.**
                //
                // فلټر لوی ریډیس پخپله راکموي، خو د `pdf` کتابتون
                // یې نه کموي: د ګردې څنډې منحني د بکس له پولې ډېر
                // بهر ځي او **د پاڼې نیمه برخه په رنګ پوښي** —
                // سرلیک، نېټې او ټګونه ټول ورسره پټیږي.
                // نو ریډیس باید تر نیم لوړوالي ډېر نه وي.
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(_t(e.category),
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.indigo700,
                      fontWeight: pw.FontWeight.bold)),
            ),
          pw.SizedBox(height: 8),
          pw.Text(_t(e.title),
              style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold)),
          if (e.summary.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(_t(e.summary),
                style: const pw.TextStyle(
                    fontSize: 10.5, color: PdfColors.grey700, lineSpacing: 3)),
          ],
        ],
      );

  /// درې‌ګونې نېټه + درجه + رنګ.
  static pw.Widget _metaTable(EventMetadata e) {
    pw.Widget cell(String label, String value) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(_t(label),
                    style: const pw.TextStyle(
                        fontSize: 7.5, color: PdfColors.grey600)),
                pw.SizedBox(height: 2),
                pw.Text(_t(value),
                    style: pw.TextStyle(
                        fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        );

    return pw.Row(children: [
      cell('هجري لمریز', e.date.shamsiText),
      pw.SizedBox(width: 6),
      cell('هجري قمري', e.date.qamariText),
      pw.SizedBox(width: 6),
      cell('میلادي', e.date.miladiText),
      pw.SizedBox(width: 6),
      cell('درجه',
          e.rating == 0 ? 'بې درجې' : '${PashtoDigits.to(e.rating)} / ۵'),
    ]);
  }

  static pw.Widget _tags(EventMetadata e) => pw.Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final k in e.keywords)
            _chip('#$k', PdfColors.blue50, PdfColors.blue800),
          for (final p in e.persons)
            _chip(p, PdfColors.green50, PdfColors.green800),
        ],
      );

  static pw.Widget _chip(String text, PdfColor bg, PdfColor fg) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: pw.BoxDecoration(
          color: bg,
          // د پورته په څېر — تر نیم لوړوالي ډېر ریډیس نه.
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(_t(text), style: pw.TextStyle(fontSize: 8.5, color: fg)),
      );

  /// د پاڼې بلاکونه.
  static List<pw.Widget> _blocks(
      EventMetadata e, Map<String, Uint8List> images) {
    final out = <pw.Widget>[];
    for (final b in e.blocks) {
      switch (b.kind) {
        case BlockKind.heading:
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
            child: pw.Text(_t(b.text),
                style: pw.TextStyle(
                    fontSize: b.level <= 1 ? 16 : (b.level == 2 ? 13.5 : 12),
                    fontWeight: pw.FontWeight.bold)),
          ));

        case BlockKind.paragraph:
          if (b.text.trim().isEmpty) break;
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 9),
            child: _linked(b.text),
          ));

        case BlockKind.quote:
          // **دوه شیان دلته پام غواړي:**
          //
          // ۱) د یوې خوا کرښه + `borderRadius` سره نه ځایږي — د pdf
          //    کتابتون یې نه مني («A borderRadius can only be given
          //    for a uniform Border»). نو رنګه کرښه پر یوه دننني
          //    چوکاټ ده چې radius نه لري، او ګرد کونجونه د بهرني
          //    چوکاټ دي.
          //
          // ۲) `CrossAxisAlignment.stretch` په Row کې دلته نه کاریږي:
          //    په `MultiPage` کې لوړوالی نامحدود دی، نو stretch د
          //    «Infinity height» تېروتنه راوړي. د کرښې بشپړ لوړوالی
          //    له `Border` څخه راځي — هغه پخپله د اولاد په اندازه وي.
          out.add(pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                // RTL: کرښه ښي لور ته
                border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.indigo, width: 3),
                ),
              ),
              padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _linked(b.text, size: 11),
                  if (b.author.isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    pw.Text('— ${_t(b.author)}',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ],
              ),
            ),
          ));

        case BlockKind.divider:
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Divider(color: PdfColors.grey300, height: 1),
          ));

        case BlockKind.image:
          final bytes = images[b.source];
          if (bytes != null) {
            out.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Column(children: [
                pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(pw.MemoryImage(bytes),
                      fit: pw.BoxFit.contain, height: 260),
                ),
                if (b.caption.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(_t(b.caption),
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.grey600)),
                ],
              ]),
            ));
          } else {
            out.add(_mediaCard(b.source, b.caption, 'انځور'));
          }

        // ── ویډیو، غږ، نور فایلونه ──
        //
        // PDF دا نه چلوي، نو یوازې کارت رسموو: څه شته او چېرې دي.
        case BlockKind.video:
          out.add(_mediaCard(b.source, b.caption, 'ویډیو'));
        case BlockKind.audio:
          out.add(_mediaCard(b.source, b.caption, 'غږ'));
        case BlockKind.file:
          out.add(_mediaCard(b.source, b.caption, 'فایل'));
      }
    }
    return out;
  }

  /// د هغو فایلونو کارت چې په PDF کې نه چلیږي.
  static pw.Widget _mediaCard(String source, String caption, String kind) =>
      pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 6),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
        ),
        child: pw.Row(children: [
          pw.Container(
            width: 30,
            height: 30,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(kind.substring(0, 1),
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo700)),
          ),
          pw.SizedBox(width: 9),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_t(caption.isEmpty ? kind : caption),
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                if (source.isNotEmpty)
                  pw.Text(source,
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                pw.Text('$kind — په PDF کې نه چلیږي، اصلي فایل وګورئ',
                    style: const pw.TextStyle(
                        fontSize: 7.5, color: PdfColors.grey500)),
              ],
            ),
          ),
        ]),
      );

  static pw.Widget _attachments(EventMetadata e) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ضمیمې (${PashtoDigits.to(e.attachments.length)})',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 7),
          pw.TableHelper.fromTextArray(
            headers: const ['نوم', 'ډول', 'اندازه', 'مسیر'],
            data: [
              for (final a in e.attachments)
                [a.name, a.kind.label, _bytes(a.sizeBytes), a.relativePath],
            ],
            headerStyle: pw.TextStyle(
                fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerRight,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
        ],
      );

  /// خام میټاډیټا — نو دوسیه خپلواکه وي.
  ///
  /// **ولې جدول، نه یو اوږد متن؟** که `key: پښتو ارزښت` په یوه
  /// کرښه کې یوځای ولیکو، د `pdf` کتابتون بایډي پښتو برخه
  /// **چپه** رسموي («تړون» → «نوړت»). نو هر ارزښت خپله ساحه
  /// لري: کیلي کیڼ‌څخه‌ښي، ارزښت ښي‌څخه‌کیڼ — دواړه سم لوستل
  /// کیږي.
  static pw.Widget _rawMetadata(EventMetadata e) {
    final rows = _jsonRows(e);
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('میټاډیټا (metadata.json)',
              style:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('بشپړ فایل د دې PDF دننه ضمیمه دی',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.SizedBox(height: 5),
          for (final r in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 62,
                    child: pw.Text('${r.key}:',
                        textDirection: pw.TextDirection.ltr,
                        style: pw.TextStyle(
                            fontSize: 7,
                            color: PdfColors.grey600,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(_t(r.value),
                        style: const pw.TextStyle(
                            fontSize: 7, color: PdfColors.grey800)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── مرستندویې ──────────────────────────────────────────

  /// **د نه‌لیدونکو تورو پاکونکی.**
  ///
  /// د پروګرام متن کې ZWNJ (`\u200C`) او د بایډي نښې (`\u200E`،
  /// `\u202B` …) عادي دي — فلټر یې سم پوهیږي. د `pdf` کتابتون
  /// شکل‌ورکوونکی یې نه پېژني: د یوه عادي توري په څېر یې په
  /// فونټ کې لټوي او پایله یې یو بې‌ربطه ټکی وي (لکه
  /// «ربیع‌الاول» → «ربیعخالاول»).
  ///
  /// نو ZWNJ ته ساده تشه ورکوو (لوستل یې همداسې سم دي) او پاتې
  /// کنټرول توري بیخي غورځوو.
  static final _invisible =
      RegExp(r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');

  static String _t(String s) => s.replaceAllMapped(
      _invisible, (m) => m[0] == '\u200C' ? ' ' : '');

  /// لینکونه په PDF کې هم کلیک‌کېدونکي کوي.
  static pw.Widget _linked(String raw, {double size = 10.5}) {
    final text = _t(raw);
    final chunks = linkify(text);
    if (!chunks.any((c) => c.isLink)) {
      return pw.Text(text,
          style: pw.TextStyle(fontSize: size, lineSpacing: 3.5));
    }
    return pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(fontSize: size, lineSpacing: 3.5),
        children: [
          for (final c in chunks)
            if (c.isLink && isSafeUrl(c.url!))
              pw.TextSpan(
                text: c.text,
                style: pw.TextStyle(
                    color: PdfColors.blue700,
                    decoration: pw.TextDecoration.underline),
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

  /// د میټاډیټا کیلي/ارزښت کرښې.
  static List<MapEntry<String, String>> _jsonRows(EventMetadata e) {
    final j = e.toJson();
    // اوږد متن پرېږدو — هغه پخپله په پاڼه کې پورته دی.
    j.remove('text');
    return [for (final x in j.entries) MapEntry(x.key, '${x.value}')];
  }
}
