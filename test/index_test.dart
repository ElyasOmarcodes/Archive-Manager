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
