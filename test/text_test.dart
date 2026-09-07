import 'package:flutter_test/flutter_test.dart';
import 'package:archive_manager/core/text/pashto_text.dart';

void main() {
  group('د پښتو متن نورمالول', () {
    test('عربي او پښتو حروف یو شان کیږي', () {
      // «كابل» په عربي «ك» او «کابل» په پښتو «ک»
      expect(searchKey('كابل'), searchKey('کابل'));
      expect(searchKey('بامياڼ'), searchKey('بامیاڼ'));
      expect(searchKey('مدرسة'), searchKey('مدرسه'));
      expect(searchKey('أحمد'), searchKey('احمد'));
    });

    test('زواید او تطویل لرې کیږي', () {
      expect(searchKey('کِتاب'), 'کتاب');
      expect(searchKey('کــتاب'), 'کتاب');
    });

    test('پښتو او لاتیني عددونه یو شان کیږي', () {
      expect(searchKey('۱۴۰۵'), '1405');
      expect(searchKey('١٤٠٥'), '1405');
    });

    test('د وړاندیز ترتیب سم دی', () {
      // دقیق > له پیله > د کلمې له پیله > دننه > هیڅ
      expect(matchScore('کابل', 'کابل'), 100);
      expect(matchScore('کابل پوهنتون', 'کاب'), 80);
      expect(matchScore('د کابل تړون', 'کاب'), 60);
      expect(matchScore('ښارکابل', 'کاب'), 40);
      expect(matchScore('هرات', 'کاب'), -1);
      // او د کوډ توپیر یې نه ماتوي
      expect(matchScore('كابل', 'کاب'), 80);
    });
  });

  group('د لینکونو پېژندل', () {
    List<String> links(String s) =>
        [for (final c in linkify(s)) if (c.isLink) c.url!];

    test('http او https پېژندل کیږي', () {
      expect(links('وګورئ https://example.com/a دلته'),
          ['https://example.com/a']);
      expect(links('http://x.af'), ['http://x.af']);
    });

    test('www. پرته له سکیمه هم پېژندل کیږي', () {
      expect(links('www.tolonews.com'), ['https://www.tolonews.com']);
    });

    test('بریښنالیک mailto: کیږي', () {
      expect(links('اړیکه: info@arvitch.af'), ['mailto:info@arvitch.af']);
    });

    test('د جملې پای ټکی د لینک برخه نه ده', () {
      final c = linkify('سرچینه https://example.com/news.');
      final link = c.firstWhere((x) => x.isLink);
      expect(link.text, 'https://example.com/news');
      expect(c.last.text, '.');
    });

    test('نامتوازن قوس بهر پاتې کیږي', () {
      final c = linkify('(وګورئ https://example.com/a)');
      expect(c.firstWhere((x) => x.isLink).text, 'https://example.com/a');
    });

    test('څو لینکونه په یوه پاراګراف کې', () {
      expect(
        links('یو https://a.com بیا www.b.org او c@d.af'),
        ['https://a.com', 'https://www.b.org', 'mailto:c@d.af'],
      );
    });

    test('بې لینکه متن یوه برخه پاتې کیږي', () {
      final c = linkify('دا یوه ساده جمله ده.');
      expect(c.length, 1);
      expect(c.single.isLink, isFalse);
    });

    test('پښتو متن د لینک شاوخوا نه ماتیږي', () {
      final c = linkify('د کابل راپور https://x.af/1 د چا لخوا؟');
      expect(c.first.text, 'د کابل راپور ');
      expect(c[1].url, 'https://x.af/1');
      expect(c.last.text, ' د چا لخوا؟');
    });
  });

  group('د پتې خوندیتوب', () {
    test('یوازې http/https/mailto منل کیږي', () {
      expect(isSafeUrl('https://x.af'), isTrue);
      expect(isSafeUrl('http://x.af'), isTrue);
      expect(isSafeUrl('mailto:a@b.af'), isTrue);
    });

    test('javascript: او data: رد کیږي', () {
      expect(isSafeUrl('javascript:alert(1)'), isFalse);
      expect(isSafeUrl('JavaScript:alert(1)'), isFalse);
      expect(isSafeUrl('data:text/html,<script>'), isFalse);
      expect(isSafeUrl('file:///etc/passwd'), isFalse);
    });

    test('د لینک پېژندونکی هیڅکله javascript: نه جوړوي', () {
      // که څوک په متن کې `javascript:` ولیکي، لینک نه ترې جوړیږي
      for (final c in linkify('javascript:alert(1) او data:text/html,x')) {
        if (c.isLink) expect(isSafeUrl(c.url!), isTrue);
      }
    });
  });
}
