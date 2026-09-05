import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../models/models.dart';
import '../models/query.dart';
import '../platform/backend.dart';
import 'event_index.dart';

/// **د لټون ماشین — SQLite + FTS5.**
///
/// دا ډیټابیس د آرشیف **حقیقت نه دی** — یوازې یو مشتق ایندکس دی چې د
/// `metadata.json` فایلونو څخه جوړیږي. که ورک شي، بیا سکن یې بیرته جوړوي.
///
/// **ولې چټک دی:** مونږ د لټون پر مهال ډیسک نه ګورو. ټول لټون د دې کوچني
/// ایندکس دننه کیږي چې په بشپړ ډول د RAM دننه ځای نیسي — نو د ۵TB ډرایو
/// او د ۵GB ډرایو د لټون وخت یو شان دی.
class IndexDb implements EventIndex {
  IndexDb._(this._db);

  final Database _db;

  /// چمتو شوي بیانونه — یو ځل تالیف کیږي او زر ځله بیا کارول کیږي.
  /// د بشپړ سکن پر مهال دا ~۳۰ ځله چټکتیا راولي، ځکه SQLite بیا بیا
  /// د SQL پارس او پلان جوړول نه تکراروي.
  _Stmts? _s;
  _Stmts get _st => _s ??= _Stmts(_db);

  static IndexDb open(String file) {
    final db = sqlite3.open(file);
    _migrate(db);
    return IndexDb._(db);
  }

  static IndexDb openMemory() {
    final db = sqlite3.openInMemory();
    _migrate(db);
    return IndexDb._(db);
  }

  @override
  void dispose() {
    _s?.dispose();
    _s = null;
    _db.close();
  }

  // ═════════════════════════════════════════════════════════
  //  سکیما
  // ═════════════════════════════════════════════════════════

  /// د سکیما نسخه — که بدله شي، ایندکس پخپله بیا جوړیږي
  /// (ډیټا نه ورکیږي، ځکه حقیقت د `metadata.json` فایلونه دي).
  static const int schemaVersion = 3;

  static void _migrate(Database db) {
    final v = db.select('PRAGMA user_version').first.values.first as int;
    if (v != 0 && v != schemaVersion) {
      for (final t in ['events_fts', 'events', 'event_keywords',
                       'event_persons', 'event_media', 'vocab']) {
        db.execute('DROP TABLE IF EXISTS $t');
      }
    }
    db.execute('PRAGMA user_version = $schemaVersion');
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA synchronous = NORMAL');
    db.execute('PRAGMA temp_store = MEMORY');
    // ۶۴MB د صفحې کیش — د ایندکس ډېره برخه په حافظه کې ساتي.
    db.execute('PRAGMA cache_size = -65536');

    db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id            TEXT PRIMARY KEY,
        title         TEXT NOT NULL,
        folder        TEXT NOT NULL,
        category      TEXT NOT NULL DEFAULT '',
        summary       TEXT NOT NULL DEFAULT '',
        rating        INTEGER NOT NULL DEFAULT 0,
        color_tag     TEXT NOT NULL DEFAULT 'none',
        jdn           INTEGER NOT NULL,
        shamsi_y      INTEGER NOT NULL,
        shamsi_m      INTEGER NOT NULL,
        qamari_y      INTEGER NOT NULL,
        miladi_y      INTEGER NOT NULL,
        file_count    INTEGER NOT NULL DEFAULT 0,
        total_bytes   INTEGER NOT NULL DEFAULT 0,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL,
        payload       TEXT NOT NULL
      )''');

    // د فاسیټ فلټر لپاره ایندکسونه — هر یو د Bridge د یوه فلټر ډلې سره سمون لري.
    for (final col in [
      'rating', 'color_tag', 'category', 'jdn',
      'shamsi_y', 'qamari_y', 'miladi_y', 'updated_at', 'title'
    ]) {
      db.execute('CREATE INDEX IF NOT EXISTS idx_events_$col ON events($col)');
    }
    db.execute('CREATE INDEX IF NOT EXISTS idx_events_folder ON events(folder)');

    // ── ډېر-په-ډېر اړیکې ──
    for (final t in ['keywords', 'persons', 'media']) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS event_$t (
          event_id TEXT NOT NULL,
          term     TEXT NOT NULL,
          PRIMARY KEY (event_id, term)
        ) WITHOUT ROWID''');
      db.execute('CREATE INDEX IF NOT EXISTS idx_${t}_term ON event_$t(term)');
    }

    // ── د لغتونو جدول ──
    db.execute('''
      CREATE TABLE IF NOT EXISTS vocab (
        kind      TEXT NOT NULL,
        name      TEXT NOT NULL,
        color_tag TEXT NOT NULL DEFAULT 'none',
        note      TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (kind, name)
      ) WITHOUT ROWID''');

    // ── FTS5: د بشپړ متن معکوس ایندکس ──
    // `unicode61 remove_diacritics 2` عربي/پښتو زواید نورمالوي، نو
    // «کابل» او «كابل» دواړه یو شان موندل کیږي.
    //
    // **مهمه:** دا جدول د `rowid` له مخې د `events` جدول سره تړل شوی دی.
    // پخوا مو د `id` (متن) له مخې حذف کاوه، خو FTS5 د متني کالم لپاره
    // ایندکس نه لري — نو هر حذف یو بشپړ سکن و او د ۲۰ زرو پیښو ایندکس
    // جوړول O(n²) کېده. اوس حذف د عدد `rowid` له مخې دی — O(log n).
    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS events_fts USING fts5(
        title,
        body,
        tokenize = "unicode61 remove_diacritics 2"
      )''');
  }

  // ═════════════════════════════════════════════════════════
  //  لیکل
  // ═════════════════════════════════════════════════════════

  @override
  void upsert(EventMetadata e) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _upsertNoTx(e);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// ډله‌ییز داخلول — د بشپړ سکن لپاره ډېر چټک (یوه معامله).
  @override
  void upsertAll(Iterable<EventMetadata> items) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final e in items) {
        _upsertNoTx(e);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _upsertNoTx(EventMetadata e) {
    final st = _st;
    st.upsert.execute([
      e.id, e.title, e.folderPath, e.category, e.summary, e.rating,
      e.colorTag.name, e.date.jdn, e.date.shamsi.year, e.date.shamsi.month,
      e.date.qamari.year, e.date.gregorian.year, e.attachmentCount,
      // میکروثانیې (نه میلي‌ثانیې): په یوه میلي‌ثانیه کې لسګونه پیښې
      // ثبت کیدی شي، او د دې تر منځ توپیر باید د ترتیب پر مهال پاتې شي.
      e.totalBytes, e.createdAt.microsecondsSinceEpoch,
      e.updatedAt.microsecondsSinceEpoch, jsonEncode(e.toJson()),
    ]);
    // د دې پیښې عددي کیلي — بیا یې FTS ته هم ورکوو، نو دواړه سره تړلي دي.
    final rid = st.ridSel.select([e.id]).first['rowid'] as int;
    st.ftsDel.execute([rid]);
    st.ftsIns.execute([rid, e.title, e.searchBlob]);

    st.kwDel.execute([e.id]);
    st.psDel.execute([e.id]);
    st.mdDel.execute([e.id]);

    for (final k in e.keywords.toSet()) {
      st.kwIns.execute([e.id, k]);
      st.vocabIns.execute(['keyword', k]);
    }
    for (final p in e.persons.toSet()) {
      st.psIns.execute([e.id, p]);
      st.vocabIns.execute(['person', p]);
    }
    for (final m in e.attachments.map((a) => a.kind.name).toSet()) {
      st.mdIns.execute([e.id, m]);
    }
    if (e.category.trim().isNotEmpty) {
      st.vocabIns.execute(['category', e.category]);
    }
  }

  @override
  void remove(String id) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final r = _db.select('SELECT rowid FROM events WHERE id = ?', [id]);
      if (r.isNotEmpty) {
        _db.execute('DELETE FROM events_fts WHERE rowid = ?',
            [r.first['rowid']]);
      }
      _db.execute('DELETE FROM events WHERE id = ?', [id]);
      for (final t in ['keywords', 'persons', 'media']) {
        _db.execute('DELETE FROM event_$t WHERE event_id = ?', [id]);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  void clear() {
    _db.execute('DELETE FROM events');
    _db.execute('DELETE FROM events_fts');
    for (final t in ['keywords', 'persons', 'media']) {
      _db.execute('DELETE FROM event_$t');
    }
  }

  // ═════════════════════════════════════════════════════════
  //  د پوښتنې جوړول
  // ═════════════════════════════════════════════════════════

  /// د WHERE برخه او پیرامیټرې جوړوي.
  ///
  /// **د ډلو ترمنځ AND، د یوې ډلې دننه OR** — د Adobe Bridge چلند.
  (String, List<Object?>) _where(EventQuery q, {String? exclude}) {
    final parts = <String>[];
    final args = <Object?>[];

    final text = q.text.trim();
    if (text.isNotEmpty && exclude != 'text') {
      parts.add(
          'e.rowid IN (SELECT rowid FROM events_fts WHERE events_fts MATCH ?)');
      args.add(_ftsQuery(text));
    }
    if (q.ratings.isNotEmpty && exclude != 'rating') {
      parts.add('e.rating IN (${List.filled(q.ratings.length, '?').join(',')})');
      args.addAll(q.ratings);
    }
    if (q.colors.isNotEmpty && exclude != 'color') {
      parts.add('e.color_tag IN (${List.filled(q.colors.length, '?').join(',')})');
      args.addAll(q.colors.map((c) => c.name));
    }
    if (q.categories.isNotEmpty && exclude != 'category') {
      parts.add('e.category IN (${List.filled(q.categories.length, '?').join(',')})');
      args.addAll(q.categories);
    }
    if (q.keywords.isNotEmpty && exclude != 'keyword') {
      parts.add('e.id IN (SELECT event_id FROM event_keywords WHERE term IN '
          '(${List.filled(q.keywords.length, '?').join(',')}))');
      args.addAll(q.keywords);
    }
    if (q.persons.isNotEmpty && exclude != 'person') {
      parts.add('e.id IN (SELECT event_id FROM event_persons WHERE term IN '
          '(${List.filled(q.persons.length, '?').join(',')}))');
      args.addAll(q.persons);
    }
    if (q.mediaKinds.isNotEmpty && exclude != 'media') {
      parts.add('e.id IN (SELECT event_id FROM event_media WHERE term IN '
          '(${List.filled(q.mediaKinds.length, '?').join(',')}))');
      args.addAll(q.mediaKinds.map((m) => m.name));
    }
    // د نېټې سلسله — تل پر JDN، نو درې واړه تقویمونه یو شان چټک دي.
    if (exclude != 'date') {
      if (q.fromJdn != null) {
        parts.add('e.jdn >= ?');
        args.add(q.fromJdn);
      }
      if (q.toJdn != null) {
        parts.add('e.jdn <= ?');
        args.add(q.toJdn);
      }
    }
    if (q.folderPrefix != null && q.folderPrefix!.isNotEmpty) {
      parts.add('e.folder LIKE ?');
      args.add('${q.folderPrefix}%');
    }

    return (parts.isEmpty ? '' : 'WHERE ${parts.join(' AND ')}', args);
  }

  /// کاروونکي متن → د FTS5 خوندي پوښتنه.
  ///
  /// هر ټکی په `"..."` کې تړل کیږي (نو د FTS5 عملګر نښې زیان نه رسوي)
  /// او `*` ورسره یوځای کیږي — نو «کاب» هم «کابل» مومي.
  static String _ftsQuery(String raw) {
    final tokens = raw
        .replaceAll(RegExp(r'["\^\*\(\):]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '""';
    return tokens.map((t) => '"${t.replaceAll('"', '')}"*').join(' AND ');
  }

  /// **د ترتیب ټاکلې (deterministic) لار.**
  ///
  /// هر ترتیب د `id` په دویمه کیلي پای ته رسیږي — نو کله چې دوه پیښې
  /// یو شان ارزښت ولري (بېلګه: یو شان اندازه)، ترتیب یې تل یو شان وي.
  /// پرته له دې، SQLite او Dart دواړه خپل خوښ ترتیب راوړي او کاروونکی
  /// د هر تازه کولو سره بېل ترتیب ویني.
  static String _orderBy(SortField s) => switch (s) {
        SortField.dateDesc => 'e.jdn DESC, e.title ASC, e.id ASC',
        SortField.dateAsc => 'e.jdn ASC, e.title ASC, e.id ASC',
        SortField.titleAsc => 'e.title ASC, e.id ASC',
        SortField.titleDesc => 'e.title DESC, e.id ASC',
        SortField.ratingDesc => 'e.rating DESC, e.jdn DESC, e.id ASC',
        SortField.ratingAsc => 'e.rating ASC, e.jdn DESC, e.id ASC',
        SortField.createdDesc => 'e.created_at DESC, e.id ASC',
        SortField.updatedDesc => 'e.updated_at DESC, e.id ASC',
        SortField.sizeDesc => 'e.total_bytes DESC, e.id ASC',
        SortField.filesDesc => 'e.file_count DESC, e.id ASC',
      };

  // ═════════════════════════════════════════════════════════
  //  لوستل
  // ═════════════════════════════════════════════════════════

  @override
  List<EventMetadata> search(EventQuery q) {
    final (where, args) = _where(q);
    final rows = _db.select(
      'SELECT e.payload, e.folder FROM events e $where '
      'ORDER BY ${_orderBy(q.sort)} LIMIT ? OFFSET ?',
      [...args, q.limit, q.offset],
    );
    return rows.map(_decode).toList();
  }

  @override
  int count(EventQuery q) {
    final (where, args) = _where(q);
    final r = _db.select('SELECT COUNT(*) c FROM events e $where', args);
    return r.isEmpty ? 0 : r.first['c'] as int;
  }

  @override
  EventMetadata? byId(String id) {
    final r = _db.select('SELECT payload, folder FROM events WHERE id = ?', [id]);
    return r.isEmpty ? null : _decode(r.first);
  }

  static EventMetadata _decode(Row r) => EventMetadata.fromJson(
        jsonDecode(r['payload'] as String) as Map<String, dynamic>,
        folderPath: r['folder'] as String,
      );

  /// **ژوندۍ فاسیټ شمېرې** — د Bridge د فلټر پینل زړه.
  ///
  /// هره ډله د خپل ځان پرته حسابیږي (`exclude`)، نو کاروونکی ویني چې
  /// «که دا افشن هم و‌ټاکم، څو پایلې پاتې کیږي» — نه صفر ته رسیږي.
  @override
  FacetCounts facets(EventQuery q) {
    Map<K, int> group<K>(String sql, String excludeGroup, K Function(String) key,
        {List<Object?> extra = const []}) {
      final (where, args) = _where(q, exclude: excludeGroup);
      final rows = _db.select(sql.replaceFirst('{WHERE}', where), [...args, ...extra]);
      final m = <K, int>{};
      for (final r in rows) {
        final v = r.values.first;
        if (v == null) continue;
        m[key('$v')] = r.values[1] as int;
      }
      return m;
    }

    final total = count(q);

    final ratings = group<int>(
        'SELECT e.rating, COUNT(*) FROM events e {WHERE} GROUP BY e.rating',
        'rating', int.parse);

    final colors = group<ColorTag>(
        'SELECT e.color_tag, COUNT(*) FROM events e {WHERE} GROUP BY e.color_tag',
        'color', ColorTag.fromName);

    final categories = group<String>(
        'SELECT e.category, COUNT(*) FROM events e {WHERE} '
        'GROUP BY e.category ORDER BY 2 DESC',
        'category', (s) => s)
      ..removeWhere((k, _) => k.trim().isEmpty);

    final keywords = group<String>(
        'SELECT k.term, COUNT(*) FROM events e '
        'JOIN event_keywords k ON k.event_id = e.id {WHERE} '
        'GROUP BY k.term ORDER BY 2 DESC LIMIT 200',
        'keyword', (s) => s);

    final persons = group<String>(
        'SELECT p.term, COUNT(*) FROM events e '
        'JOIN event_persons p ON p.event_id = e.id {WHERE} '
        'GROUP BY p.term ORDER BY 2 DESC LIMIT 200',
        'person', (s) => s);

    final media = group<MediaKind>(
        'SELECT m.term, COUNT(*) FROM events e '
        'JOIN event_media m ON m.event_id = e.id {WHERE} GROUP BY m.term',
        'media',
        (s) => MediaKind.values.firstWhere((k) => k.name == s,
            orElse: () => MediaKind.other));

    final years = group<int>(
        'SELECT e.shamsi_y, COUNT(*) FROM events e {WHERE} '
        'GROUP BY e.shamsi_y ORDER BY 1 DESC',
        'date', int.parse);

    return FacetCounts(
      total: total,
      ratings: ratings,
      colors: colors,
      categories: categories,
      keywords: keywords,
      persons: persons,
      mediaKinds: media,
      years: years,
    );
  }

  // ═════════════════════════════════════════════════════════
  //  لنډیز
  // ═════════════════════════════════════════════════════════

  @override
  ArchiveStats stats() {
    final head = _db.select(
        'SELECT COUNT(*) c, COALESCE(SUM(file_count),0) f, '
        'COALESCE(SUM(total_bytes),0) b FROM events');
    final h = head.first;

    Map<String, int> countBy(String sql) {
      final m = <String, int>{};
      for (final r in _db.select(sql)) {
        final v = r.values.first;
        if (v != null) m['$v'] = r.values[1] as int;
      }
      return m;
    }

    final media = countBy(
        'SELECT term, COUNT(*) FROM event_media GROUP BY term');
    final ratings = countBy(
        'SELECT rating, COUNT(*) FROM events GROUP BY rating');

    int vocabCount(String kind) {
      final r = _db.select('SELECT COUNT(*) c FROM vocab WHERE kind = ?', [kind]);
      return r.first['c'] as int;
    }

    // د تېرو ۷ ورځو فعالیت — د ثبت وخت له مخې.
    final today = TriDate.now().jdn;
    final weekly = <int>[];
    for (var i = 6; i >= 0; i--) {
      final day = today - i;
      final r = _db.select(
          'SELECT COUNT(*) c FROM events WHERE jdn = ?', [day]);
      weekly.add(r.first['c'] as int);
    }

    final recent = _db
        .select('SELECT payload, folder FROM events ORDER BY updated_at DESC LIMIT 6')
        .map(_decode)
        .toList();

    return ArchiveStats(
      eventCount: h['c'] as int,
      attachmentCount: h['f'] as int,
      totalBytes: h['b'] as int,
      keywordCount: vocabCount('keyword'),
      personCount: vocabCount('person'),
      categoryCount: vocabCount('category'),
      mediaBreakdown: {
        for (final e in media.entries)
          MediaKind.values.firstWhere((k) => k.name == e.key,
              orElse: () => MediaKind.other): e.value
      },
      ratingSpread: {
        for (final e in ratings.entries) int.parse(e.key): e.value
      },
      weeklyActivity: weekly,
      recentEvents: recent,
    );
  }

  // ═════════════════════════════════════════════════════════
  //  لغتونه
  // ═════════════════════════════════════════════════════════

  @override
  List<VocabTerm> vocab(VocabKind kind) {
    final usage = switch (kind) {
      VocabKind.keyword =>
        'SELECT term, COUNT(*) c FROM event_keywords GROUP BY term',
      VocabKind.person =>
        'SELECT term, COUNT(*) c FROM event_persons GROUP BY term',
      VocabKind.category =>
        "SELECT category term, COUNT(*) c FROM events WHERE category <> '' GROUP BY category",
    };
    final counts = <String, int>{};
    for (final r in _db.select(usage)) {
      counts['${r['term']}'] = r['c'] as int;
    }

    final rows = _db.select(
        'SELECT name, color_tag, note FROM vocab WHERE kind = ? ORDER BY name',
        [_vocabKey(kind)]);

    return rows
        .map((r) => VocabTerm(
              name: r['name'] as String,
              colorTag: ColorTag.fromName(r['color_tag'] as String?),
              note: r['note'] as String? ?? '',
              usageCount: counts[r['name'] as String] ?? 0,
            ))
        .toList();
  }

  static String _vocabKey(VocabKind k) => switch (k) {
        VocabKind.keyword => 'keyword',
        VocabKind.person => 'person',
        VocabKind.category => 'category',
      };

  @override
  void addVocab(VocabKind kind, VocabTerm t) => _db.execute(
        'INSERT INTO vocab (kind,name,color_tag,note) VALUES (?,?,?,?) '
        'ON CONFLICT(kind,name) DO UPDATE SET color_tag=excluded.color_tag, '
        'note=excluded.note',
        [_vocabKey(kind), t.name, t.colorTag.name, t.note],
      );

  @override
  void deleteVocabRow(VocabKind kind, String name) => _db
      .execute('DELETE FROM vocab WHERE kind = ? AND name = ?',
          [_vocabKey(kind), name]);

  /// هغه پیښې راګرځوي چې دا لغت کاروي — د بیا لیکلو لپاره.
  @override
  List<EventMetadata> eventsUsing(VocabKind kind, String name) {
    final sql = switch (kind) {
      VocabKind.keyword =>
        'SELECT e.payload, e.folder FROM events e JOIN event_keywords k '
            'ON k.event_id = e.id WHERE k.term = ?',
      VocabKind.person =>
        'SELECT e.payload, e.folder FROM events e JOIN event_persons p '
            'ON p.event_id = e.id WHERE p.term = ?',
      VocabKind.category =>
        'SELECT e.payload, e.folder FROM events e WHERE e.category = ?',
    };
    return _db.select(sql, [name]).map(_decode).toList();
  }
}

/// د چټک ډله‌ییز داخلولو لپاره چمتو شوي بیانونه.
class _Stmts {
  _Stmts(Database db)
      : upsert = db.prepare(
          '''INSERT INTO events (id,title,folder,category,summary,rating,color_tag,
               jdn,shamsi_y,shamsi_m,qamari_y,miladi_y,file_count,total_bytes,
               created_at,updated_at,payload)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
             ON CONFLICT(id) DO UPDATE SET
               title=excluded.title, folder=excluded.folder,
               category=excluded.category, summary=excluded.summary,
               rating=excluded.rating, color_tag=excluded.color_tag,
               jdn=excluded.jdn, shamsi_y=excluded.shamsi_y,
               shamsi_m=excluded.shamsi_m, qamari_y=excluded.qamari_y,
               miladi_y=excluded.miladi_y, file_count=excluded.file_count,
               total_bytes=excluded.total_bytes, updated_at=excluded.updated_at,
               payload=excluded.payload'''),
        ftsIns = db.prepare(
            'INSERT INTO events_fts (rowid,title,body) VALUES (?,?,?)'),
        ftsDel = db.prepare('DELETE FROM events_fts WHERE rowid = ?'),
        ridSel = db.prepare('SELECT rowid FROM events WHERE id = ?'),
        kwIns = db.prepare('INSERT OR IGNORE INTO event_keywords VALUES (?,?)'),
        psIns = db.prepare('INSERT OR IGNORE INTO event_persons VALUES (?,?)'),
        mdIns = db.prepare('INSERT OR IGNORE INTO event_media VALUES (?,?)'),
        kwDel = db.prepare('DELETE FROM event_keywords WHERE event_id = ?'),
        psDel = db.prepare('DELETE FROM event_persons WHERE event_id = ?'),
        mdDel = db.prepare('DELETE FROM event_media WHERE event_id = ?'),
        vocabIns = db.prepare(
            'INSERT OR IGNORE INTO vocab (kind,name) VALUES (?,?)');

  final PreparedStatement upsert, ftsIns, ftsDel, ridSel;
  final PreparedStatement kwIns, psIns, mdIns;
  final PreparedStatement kwDel, psDel, mdDel;
  final PreparedStatement vocabIns;

  void dispose() {
    for (final s in [upsert, ftsIns, ftsDel, ridSel, kwIns, psIns, mdIns,
                     kwDel, psDel, mdDel, vocabIns]) {
      s.close();
    }
  }
}
