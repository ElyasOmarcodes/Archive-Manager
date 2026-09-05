import 'package:flutter_test/flutter_test.dart';
import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/theme/tokens.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/features/editor/html_builder.dart';

void main() {
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
