/// **د پښتو/عربي متن نورمالول.**
///
/// پښتو په دوو مختلفو کوډونو لیکل کیږي: عربي «ي» (U+064A) او پښتو
/// «ی» (U+06CC)، عربي «ك» (U+0643) او پښتو «ک» (U+06A9). سترګو ته
/// یو شان دي، خو کمپیوټر ته بېل حروف دي. که یې ونه نورمالوو،
/// «کابل» به «كابل» ونه موندل شي.
///
/// دا دقیقاً هغه څه کوي چې د SQLite د FTS5
/// `unicode61 remove_diacritics 2` یې کوي — نو د لټون او د
/// وړاندیزونو چلند یو شان وي.
library;

/// متن نورمالوي. زواید (حرکات) او تطویل غورځوي.
String normalizePashto(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x064B && r <= 0x0652) continue; // حرکات
    if (r == 0x0640) continue; //                تطویل ـ
    if (r == 0x200C || r == 0x200D) continue; // نیم‌ځای
    b.writeCharCode(switch (r) {
      0x0643 => 0x06A9, //                     ك → ک
      0x064A || 0x0649 => 0x06CC, //           ي ى → ی
      0x0623 || 0x0625 || 0x0622 => 0x0627, // أ إ آ → ا
      0x0629 || 0x06C0 => 0x0647, //           ة ۀ → ه
      _ => r,
    });
  }
  return b.toString().toLowerCase();
}

/// عربي/پښتو عددونه لاتیني ته — نو «۱۴۰۵» او «1405» یو شان وي.
String normalizeDigits(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    var i = fa.indexOf(ch);
    if (i < 0) i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

/// د لټون لپاره بشپړ نورمالول — حروف + عددونه.
String searchKey(String s) => normalizeDigits(normalizePashto(s)).trim();

/// **د وړاندیزونو ترتیب.**
///
/// دقیق مطابقت تر ټولو مخکې، بیا هغه چې له پیل څخه سمون خوري،
/// بیا هغه چې یوه کلمه یې له پیل څخه سمون خوري، بیا نور.
/// که هیڅ سمون نه وي، `-1` راګرځوي.
int matchScore(String candidate, String query) {
  final c = searchKey(candidate);
  final q = searchKey(query);
  if (q.isEmpty) return 0;
  if (c == q) return 100;
  if (c.startsWith(q)) return 80;
  for (final w in c.split(RegExp(r'\s+'))) {
    if (w.startsWith(q)) return 60;
  }
  if (c.contains(q)) return 40;
  return -1;
}

// ═══════════════════════════════════════════════════════════
//  د لینکونو پېژندل
// ═══════════════════════════════════════════════════════════

/// د متن یوه برخه — یا ساده متن، یا لینک.
class TextChunk {
  const TextChunk(this.text, {this.url});

  final String text;

  /// که `null` نه وي، دا برخه یو لینک دی او دا یې بشپړ پته ده.
  final String? url;

  bool get isLink => url != null;
}

/// http(s) لینکونه، `www.` پیلونه او بریښنالیکونه.
///
/// د پای نښې (`. , ) ؛ …`) له لینکه بهر پاتې کیږي — نو
/// «وګورئ: https://x.com/a.» کې تېر ټکی د لینک برخه نه ده.
final _linkRe = RegExp(
  r'(https?://[^\s<>"]+|www\.[^\s<>"]+|[\w.+-]+@[\w-]+\.[\w.-]+)',
  caseSensitive: false,
);

const _trailing = '.,;:!?)]}»”’،؛؟…';

/// **متن پر برخو ویشي — ساده متن او لینکونه.**
///
/// دا یوه سرچینه ده چې هم د پروګرام دننه پریویو یې کاروي، هم د
/// `index.html` جوړونکی — نو دواړه ځایه یو شان چلند کوي.
List<TextChunk> linkify(String text) {
  if (text.isEmpty) return const [];
  final out = <TextChunk>[];
  var last = 0;

  for (final m in _linkRe.allMatches(text)) {
    var raw = m.group(0)!;
    var end = m.end;

    // د پای ټکي/کامې له لینکه بهر پرېږده
    while (raw.isNotEmpty && _trailing.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
      end--;
    }
    // نامتوازن تړونکی قوس هم بهر پرېږده: «(x.com/a)»
    while (raw.endsWith(')') &&
        ')'.allMatches(raw).length > '('.allMatches(raw).length) {
      raw = raw.substring(0, raw.length - 1);
      end--;
    }
    if (raw.isEmpty) continue;

    if (m.start > last) out.add(TextChunk(text.substring(last, m.start)));

    final url = raw.contains('@') && !raw.startsWith('http')
        ? 'mailto:$raw'
        : (raw.startsWith('http') ? raw : 'https://$raw');
    out.add(TextChunk(raw, url: url));
    last = end;
  }

  if (last < text.length) out.add(TextChunk(text.substring(last)));
  return out;
}

/// آیا دا پته د پرانیستلو لپاره خوندي ده؟
///
/// یوازې `http`, `https` او `mailto` منو. `javascript:` او
/// `data:` رد کیږي — هغه د کوډ د ننوتلو لار ده.
bool isSafeUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('http://') ||
      u.startsWith('https://') ||
      u.startsWith('mailto:');
}
