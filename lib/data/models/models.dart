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

/// **د آرشیف حقیقت.** هره پیښه یو داسې فایل خپل فولډر کې لري.
///
/// دا فایل عمداً کوچنی او سپک دی: د پیښې ټول کوډ په `index.html` کې دی،
/// خو لټون یوازې دلته کیږي — نو زرګونه پیښې هم په میلي‌ثانیو کې فلټریږي.
class EventMetadata {
  EventMetadata({
    required this.id,
    required this.title,
    required this.folderPath,
    required this.date,
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
    this.schemaVersion = 1,
  })  : keywords = keywords ?? [],
        persons = persons ?? [],
        links = links ?? [],
        blocks = blocks ?? [],
        attachments = attachments ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// ثابت پېژندګلوی — د فولډر د نوم له بدلون سره هم نه بدلیږي.
  final String id;

  String title;

  /// د پیښې فولډر بشپړ مسیر.
  String folderPath;

  /// د پیښې تاریخ — درې واړه تقویمونه + JDN.
  TriDate date;

  String category;
  String summary;

  /// ۰..۵ ستوري.
  int rating;

  ColorTag colorTag;

  final List<String> keywords;
  final List<String> persons;
  final List<String> links;
  final List<Block> blocks;
  final List<Attachment> attachments;

  final DateTime createdAt;
  DateTime updatedAt;
  final int schemaVersion;

  int get attachmentCount => attachments.length;
  int get totalBytes => attachments.fold(0, (a, b) => a + b.sizeBytes);

  Map<MediaKind, int> get mediaBreakdown {
    final m = <MediaKind, int>{};
    for (final a in attachments) {
      m[a.kind] = (m[a.kind] ?? 0) + 1;
    }
    return m;
  }

  /// هغه ټول متن چې FTS5 ایندکس کوي.
  String get searchBlob => [
        title,
        summary,
        category,
        ...keywords,
        ...persons,
        ...blocks.map((b) => b.searchText),
        ...attachments.map((a) => a.name),
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
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'title': title,
        'category': category,
        'summary': summary,
        'date': date.toJson(),
        'rating': rating,
        'colorTag': colorTag.name,
        'keywords': keywords,
        'persons': persons,
        'links': links,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static EventMetadata fromJson(Map<String, dynamic> j, {String folderPath = ''}) =>
      EventMetadata(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        folderPath: folderPath,
        date: j['date'] is Map
            ? TriDate.fromJson(Map<String, dynamic>.from(j['date'] as Map))
            : TriDate.now(),
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
                ?.map((e) => Attachment.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
        schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
      );
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
