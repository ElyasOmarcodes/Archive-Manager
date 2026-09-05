import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../models/models.dart';
import '../models/query.dart';
import '../platform/backend.dart';
import 'event_index.dart';

/// **د یادښت دننه لټون ماشین** — بشپړ Dart، هیڅ اصلي کتابتون ته اړتیا نه لري.
///
/// ویب کې `dart:ffi` نشته، نو SQLite هلته نه چلیږي. دا تطبیق د نندارې
/// نسخې لپاره دی او **دقیقاً هماغه منطق** پلې کوي چې `IndexDb` یې کوي —
/// د ډلو ترمنځ AND، د یوې ډلې دننه OR، او ژوندۍ فاسیټ شمېرې.
class MemoryIndex implements EventIndex {
  final Map<String, EventMetadata> _events = {};
  final Map<VocabKind, Map<String, VocabTerm>> _vocab = {
    for (final k in VocabKind.values) k: {},
  };

  @override
  void dispose() {}

  // ═══════════════════════════════════════════════════════
  //  لیکل
  // ═══════════════════════════════════════════════════════

  @override
  void upsert(EventMetadata e) {
    _events[e.id] = e;
    for (final k in e.keywords) {
      _vocab[VocabKind.keyword]!.putIfAbsent(k, () => VocabTerm(name: k));
    }
    for (final p in e.persons) {
      _vocab[VocabKind.person]!.putIfAbsent(p, () => VocabTerm(name: p));
    }
    if (e.category.trim().isNotEmpty) {
      _vocab[VocabKind.category]!
          .putIfAbsent(e.category, () => VocabTerm(name: e.category));
    }
  }

  @override
  void upsertAll(Iterable<EventMetadata> items) => items.forEach(upsert);

  @override
  void remove(String id) => _events.remove(id);

  @override
  void clear() {
    _events.clear();
    for (final m in _vocab.values) {
      m.clear();
    }
  }

  // ═══════════════════════════════════════════════════════
  //  فلټر
  // ═══════════════════════════════════════════════════════

  /// یوه پیښه د پوښتنې سره سمون لري؟ (`exclude` یوه ډله بې‌اغېزې کوي)
  bool _matches(EventMetadata e, EventQuery q, {String? exclude}) {
    if (exclude != 'text' && q.text.trim().isNotEmpty) {
      if (!_matchesText(e, q.text)) return false;
    }
    if (exclude != 'rating' && q.ratings.isNotEmpty) {
      if (!q.ratings.contains(e.rating)) return false;
    }
    if (exclude != 'color' && q.colors.isNotEmpty) {
      if (!q.colors.contains(e.colorTag)) return false;
    }
    if (exclude != 'category' && q.categories.isNotEmpty) {
      if (!q.categories.contains(e.category)) return false;
    }
    if (exclude != 'keyword' && q.keywords.isNotEmpty) {
      if (!e.keywords.any(q.keywords.contains)) return false;
    }
    if (exclude != 'person' && q.persons.isNotEmpty) {
      if (!e.persons.any(q.persons.contains)) return false;
    }
    if (exclude != 'media' && q.mediaKinds.isNotEmpty) {
      if (!e.attachments.any((a) => q.mediaKinds.contains(a.kind))) return false;
    }
    if (exclude != 'date') {
      if (q.fromJdn != null && e.date.jdn < q.fromJdn!) return false;
      if (q.toJdn != null && e.date.jdn > q.toJdn!) return false;
    }
    if (q.folderPrefix != null && q.folderPrefix!.isNotEmpty) {
      if (!e.folderPath.startsWith(q.folderPrefix!)) return false;
    }
    return true;
  }

  /// د FTS5 د چلند نقل: هر ټکی باید پیدا شي (AND)، او د ټکي پیل
  /// کافي دی (prefix match).
  static bool _matchesText(EventMetadata e, String raw) {
    final blob = _normalize('${e.title} ${e.searchBlob}');
    final tokens = _normalize(raw)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return true;
    final words = blob.split(RegExp(r'\s+'));
    return tokens.every((t) => words.any((w) => w.startsWith(t)));
  }

  /// د عربي/پښتو د حروفو نورمالول — د FTS5 د
  /// `unicode61 remove_diacritics` په څېر.
  static String _normalize(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      // زواید (حرکات) لرې کوو
      if (r >= 0x064B && r <= 0x0652) continue;
      if (r == 0x0640) continue; // تطویل
      b.writeCharCode(switch (r) {
        0x0643 => 0x06A9, // ك → ک
        0x064A => 0x06CC, // ي → ی
        0x0623 || 0x0625 || 0x0622 => 0x0627, // أ إ آ → ا
        0x0629 => 0x0647, // ة → ه
        _ => r,
      });
    }
    return b.toString().toLowerCase().replaceAll(RegExp(r'[^\w؀-ۿ\s]'), ' ');
  }

  List<EventMetadata> _filtered(EventQuery q, {String? exclude}) =>
      _events.values.where((e) => _matches(e, q, exclude: exclude)).toList();

  // ═══════════════════════════════════════════════════════
  //  لوستل
  // ═══════════════════════════════════════════════════════

  @override
  List<EventMetadata> search(EventQuery q) {
    final list = _filtered(q)..sort((a, b) => _compare(a, b, q.sort));
    if (q.offset >= list.length) return const [];
    return list.skip(q.offset).take(q.limit).toList();
  }

  /// هماغه ټاکلی ترتیب چې `IndexDb._orderBy` یې کوي — د `id` په
  /// دویمه کیلي، نو دواړه ماشینونه تل یو شان لړ راوړي.
  static int _compare(EventMetadata a, EventMetadata b, SortField s) {
    final keys = switch (s) {
      SortField.dateDesc => [
          b.date.jdn.compareTo(a.date.jdn),
          a.title.compareTo(b.title),
        ],
      SortField.dateAsc => [
          a.date.jdn.compareTo(b.date.jdn),
          a.title.compareTo(b.title),
        ],
      SortField.titleAsc => [a.title.compareTo(b.title)],
      SortField.titleDesc => [b.title.compareTo(a.title)],
      SortField.ratingDesc => [
          b.rating.compareTo(a.rating),
          b.date.jdn.compareTo(a.date.jdn),
        ],
      SortField.ratingAsc => [
          a.rating.compareTo(b.rating),
          b.date.jdn.compareTo(a.date.jdn),
        ],
      SortField.createdDesc => [b.createdAt.compareTo(a.createdAt)],
      SortField.updatedDesc => [b.updatedAt.compareTo(a.updatedAt)],
      SortField.sizeDesc => [b.totalBytes.compareTo(a.totalBytes)],
      SortField.filesDesc => [b.attachmentCount.compareTo(a.attachmentCount)],
    };
    for (final k in keys) {
      if (k != 0) return k;
    }
    return a.id.compareTo(b.id);
  }

  @override
  int count(EventQuery q) => _filtered(q).length;

  @override
  EventMetadata? byId(String id) => _events[id];

  @override
  FacetCounts facets(EventQuery q) {
    Map<K, int> tally<K>(String exclude, Iterable<K> Function(EventMetadata) keys) {
      final m = <K, int>{};
      for (final e in _filtered(q, exclude: exclude)) {
        for (final k in keys(e).toSet()) {
          m[k] = (m[k] ?? 0) + 1;
        }
      }
      return m;
    }

    return FacetCounts(
      total: count(q),
      ratings: tally<int>('rating', (e) => [e.rating]),
      colors: tally<ColorTag>('color', (e) => [e.colorTag]),
      categories: tally<String>('category',
          (e) => e.category.trim().isEmpty ? const [] : [e.category]),
      keywords: tally<String>('keyword', (e) => e.keywords),
      persons: tally<String>('person', (e) => e.persons),
      mediaKinds:
          tally<MediaKind>('media', (e) => e.attachments.map((a) => a.kind)),
      years: tally<int>('date', (e) => [e.date.shamsi.year]),
    );
  }

  @override
  ArchiveStats stats() {
    final all = _events.values.toList();
    final media = <MediaKind, int>{};
    final ratings = <int, int>{};
    for (final e in all) {
      for (final a in e.attachments) {
        media[a.kind] = (media[a.kind] ?? 0) + 1;
      }
      ratings[e.rating] = (ratings[e.rating] ?? 0) + 1;
    }

    final today = TriDate.now().jdn;
    final weekly = [
      for (var i = 6; i >= 0; i--)
        all.where((e) => e.date.jdn == today - i).length
    ];

    final recent = [...all]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ArchiveStats(
      eventCount: all.length,
      attachmentCount: all.fold(0, (a, e) => a + e.attachmentCount),
      totalBytes: all.fold(0, (a, e) => a + e.totalBytes),
      keywordCount: _vocab[VocabKind.keyword]!.length,
      personCount: _vocab[VocabKind.person]!.length,
      categoryCount: _vocab[VocabKind.category]!.length,
      mediaBreakdown: media,
      ratingSpread: ratings,
      weeklyActivity: weekly,
      recentEvents: recent.take(6).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  لغتونه
  // ═══════════════════════════════════════════════════════

  @override
  List<VocabTerm> vocab(VocabKind kind) {
    final counts = <String, int>{};
    for (final e in _events.values) {
      final terms = switch (kind) {
        VocabKind.keyword => e.keywords,
        VocabKind.person => e.persons,
        VocabKind.category =>
          e.category.trim().isEmpty ? const <String>[] : [e.category],
      };
      for (final t in terms.toSet()) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final list = _vocab[kind]!
        .values
        .map((t) => VocabTerm(
              name: t.name,
              colorTag: t.colorTag,
              note: t.note,
              usageCount: counts[t.name] ?? 0,
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  void addVocab(VocabKind kind, VocabTerm t) => _vocab[kind]![t.name] = t;

  @override
  void deleteVocabRow(VocabKind kind, String name) =>
      _vocab[kind]!.remove(name);

  @override
  List<EventMetadata> eventsUsing(VocabKind kind, String name) =>
      _events.values.where((e) {
        return switch (kind) {
          VocabKind.keyword => e.keywords.contains(name),
          VocabKind.person => e.persons.contains(name),
          VocabKind.category => e.category == name,
        };
      }).toList();
}
