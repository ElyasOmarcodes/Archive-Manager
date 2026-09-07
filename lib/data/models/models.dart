import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';

// ═══════════════════════════════════════════════════════════
//  د ویجټ بلاکونه — د index.html د جوړولو بنسټ
// ═══════════════════════════════════════════════════════════

/// هغه ویجټونه چې د پیښې پاڼې کې ډراګ او ډراپ کیږي.
enum BlockKind {
  heading('عنوان', 'title'),
  paragraph('ساده متن', 'notes'),
  quote('نقل قول', 'format_quote'),
  image('تصویر', 'image'),
  video('ویډیو', 'movie'),
  audio('صوتي', 'graphic_eq'),
  file('نور فایلونه', 'attach_file'),
  divider('د فاصلې کرښه', 'horizontal_rule');

  const BlockKind(this.label, this.icon);
  final String label;
  final String icon;

  bool get needsFile =>
      this == image || this == video || this == audio || this == file;

  static BlockKind fromName(String n) =>
      BlockKind.values.firstWhere((e) => e.name == n, orElse: () => paragraph);
}

/// د پاڼې یو بلاک.
class Block {
  Block({
    required this.id,
    required this.kind,
    this.text = '',
    this.caption = '',
    this.source = '',
    this.author = '',
    this.level = 2,
    this.align = 'center',
  });

  final String id;
  BlockKind kind;

  /// د عنوان/پاراګراف/نقل‌قول متن.
  String text;

  /// د فایل لاندې لیکل شوی وضاحت.
  String caption;

  /// د فایل نسبي مسیر: `attachments/doc_video_01.mp4`
  String source;

  /// د نقل‌قول ویونکی.
  String author;

  /// د عنوان کچه ۱..۴
  int level;

  /// `center` | `right` | `left`
  String align;

  Block copy() => Block(
        id: id,
        kind: kind,
        text: text,
        caption: caption,
        source: source,
        author: author,
        level: level,
        align: align,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        if (text.isNotEmpty) 'text': text,
        if (caption.isNotEmpty) 'caption': caption,
        if (source.isNotEmpty) 'source': source,
        if (author.isNotEmpty) 'author': author,
        if (kind == BlockKind.heading) 'level': level,
        'align': align,
      };

  static Block fromJson(Map<String, dynamic> j) => Block(
        id: j['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        kind: BlockKind.fromName(j['kind'] as String? ?? 'paragraph'),
        text: j['text'] as String? ?? '',
        caption: j['caption'] as String? ?? '',
        source: j['source'] as String? ?? '',
        author: j['author'] as String? ?? '',
        level: (j['level'] as num?)?.toInt() ?? 2,
        align: j['align'] as String? ?? 'center',
      );

  /// هغه متن چې د بشپړ متن لټون (FTS5) ته ورکول کیږي.
  String get searchText => [text, caption, author].where((s) => s.isNotEmpty).join(' ');
}

// ═══════════════════════════════════════════════════════════
//  ضمیمې
// ═══════════════════════════════════════════════════════════

/// د فایل پراخې کټګورۍ — د فلټر او ډاشبورډ لپاره.
enum MediaKind {
  image('انځور', ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tif', 'tiff', 'heic', 'avif']),
  video('ویډیو', ['mp4', 'mkv', 'mov', 'avi', 'webm', 'wmv', 'flv', 'm4v', 'mpg', 'mpeg']),
  audio('غږ', ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'wma', 'opus']),
  document('سند', ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'md']),
  sheet('جدول', ['xls', 'xlsx', 'csv', 'ods']),
  archive('کمپرس', ['zip', 'rar', '7z', 'tar', 'gz', 'xz']),
  other('نور', []);

  const MediaKind(this.label, this.extensions);
  final String label;
  final List<String> extensions;

  static MediaKind ofPath(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0) return other;
    final ext = path.substring(i + 1).toLowerCase();
    for (final k in MediaKind.values) {
      if (k.extensions.contains(ext)) return k;
    }
    return other;
  }
}

/// یوه ضمیمه چې د `attachments/` فولډر دننه پرته ده.
class Attachment {
  const Attachment({
    required this.name,
    required this.relativePath,
    required this.kind,
    this.sizeBytes = 0,
  });

  final String name;
  final String relativePath;
  final MediaKind kind;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': relativePath,
        'kind': kind.name,
        'size': sizeBytes,
      };

  static Attachment fromJson(Map<String, dynamic> j) => Attachment(
        name: j['name'] as String? ?? '',
        relativePath: j['path'] as String? ?? '',
        kind: MediaKind.values.firstWhere(
            (e) => e.name == (j['kind'] as String? ?? ''),
            orElse: () => MediaKind.other),
        sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
      );
}

// ═══════════════════════════════════════════════════════════
//  د پیښې میټاډیټا — د `metadata.json` بشپړ سکیما
// ═══════════════════════════════════════════════════════════

/// **د پیښې میټاډیټا — د آرشیف حقیقت.**
///
/// ## ولې دوه فایله؟
///
/// یوه ریښتینې پیښه لسګونه بلاکونه لري (عنوانونه، پاراګرافونه، نقل
/// قولونه، د فایلونو مسیرونه) — هغه یو اوږد کوډ جوړوي. خو د **فلټر**
/// پر مهال مونږ له هغو څخه یو هم نه کاروو.
///
/// نو ډیټا په دوو فایلونو ویشل شوې:
///
/// ```
/// 📁 د کابل او چین تړون/
/// ├── metadata.json   ← یوازې هغه څه چې فلټر یې کاروي  (~۴۰۰ بایټه)
/// ├── content.json    ← بلاکونه او ضمیمې              (څومره چې وي)
/// ├── index.html
/// └── attachments/
/// ```
///
/// * **`metadata.json`** د سکن پر مهال لوستل کیږي — د هرې پیښې لپاره.
///   نو څومره چې کوچنی وي، هومره سکن او لټون چټک دی.
/// * **`content.json`** یوازې هغه وخت لوستل کیږي چې کاروونکی پیښه
///   پرانیزي — یعنې یو ځل، نه د زرګونو پیښو لپاره.
///
/// د دې لپاره چې فلټر لا هم د بلاکونو متن ولټوي، د بلاکونو متن یو ځل
/// د ثبت پر مهال په `contentText` کې څنډل کیږي — نو بشپړ متن لټون
/// پرته له دې چې بلاکونه ولوستل شي کار کوي.
class EventMetadata {
  EventMetadata({
    required this.id,
    required this.title,
    required this.folderPath,
    required TriDate date,
    this.category = '',
    this.summary = '',
    this.rating = 0,
    this.colorTag = ColorTag.none,
    List<String>? keywords,
    List<String>? persons,
    List<String>? links,
    List<Block>? blocks,
    List<Attachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.schemaVersion = currentSchema,
    // ── لنډیز: کله چې محتوا نه وي لوستل شوې، له دې ګټه اخلو ──
    Map<MediaKind, int>? mediaCounts,
    int? fileCount,
    int? totalBytes,
    String? contentText,
    bool? contentLoaded,
  })  : _jdn = date.jdn,
        _date = date,
        keywords = keywords ?? [],
        persons = persons ?? [],
        links = links ?? [],
        blocks = blocks ?? [],
        attachments = attachments ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        // که محتوا راکړل شوې وي، لنډیز له هغې جوړوو؛ که نه، هغه
        // لنډیز کاروو چې له `metadata.json` څخه راغلی.
        _mediaCounts = mediaCounts ?? _countMedia(attachments ?? const []),
        _fileCount = fileCount ?? (attachments?.length ?? 0),
        _totalBytes = totalBytes ??
            (attachments ?? const <Attachment>[])
                .fold(0, (a, b) => a + b.sizeBytes),
        _contentText = contentText ?? _flatten(blocks, attachments),
        contentLoaded =
            contentLoaded ?? (blocks != null || attachments != null);

  /// اوسنۍ سکیما. ۱ = زوړ (یو فایل)، ۲ = نوی (دوه فایله).
  static const int currentSchema = 2;

  /// ثابت پېژندګلوی — د فولډر د نوم له بدلون سره هم نه بدلیږي.
  final String id;

  String title;

  /// د پیښې فولډر بشپړ مسیر.
  String folderPath;

  // ── نېټه: یوازې `jdn` ساتل کیږي ──────────────────────
  //
  // درې واړه تقویمونه له `jdn` څخه محاسبه کیږي، نو په فایل کې یې
  // ساتل بې‌ګټې تکرار و. محاسبه یې ~۲۳µs ده، نو یوازې هغه وخت یې
  // کوو چې ښکاره شي — نه د هرې پیښې د لوستلو پر مهال.
  int _jdn;
  TriDate? _date;

  int get jdn => _jdn;

  TriDate get date => _date ??= TriDate.fromJdn(_jdn);

  set date(TriDate d) {
    _jdn = d.jdn;
    _date = d;
  }

  String category;
  String summary;

  /// ۰..۵ ستوري.
  int rating;

  ColorTag colorTag;

  final List<String> keywords;
  final List<String> persons;

  final DateTime createdAt;
  DateTime updatedAt;
  final int schemaVersion;

  // ── محتوا: یوازې د اړتیا پر مهال لوستل کیږي ──────────
  final List<Block> blocks;
  final List<Attachment> attachments;
  final List<String> links;

  /// آیا `content.json` لوستل شوی؟
  ///
  /// که `false` وي، `blocks` او `attachments` تش دي — خو `fileCount`،
  /// `totalBytes` او `mediaBreakdown` بیا هم سم دي، ځکه هغه په
  /// `metadata.json` کې لنډیز شوي دي.
  bool contentLoaded;

  // ── لنډیز ────────────────────────────────────────────
  Map<MediaKind, int> _mediaCounts;
  int _fileCount;
  int _totalBytes;
  String _contentText;

  int get attachmentCount => _fileCount;
  int get totalBytes => _totalBytes;
  Map<MediaKind, int> get mediaBreakdown => _mediaCounts;

  /// د بلاکونو څنډل شوی متن — د بشپړ متن لټون لپاره.
  String get contentText => _contentText;

  /// محتوا ورګډوي (له `content.json` څخه) او لنډیز بیا حسابوي.
  void applyContent(Map<String, dynamic> j) {
    blocks
      ..clear()
      ..addAll((j['blocks'] as List? ?? [])
          .map((e) => Block.fromJson(Map<String, dynamic>.from(e as Map))));
    attachments
      ..clear()
      ..addAll((j['attachments'] as List? ?? [])
          .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e as Map))));
    links
      ..clear()
      ..addAll((j['links'] as List? ?? []).map((e) => '$e'));
    contentLoaded = true;
    _recount();
  }

  /// د ثبت دمخه لنډیز له اوسنۍ محتوا څخه بیا جوړوي.
  void _recount() {
    _mediaCounts = _countMedia(attachments);
    _fileCount = attachments.length;
    _totalBytes = attachments.fold(0, (a, b) => a + b.sizeBytes);
    _contentText = _flatten(blocks, attachments);
  }

  static Map<MediaKind, int> _countMedia(List<Attachment> atts) {
    final m = <MediaKind, int>{};
    for (final a in atts) {
      m[a.kind] = (m[a.kind] ?? 0) + 1;
    }
    return m;
  }

  /// د بلاکونو او د فایلونو نومونه یوې کرښې ته — د لټون لپاره.
  static String _flatten(List<Block>? blocks, List<Attachment>? atts) => [
        ...?blocks?.map((b) => b.searchText),
        ...?atts?.map((a) => a.name),
      ].where((s) => s.trim().isNotEmpty).join(' \n ');

  /// هغه ټول متن چې FTS5 ایندکس کوي.
  ///
  /// د نېټو متن هم پکې دی — نو «سنبله ۱۴۰۵» یا «ربیع‌الاول» لټول
  /// کیدی شي. دا یوازې د ایندکس پر مهال حسابیږي، نه د لوستلو.
  String get searchBlob => [
        title,
        summary,
        category,
        ...keywords,
        ...persons,
        _contentText,
        date.shamsiText,
        date.qamariText,
        date.miladiText,
      ].where((s) => s.trim().isNotEmpty).join(' \n ');

  EventMetadata copyWith({
    String? title,
    String? folderPath,
    TriDate? date,
    String? category,
    String? summary,
    int? rating,
    ColorTag? colorTag,
    List<String>? keywords,
    List<String>? persons,
    List<String>? links,
    List<Block>? blocks,
    List<Attachment>? attachments,
  }) =>
      EventMetadata(
        id: id,
        title: title ?? this.title,
        folderPath: folderPath ?? this.folderPath,
        date: date ?? this.date,
        category: category ?? this.category,
        summary: summary ?? this.summary,
        rating: rating ?? this.rating,
        colorTag: colorTag ?? this.colorTag,
        keywords: keywords ?? List.of(this.keywords),
        persons: persons ?? List.of(this.persons),
        links: links ?? List.of(this.links),
        blocks: blocks ?? this.blocks.map((b) => b.copy()).toList(),
        attachments: attachments ?? List.of(this.attachments),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        schemaVersion: schemaVersion,
        mediaCounts: Map.of(_mediaCounts),
        fileCount: _fileCount,
        totalBytes: _totalBytes,
        contentText: _contentText,
        contentLoaded: contentLoaded,
      );

  // ═══════════════════════════════════════════════════════
  //  JSON
  // ═══════════════════════════════════════════════════════

  /// **`metadata.json`** — یوازې هغه څه چې فلټر یې کاروي.
  ///
  /// د نېټې درې واړه بڼې دلته نشته: `jdn` بس دی، پاتې یې محاسبه کیږي.
  Map<String, dynamic> toJson() {
    if (contentLoaded) _recount();
    return {
      'v': currentSchema,
      'id': id,
      'title': title,
      if (category.isNotEmpty) 'category': category,
      if (summary.isNotEmpty) 'summary': summary,
      'jdn': _jdn,
      if (rating != 0) 'rating': rating,
      if (colorTag != ColorTag.none) 'color': colorTag.name,
      if (keywords.isNotEmpty) 'keywords': keywords,
      if (persons.isNotEmpty) 'persons': persons,
      if (_fileCount > 0) 'files': _fileCount,
      if (_totalBytes > 0) 'bytes': _totalBytes,
      if (_mediaCounts.isNotEmpty)
        'media': {for (final e in _mediaCounts.entries) e.key.name: e.value},
      if (_contentText.isNotEmpty) 'text': _contentText,
      'created': createdAt.millisecondsSinceEpoch,
      'updated': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// **`content.json`** — د پاڼې محتوا. یوازې د پرانیستلو پر مهال.
  Map<String, dynamic> toContentJson() => {
        'v': currentSchema,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        if (links.isNotEmpty) 'links': links,
      };

  /// له `metadata.json` څخه لوستل — نوې (v2) او زړه (v1) دواړه بڼې.
  static EventMetadata fromJson(Map<String, dynamic> j,
      {String folderPath = ''}) {
    final v = (j['v'] ?? j['schemaVersion'] ?? 1) as int;
    return v >= 2 ? _fromV2(j, folderPath) : _fromV1(j, folderPath);
  }

  static EventMetadata _fromV2(Map<String, dynamic> j, String folder) {
    final media = <MediaKind, int>{};
    final mediaJson = j['media'] as Map?;
    if (mediaJson != null) {
      for (final e in mediaJson.entries) {
        final k = MediaKind.values.firstWhere((x) => x.name == '${e.key}',
            orElse: () => MediaKind.other);
        media[k] = (e.value as num).toInt();
      }
    }
    return EventMetadata(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      folderPath: folder,
      date: TriDate.fromJdn((j['jdn'] as num?)?.toInt() ?? TriDate.now().jdn),
      category: j['category'] as String? ?? '',
      summary: j['summary'] as String? ?? '',
      rating: (j['rating'] as num?)?.toInt() ?? 0,
      colorTag: ColorTag.fromName(j['color'] as String?),
      keywords: (j['keywords'] as List?)?.map((e) => '$e').toList() ?? [],
      persons: (j['persons'] as List?)?.map((e) => '$e').toList() ?? [],
      createdAt: _epoch(j['created']),
      updatedAt: _epoch(j['updated']),
      mediaCounts: media,
      fileCount: (j['files'] as num?)?.toInt() ?? 0,
      totalBytes: (j['bytes'] as num?)?.toInt() ?? 0,
      contentText: j['text'] as String? ?? '',
      contentLoaded: false,
    );
  }

  /// **زړه بڼه** — هغه فایلونه چې بلاکونه یې دننه لري.
  ///
  /// د پروګرام زړې نسخې دا بڼه لیکله. لا هم یې لولو، نو هیڅوک خپله
  /// ډیټا نه بایلي؛ لومړی ځل چې پیښه بیا ثبت شي، پخپله نوې بڼې ته
  /// اوړي.
  static EventMetadata _fromV1(Map<String, dynamic> j, String folder) {
    final dateJson = j['date'];
    final date = dateJson is Map
        ? TriDate.fromJson(Map<String, dynamic>.from(dateJson))
        : TriDate.now();
    return EventMetadata(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      folderPath: folder,
      date: date,
      category: j['category'] as String? ?? '',
      summary: j['summary'] as String? ?? '',
      rating: (j['rating'] as num?)?.toInt() ?? 0,
      colorTag: ColorTag.fromName(j['colorTag'] as String?),
      keywords: (j['keywords'] as List?)?.map((e) => '$e').toList() ?? [],
      persons: (j['persons'] as List?)?.map((e) => '$e').toList() ?? [],
      links: (j['links'] as List?)?.map((e) => '$e').toList() ?? [],
      blocks: (j['blocks'] as List?)
              ?.map((e) => Block.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      attachments: (j['attachments'] as List?)
              ?.map((e) =>
                  Attachment.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      schemaVersion: 1,
      contentLoaded: true,
    );
  }

  static DateTime? _epoch(Object? v) => v is num
      ? DateTime.fromMillisecondsSinceEpoch(v.toInt())
      : (v is String ? DateTime.tryParse(v) : null);
}

// ═══════════════════════════════════════════════════════════
//  د لغتونو (vocabulary) توکي
// ═══════════════════════════════════════════════════════════

/// یو کیورډ / شخصیت / کټګوري — د مدیریت پاڼو لپاره.
class VocabTerm {
  VocabTerm({
    required this.name,
    this.usageCount = 0,
    this.colorTag = ColorTag.none,
    this.note = '',
  });

  String name;
  int usageCount;
  ColorTag colorTag;
  String note;

  Map<String, dynamic> toJson() => {
        'name': name,
        'colorTag': colorTag.name,
        if (note.isNotEmpty) 'note': note,
      };

  static VocabTerm fromJson(Map<String, dynamic> j) => VocabTerm(
        name: j['name'] as String? ?? '',
        colorTag: ColorTag.fromName(j['colorTag'] as String?),
        note: j['note'] as String? ?? '',
      );
}

/// د لغتونو کوم ډول.
enum VocabKind {
  keyword('کیورډونه', 'کیورډ'),
  person('شخصیتونه', 'شخصیت'),
  category('کټګورۍ', 'کټګوري');

  const VocabKind(this.plural, this.singular);
  final String plural;
  final String singular;
}
