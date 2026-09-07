import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/theme/tokens.dart';
import 'package:archive_manager/data/index/index_db.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/data/models/query.dart';

EventMetadata mk(String id, String title, TriDate d,
    {int rating = 0,
    ColorTag color = ColorTag.none,
    String cat = '',
    List<String> kw = const [],
    List<String> ppl = const [],
    List<MediaKind> media = const []}) {
  return EventMetadata(
    id: id, title: title, folderPath: 'E:/Arvitch/$id', date: d,
    category: cat, rating: rating, colorTag: color,
    keywords: [...kw], persons: [...ppl],
    summary: 'د $title لنډ وضاحت',
    attachments: [
      for (var i = 0; i < media.length; i++)
        Attachment(name: 'f$i.${media[i].extensions.first}',
            relativePath: 'attachments/f$i.${media[i].extensions.first}',
            kind: media[i], sizeBytes: 1000 * (i + 1)),
    ],
  );
}

void main() {
  _paging();
  late IndexDb db;
  setUp(() {
    db = IndexDb.openMemory();
    db.upsertAll([
      mk('e1', 'د کابل او چین تړون', TriDate.fromShamsi(1405, 6, 13),
          rating: 5, color: ColorTag.red, cat: 'سیاسي',
          kw: ['تړون', 'چین'], ppl: ['حامد کرزی'],
          media: [MediaKind.video, MediaKind.image]),
      mk('e2', 'د کندهار امنیتي پیښه', TriDate.fromShamsi(1405, 5, 2),
          rating: 3, color: ColorTag.blue, cat: 'امنیتي',
          kw: ['امنیت', 'چین'], ppl: ['احمد شاه'],
          media: [MediaKind.audio]),
      mk('e3', 'د پارلمان غونډه', TriDate.fromShamsi(1404, 9, 20),
          rating: 5, color: ColorTag.red, cat: 'سیاسي',
          kw: ['پارلمان'], media: [MediaKind.image, MediaKind.document]),
    ]);
  });
  tearDown(() => db.dispose());

  test('full text search finds Pashto text', () {
    expect(db.search(const EventQuery(text: 'کابل')).map((e) => e.id), ['e1']);
    // 'چین' is a keyword on e1 and e2 — keywords are part of the FTS body
    expect(db.search(const EventQuery(text: 'چین')).map((e) => e.id).toSet(),
        {'e1', 'e2'});
    // keyword blob is inside FTS body too
    expect(db.search(const EventQuery(text: 'امنیت')).map((e) => e.id), ['e2']);
    // prefix search
    expect(db.search(const EventQuery(text: 'پارلم')).map((e) => e.id), ['e3']);
  });

  test('facet filters AND across groups, OR within', () {
    expect(db.search(EventQuery(ratings: {5})).length, 2);
    expect(db.search(EventQuery(ratings: {5}, categories: {'سیاسي'})).length, 2);
    expect(db.search(EventQuery(ratings: {5}, colors: {ColorTag.blue})).length, 0);
    expect(db.search(EventQuery(keywords: {'چین'})).length, 2, reason: 'OR within group');
    expect(db.search(EventQuery(keywords: {'چین'}, ratings: {3})).length, 1);
    expect(db.search(EventQuery(mediaKinds: {MediaKind.video})).map((e) => e.id), ['e1']);
    expect(db.search(EventQuery(persons: {'حامد کرزی'})).map((e) => e.id), ['e1']);
  });

  test('date range works across all three calendars via JDN', () {
    final from = TriDate.fromShamsi(1405, 1, 1).jdn;
    final to = TriDate.fromShamsi(1405, 12, 29).jdn;
    expect(db.search(EventQuery(fromJdn: from, toJdn: to)).length, 2);

    // same window expressed in Gregorian
    final g1 = TriDate.fromGregorian(2026, 3, 21).jdn;
    final g2 = TriDate.fromGregorian(2027, 3, 20).jdn;
    expect(db.search(EventQuery(fromJdn: g1, toJdn: g2)).length, 2);

    // Hijri qamari window
    final q1 = TriDate.fromQamari(1447, 1, 1).jdn;
    expect(db.search(EventQuery(fromJdn: q1)).length, greaterThan(0));
  });

  test('facet counts exclude their own group (Bridge behaviour)', () {
    final f = db.facets(EventQuery(ratings: {5}));
    expect(f.total, 2);
    // rating group counts ignore the rating filter, so rating 3 stays visible
    expect(f.ratings[3], 1);
    expect(f.ratings[5], 2);
    expect(f.categories['سیاسي'], 2);
    expect(f.colors[ColorTag.red], 2);
    expect(f.mediaKinds[MediaKind.image], 2);
    expect(f.years[1405], 1);
    expect(f.years[1404], 1);
  });

  test('sorting', () {
    expect(db.search(const EventQuery(sort: SortField.dateAsc)).first.id, 'e3');
    expect(db.search(const EventQuery(sort: SortField.dateDesc)).first.id, 'e1');
    expect(db.search(const EventQuery(sort: SortField.ratingAsc)).first.rating, 3);
  });

  test('vocab is auto-registered and usage counted', () {
    final kws = db.vocab(VocabKind.keyword);
    expect(kws.map((k) => k.name).toSet(),
        {'تړون', 'چین', 'امنیت', 'پارلمان'});
    expect(kws.firstWhere((k) => k.name == 'چین').usageCount, 2);
    expect(db.vocab(VocabKind.category).map((c) => c.name).toSet(),
        {'سیاسي', 'امنیتي'});
    expect(db.eventsUsing(VocabKind.keyword, 'چین').length, 2);
  });

  test('stats', () {
    final s = db.stats();
    expect(s.eventCount, 3);
    expect(s.attachmentCount, 5);
    expect(s.mediaBreakdown[MediaKind.image], 2);
    expect(s.ratingSpread[5], 2);
    expect(s.weeklyActivity.length, 7);
    expect(s.recentEvents.length, 3);
  });

  test('search injection characters do not crash FTS', () {
    for (final t in ['"', '*', 'a AND', '(((', 'NEAR(', '^x', 'کابل"']) {
      expect(() => db.search(EventQuery(text: t)), returnsNormally,
          reason: 'input: $t');
    }
  });
}

/// **د ترتیب او پاڼه‌بندۍ ازموینه.**
///
/// دا باګ کاروونکي وموند: د «نوم — الفبا» ترتیب یوازې د «ب» پیښې
/// راوړلې، او برعکس یې یوازې د «ک». علت دا و چې د لټون پایله په
/// ۵۰۰ محدوده وه، نو کاروونکی یوازې د ترتیب شوي لیست **یوه برخه**
/// لیده — او هغه یې د ناقص لیست په توګه پېژندله.
///
/// دلته ثابتوو چې پاڼه‌بندي د ترتیب پرله‌پسې والی نه ماتوي: د ټولو
/// پاڼو یوځای کول باید دقیقاً هغه لیست راوړي چې بې‌محدودیته راځي.
void _paging() {
  group('ترتیب + پاڼه‌بندي', () {
    late IndexDb db;
    const n = 1200;

    setUp(() {
      db = IndexDb.openMemory();
      final rnd = Random(7);
      const letters = 'ابپتجحدرسشکگلمنو';
      db.upsertAll([
        for (var i = 0; i < n; i++)
          EventMetadata(
            id: 'p-$i',
            title: '${letters[rnd.nextInt(letters.length)]}'
                '${letters[rnd.nextInt(letters.length)]} پیښه $i',
            folderPath: '/x/$i',
            date: TriDate.fromJdn(2450000 + rnd.nextInt(4000)),
            rating: rnd.nextInt(6),
          )
      ]);
    });

    tearDown(() => db.dispose());

    /// ټولې پاڼې یوځای — لکه چې کاروونکی تر پایه سکرول کړي.
    List<EventMetadata> allPages(SortField sort, {int page = 200}) {
      final out = <EventMetadata>[];
      while (out.length < n) {
        final chunk = db.search(
            EventQuery(sort: sort, limit: page, offset: out.length));
        if (chunk.isEmpty) break;
        out.addAll(chunk);
      }
      return out;
    }

    for (final sort in SortField.values) {
      test('${sort.name}: پاڼه‌بندي ترتیب نه ماتوي', () {
        final paged = allPages(sort);
        final whole = db.search(EventQuery(sort: sort, limit: n * 2));

        expect(paged.length, n, reason: 'ټولې پیښې باید راشي');
        expect(paged.map((e) => e.id).toList(),
            whole.map((e) => e.id).toList(),
            reason: 'د پاڼو یوځای کول باید بشپړ لیست ورکړي');
      });
    }

    test('د درجې ترتیب ټولې درجې راوړي — نه یوازې لوړې', () {
      final desc = allPages(SortField.ratingDesc);
      expect(desc.map((e) => e.rating).toSet(), {0, 1, 2, 3, 4, 5},
          reason: 'بې‌ستوري پیښې هم باید په لیست کې وي');
      // او ترتیب ریښتیا نزولي دی
      for (var i = 1; i < desc.length; i++) {
        expect(desc[i].rating, lessThanOrEqualTo(desc[i - 1].rating));
      }
    });

    test('د نوم ترتیب له لومړي تر وروستي حرف ځي', () {
      final asc = allPages(SortField.titleAsc);
      final titles = asc.map((e) => e.title).toList();
      expect(titles, orderedEquals(List.of(titles)..sort()));
      // د لیست لومړی او وروستی باید مختلف حرف ولري
      expect(titles.first[0], isNot(titles.last[0]),
          reason: 'ټول لیست باید راشي، نه یوازې د یوه حرف برخه');
    });
  });
}
