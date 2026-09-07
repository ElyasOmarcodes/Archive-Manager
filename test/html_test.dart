import 'package:flutter_test/flutter_test.dart';
import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/theme/tokens.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/features/editor/html_builder.dart';

void main() {
  _links();
  test('generates a complete standalone RTL page', () {
    final e = EventMetadata(
      id: 'x1',
      title: 'د کابل او چین تړون',
      folderPath: r'E:\A\x1',
      date: TriDate.fromShamsi(1405, 6, 13),
      category: 'سیاسي',
      summary: 'مهم تړون لاسلیک شو.',
      rating: 5,
      colorTag: ColorTag.red,
      keywords: ['تړون', 'چین'],
      persons: ['حامد کرزی'],
      blocks: [
        Block(id: '1', kind: BlockKind.heading, text: 'سریزه', level: 2),
        Block(id: '2', kind: BlockKind.paragraph, text: 'لومړۍ کرښه\nدویمه کرښه'),
        Block(id: '3', kind: BlockKind.quote, text: 'دا یو مهم پړاو دی',
            author: 'حامد کرزی'),
        Block(id: '4', kind: BlockKind.image,
            source: 'attachments/evidence_img_01.jpg', caption: 'د غونډې انځور'),
        Block(id: '5', kind: BlockKind.video,
            source: 'attachments/doc_video_01.mp4'),
        Block(id: '6', kind: BlockKind.audio,
            source: 'attachments/statement.wav', caption: 'بیان'),
        Block(id: '7', kind: BlockKind.file, source: 'attachments/data.xlsx'),
        Block(id: '8', kind: BlockKind.divider),
      ],
    );

    final html = buildEventHtml(e);

    // structure
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('<html lang="ps" dir="rtl">'));
    expect(html.trim(), endsWith('</html>'));
    expect(html, contains('</body>'));

    // all three calendars embedded
    expect(html, contains('۱۳ سنبله ۱۴۰۵'));
    expect(html, contains('event-date-qamari'));
    expect(html, contains('event-date-miladi'));

    // every block rendered
    expect(html, contains('<h2 class="blk h2'));
    expect(html, contains('لومړۍ کرښه<br>دویمه کرښه'));
    expect(html, contains('<blockquote'));
    expect(html, contains('onclick="openLb(this)"'));
    expect(html, contains('<video controls'));
    expect(html, contains('<audio controls'));
    expect(html, contains('file-card'));
    expect(html, contains('<hr class="blk rule'));

    // self-contained: no external refs
    expect(html.contains('http://'), isFalse);
    expect(html.contains('https://'), isFalse);
    expect(html, contains('<style>'));
    expect(html, contains('<script>'));

    // header/footer present
    expect(html, contains('class="hdr"'));
    expect(html, contains('class="ftr"'));
    expect(html, contains('toggleTheme'));
  });

  test('escapes user content — no HTML/script injection', () {
    final e = EventMetadata(
      id: 'x2',
      title: '<script>alert("xss")</script>',
      folderPath: '',
      date: TriDate.now(),
      summary: 'a & b < c > d "quoted"',
      keywords: ['<img onerror=alert(1)>'],
      persons: ["O'Brien"],
      blocks: [
        Block(id: '1', kind: BlockKind.paragraph,
            text: '</p><script>bad()</script>'),
        Block(id: '2', kind: BlockKind.quote,
            text: 'x', author: '"><script>y</script>'),
      ],
    );

    final html = buildEventHtml(e);

    expect(html.contains('<script>alert'), isFalse);
    expect(html.contains('<script>bad()'), isFalse);
    expect(html.contains('<script>y</script>'), isFalse);
    expect(html.contains('<img onerror'), isFalse);
    expect(html, contains('&lt;script&gt;alert'));
    expect(html, contains('a &amp; b &lt; c &gt; d &quot;quoted&quot;'));
    expect(html, contains('O&#39;Brien'));

    // the only <script> tags are ours
    expect('<script>'.allMatches(html).length, 1);
  });

  test('font-face rules are emitted only when a font dir is given', () {
    final e = EventMetadata(
      id: 'f1', title: 'ازموینه', folderPath: '', date: TriDate.now(),
      blocks: [Block(id: '1', kind: BlockKind.paragraph, text: 'متن')],
    );

    // پرته له فونټ فولډر — د سیسټم فونټ ته ورګرځي
    final plain = buildEventHtml(e);
    expect(plain.contains('@font-face'), isFalse);
    expect(plain, contains('font-family:Vazirmatn,"Segoe UI"'));

    // د فونټ فولډر سره — څلور وزنه تړل کیږي
    final withFont = buildEventHtml(e, fontDir: '../../../../_arvitch/fonts');
    expect('@font-face'.allMatches(withFont).length, 4);
    for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      expect(withFont,
          contains('url("../../../../_arvitch/fonts/Vazirmatn-$w.woff2")'));
    }
    // نسبي مسیر — نو د آرشیف لېږدول پاڼه نه ماتوي
    expect(withFont.contains('file://'), isFalse);
    expect(withFont.contains('C:'), isFalse);
    expect(withFont, contains('font-display:swap'));
  });

  test('missing sources degrade gracefully', () {
    final e = EventMetadata(
      id: 'x3', title: 't', folderPath: '', date: TriDate.now(),
      blocks: [
        Block(id: '1', kind: BlockKind.image),
        Block(id: '2', kind: BlockKind.video),
        Block(id: '3', kind: BlockKind.audio),
        Block(id: '4', kind: BlockKind.file),
      ],
    );
    final html = buildEventHtml(e);
    expect('class="blk missing'.allMatches(html).length, 4);
    expect(html, isNot(contains('src=""')));
  });
}

/// **د لینکونو اتومات پېژندل په جوړ شوي HTML کې.**
void _links() {
  EventMetadata withText(String text) => EventMetadata(
        id: 'lk',
        title: 'د لینک ازموینه',
        folderPath: '/x',
        date: TriDate.now(),
        blocks: [Block(id: 'b1', kind: BlockKind.paragraph, text: text)],
      );

  group('لینکونه په HTML کې', () {
    test('ساده لینک <a> کیږي او په نوې کړکۍ پرانیځي', () {
      final h = buildEventHtml(withText('سرچینه https://tolonews.com/a دلته'));
      expect(h, contains('<a href="https://tolonews.com/a"'));
      expect(h, contains('target="_blank"'));
      expect(h, contains('rel="noopener noreferrer"'));
    });

    test('www. لینک https:// ورسره لګیږي', () {
      final h = buildEventHtml(withText('www.example.af'));
      expect(h, contains('href="https://www.example.af"'));
    });

    test('بریښنالیک mailto: کیږي', () {
      final h = buildEventHtml(withText('اړیکه: info@arvitch.af'));
      expect(h, contains('href="mailto:info@arvitch.af"'));
    });

    test('javascript: هیڅکله <a href> نه جوړوي', () {
      final h = buildEventHtml(withText('javascript:alert(1)'));
      expect(h.contains('href="javascript:'), isFalse);
    });

    test('د HTML نښې لا هم تېښته کیږي — کوډ نه چلیږي', () {
      final h = buildEventHtml(
          withText('<script>alert(1)</script> او https://ok.af'));
      expect(h.contains('<script>alert(1)</script>'), isFalse);
      expect(h, contains('&lt;script&gt;'));
      // خو ریښتینی لینک لا هم کار کوي
      expect(h, contains('href="https://ok.af"'));
    });

    test('د لینک دننه د تېښتې وړ نښې خوندي دي', () {
      final h = buildEventHtml(withText('https://x.af/?a=1&b="2"'));
      expect(h.contains('&amp;'), isTrue);
      expect(h.contains('href="https://x.af/?a=1&b="2""'), isFalse);
    });
  });
}
