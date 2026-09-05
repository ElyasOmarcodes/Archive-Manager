import 'package:flutter_test/flutter_test.dart';
import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/theme/tokens.dart';
import 'package:archive_manager/data/index/event_index.dart';
import 'package:archive_manager/data/index/index_db.dart';
import 'package:archive_manager/data/index/memory_index.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/data/models/query.dart';

/// دواړه ماشینونه باید یو شان پایلې ورکړي — که نه، یو یې خراب دی.
void main() {
  late IndexDb sql;
  late MemoryIndex mem;
  late List<EventMetadata> data;

  setUp(() {
    sql = IndexDb.openMemory();
    mem = MemoryIndex();

    final cats = ['سیاسي', 'امنیتي', 'اقتصادي', 'ټولنیز'];
    final kws = ['تړون', 'چین', 'امنیت', 'پارلمان', 'سوله', 'کډوال'];
    final ppl = ['حامد کرزی', 'اشرف غني', 'زرمینه'];
    final media = [MediaKind.video, MediaKind.image, MediaKind.audio,
                   MediaKind.document, MediaKind.sheet];

    data = [
      for (var i = 0; i < 120; i++)
        EventMetadata(
          id: 'e$i',
          title: 'پیښه ${i}: د ${cats[i % 4]} ${kws[i % 6]} راپور',
          summary: 'د دې پیښې لنډ وضاحت — ${kws[(i * 5) % 6]}',
          folderPath: 'E:/Arvitch/e$i',
          date: TriDate.fromJdn(TriDate.fromShamsi(1400, 1, 1).jdn + i * 11),
          category: i % 9 == 0 ? '' : cats[i % 4],
          rating: i % 6,
          colorTag: ColorTag.values[i % ColorTag.values.length],
          keywords: {kws[i % 6], kws[(i * 3) % 6]}.toList(),
          persons: i % 5 == 0 ? [] : [ppl[i % 3]],
          attachments: [
            for (var k = 0; k <= i % 4; k++)
              Attachment(
                  name: 'f$k', relativePath: 'attachments/f$k',
                  kind: media[(i + k) % 5], sizeBytes: 1000 * (k + 1)),
          ],
        ),
    ];

    sql.upsertAll(data);
    mem.upsertAll(data);
  });

  tearDown(() => sql.dispose());

  void agree(String label, EventQuery q) {
    final a = sql.search(q.copyWith(limit: 1000)).map((e) => e.id).toList();
    final b = mem.search(q.copyWith(limit: 1000)).map((e) => e.id).toList();
    expect(b, a, reason: '$label — result sets differ');
    expect(mem.count(q), sql.count(q), reason: '$label — counts differ');
  }

  test('filter parity across every facet group', () {
    agree('no filter', const EventQuery());
    agree('rating', EventQuery(ratings: {5}));
    agree('rating multi', EventQuery(ratings: {0, 3, 5}));
    agree('color', EventQuery(colors: {ColorTag.red, ColorTag.blue}));
    agree('category', EventQuery(categories: {'سیاسي'}));
    agree('keyword OR', EventQuery(keywords: {'چین', 'سوله'}));
    agree('person', EventQuery(persons: {'حامد کرزی'}));
    agree('media', EventQuery(mediaKinds: {MediaKind.video}));
    agree('media multi',
        EventQuery(mediaKinds: {MediaKind.video, MediaKind.sheet}));
    agree('folder prefix', const EventQuery(folderPrefix: 'E:/Arvitch/e1'));
  });

  test('date range parity across all three calendars', () {
    for (final r in [
      (TriDate.fromShamsi(1400, 1, 1).jdn, TriDate.fromShamsi(1401, 1, 1).jdn),
      (TriDate.fromQamari(1443, 1, 1).jdn, TriDate.fromQamari(1445, 1, 1).jdn),
      (TriDate.fromGregorian(2022, 1, 1).jdn,
       TriDate.fromGregorian(2024, 6, 30).jdn),
    ]) {
      agree('range ${r.$1}-${r.$2}', EventQuery(fromJdn: r.$1, toJdn: r.$2));
    }
    agree('open-ended from',
        EventQuery(fromJdn: TriDate.fromShamsi(1402, 1, 1).jdn));
    agree('open-ended to',
        EventQuery(toJdn: TriDate.fromShamsi(1402, 1, 1).jdn));
  });

  test('combined AND across groups', () {
    agree('rating+cat', EventQuery(ratings: {3, 4, 5}, categories: {'سیاسي'}));
    agree(
        'kitchen sink',
        EventQuery(
          ratings: {2, 3, 4, 5},
          categories: {'سیاسي', 'امنیتي'},
          keywords: {'چین', 'تړون'},
          mediaKinds: {MediaKind.video, MediaKind.image},
          fromJdn: TriDate.fromShamsi(1400, 1, 1).jdn,
          toJdn: TriDate.fromShamsi(1404, 12, 29).jdn,
        ));
  });

  test('sort parity for every sort field', () {
    for (final f in SortField.values) {
      agree('sort ${f.name}', EventQuery(sort: f));
    }
  });

  test('facet count parity', () {
    for (final q in [
      const EventQuery(),
      EventQuery(ratings: {5}),
      EventQuery(categories: {'سیاسي'}, keywords: {'چین'}),
      EventQuery(
          fromJdn: TriDate.fromShamsi(1401, 1, 1).jdn,
          mediaKinds: {MediaKind.audio}),
    ]) {
      final a = sql.facets(q);
      final b = mem.facets(q);
      expect(b.total, a.total, reason: 'total');
      expect(b.ratings, a.ratings, reason: 'ratings');
      expect(b.colors, a.colors, reason: 'colors');
      expect(b.categories, a.categories, reason: 'categories');
      expect(b.persons, a.persons, reason: 'persons');
      expect(b.mediaKinds, a.mediaKinds, reason: 'media');
      expect(b.years, a.years, reason: 'years');
      // sql caps keywords at 200; our data has 6 so they must match
      expect(b.keywords, a.keywords, reason: 'keywords');
    }
  });

  test('full-text parity for Pashto queries', () {
    for (final t in ['چین', 'پارلمان', 'سیاسي', 'راپور', 'پیښه',
                     'سوله کډوال', 'وضاحت', 'زرمین']) {
      agree('text "$t"', EventQuery(text: t));
    }
  });

  test('vocab + stats parity', () {
    for (final k in VocabKind.values) {
      final a = {for (final t in sql.vocab(k)) t.name: t.usageCount};
      final b = {for (final t in mem.vocab(k)) t.name: t.usageCount};
      expect(b, a, reason: 'vocab ${k.name}');
      expect(mem.eventsUsing(k, a.keys.first).map((e) => e.id).toSet(),
          sql.eventsUsing(k, a.keys.first).map((e) => e.id).toSet());
    }

    final a = sql.stats();
    final b = mem.stats();
    expect(b.eventCount, a.eventCount);
    expect(b.attachmentCount, a.attachmentCount);
    expect(b.totalBytes, a.totalBytes);
    expect(b.keywordCount, a.keywordCount);
    expect(b.personCount, a.personCount);
    expect(b.categoryCount, a.categoryCount);
    expect(b.mediaBreakdown, a.mediaBreakdown);
    expect(b.ratingSpread, a.ratingSpread);
    expect(b.weeklyActivity, a.weeklyActivity);
  });

  test('remove and clear parity', () {
    sql.remove('e5');
    mem.remove('e5');
    agree('after remove', const EventQuery());
    expect(mem.byId('e5'), isNull);
    expect(sql.byId('e5'), isNull);

    sql.clear();
    mem.clear();
    expect(mem.count(const EventQuery()), 0);
    expect(sql.count(const EventQuery()), 0);
  });

  test('both satisfy the shared interface', () {
    expect(sql, isA<EventIndex>());
    expect(mem, isA<EventIndex>());
  });
}
