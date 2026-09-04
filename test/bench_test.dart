import 'package:flutter_test/flutter_test.dart';
import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/theme/tokens.dart';
import 'package:archive_manager/data/index/index_db.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/data/models/query.dart';

void main() {
  test('BENCHMARK: 20,000 events', () {
    final db = IndexDb.openMemory();
    final cats = ['سیاسي', 'امنیتي', 'اقتصادي', 'ټولنیز', 'کلتوري', 'ورزشي'];
    final kws = ['تړون','چین','امنیت','پارلمان','ولسمشر','بریدونه','سوله',
                 'کډوال','بودیجه','زلزله','لوبې','ښوونځی','روغتیا','بند'];
    final ppl = ['حامد کرزی','اشرف غني','عبدالله عبدالله','محمد نبي','زرمینه'];
    final media = MediaKind.values;

    final sw = Stopwatch()..start();
    final batch = <EventMetadata>[];
    for (var i = 0; i < 20000; i++) {
      final d = TriDate.fromJdn(TriDate.fromShamsi(1395, 1, 1).jdn + (i % 3650));
      batch.add(EventMetadata(
        id: 'e$i',
        title: 'پیښه $i — د ${cats[i % 6]} ${kws[i % 14]} پېښه',
        folderPath: 'E:/Arvitch/${d.shamsi.year}/${d.shamsi.month}/e$i',
        date: d,
        category: cats[i % 6],
        rating: i % 6,
        colorTag: ColorTag.values[i % ColorTag.values.length],
        keywords: [kws[i % 14], kws[(i * 7) % 14], kws[(i * 3) % 14]],
        persons: [ppl[i % 5], ppl[(i * 3) % 5]],
        summary: 'د دې پیښې لنډ وضاحت چې د ${cats[i % 6]} په برخه کې ثبت شوی دی.',
        attachments: [
          for (var k = 0; k < (i % 5) + 1; k++)
            Attachment(
                name: 'file_$k.${media[(i + k) % media.length].extensions.isEmpty ? "bin" : media[(i + k) % media.length].extensions.first}',
                relativePath: 'attachments/file_$k',
                kind: media[(i + k) % media.length],
                sizeBytes: 500000 * (k + 1)),
        ],
      ));
    }
    print('build models:      ${sw.elapsedMilliseconds} ms');

    sw.reset();
    db.upsertAll(batch);
    print('index 20,000:      ${sw.elapsedMilliseconds} ms');

    void time(String label, void Function() f) {
      final s = Stopwatch()..start();
      f();
      print('${label.padRight(19)}${s.elapsedMicroseconds / 1000} ms');
    }

    late int n;
    time('full-text "پارلمان"', () {
      n = db.search(const EventQuery(text: 'پارلمان', limit: 100)).length;
    });
    print('   -> $n rows');

    time('multi-word FTS', () {
      n = db.search(const EventQuery(text: 'سیاسي تړون', limit: 100)).length;
    });
    print('   -> $n rows');

    time('rating+color+cat', () {
      n = db.search(EventQuery(
          ratings: {5}, colors: {ColorTag.red}, categories: {'سیاسي'},
          limit: 100)).length;
    });
    print('   -> $n rows');

    time('date range (1400)', () {
      n = db.search(EventQuery(
          fromJdn: TriDate.fromShamsi(1400, 1, 1).jdn,
          toJdn: TriDate.fromShamsi(1400, 12, 29).jdn, limit: 100)).length;
    });
    print('   -> $n rows');

    time('keyword+person', () {
      n = db.search(EventQuery(
          keywords: {'چین', 'سوله'}, persons: {'حامد کرزی'}, limit: 100)).length;
    });
    print('   -> $n rows');

    time('ALL facet counts', () {
      final f = db.facets(EventQuery(ratings: {5}, categories: {'سیاسي'}));
      n = f.total;
    });
    print('   -> $n total');

    time('combined worst-case', () {
      n = db.search(EventQuery(
        text: 'پیښه',
        ratings: {3, 4, 5},
        categories: {'سیاسي', 'امنیتي'},
        keywords: {'چین'},
        mediaKinds: {MediaKind.video},
        fromJdn: TriDate.fromShamsi(1398, 1, 1).jdn,
        toJdn: TriDate.fromShamsi(1404, 12, 29).jdn,
        limit: 100,
      )).length;
    });
    print('   -> $n rows');

    time('stats (dashboard)', () => db.stats());

    db.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
