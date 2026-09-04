import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import 'models.dart';

/// د ترتیب معیارونه — د Adobe Bridge د Sort مینو په څېر.
enum SortField {
  dateDesc('تاریخ — نوی تر زوړ'),
  dateAsc('تاریخ — زوړ تر نوي'),
  titleAsc('نوم — الفبا'),
  titleDesc('نوم — برعکس'),
  ratingDesc('درجه — لوړ تر ټیټ'),
  ratingAsc('درجه — ټیټ تر لوړ'),
  createdDesc('د ثبت وخت — نوی'),
  updatedDesc('وروستی بدلون'),
  sizeDesc('اندازه — لوی تر کوچني'),
  filesDesc('د فایلونو شمېر');

  const SortField(this.label);
  final String label;
}

/// **د لټون بشپړه پوښتنه.**
///
/// د ډلو تر منځ **AND**، د یوې ډلې دننه **OR** — دقیقاً د Adobe Bridge
/// د Filter Panel چلند.
class EventQuery {
  const EventQuery({
    this.text = '',
    this.ratings = const {},
    this.colors = const {},
    this.categories = const {},
    this.keywords = const {},
    this.persons = const {},
    this.mediaKinds = const {},
    this.dateKind = CalendarKind.shamsi,
    this.fromJdn,
    this.toJdn,
    this.folderPrefix,
    this.sort = SortField.dateDesc,
    this.limit = 500,
    this.offset = 0,
  });

  /// د بشپړ متن لټون — FTS5 ته ورکول کیږي.
  final String text;

  /// ۰..۵ — تشه ډله یعنې «هر څه».
  final Set<int> ratings;
  final Set<ColorTag> colors;
  final Set<String> categories;
  final Set<String> keywords;
  final Set<String> persons;
  final Set<MediaKind> mediaKinds;

  /// کوم تقویم چې د نېټې د سلسلې لپاره ښکاره شوی و (یوازې د UI لپاره).
  final CalendarKind dateKind;

  /// د نېټې سلسله — تل د JDN په بڼه، نو هر تقویم یو شان چټک دی.
  final int? fromJdn;
  final int? toJdn;

  /// یوازې د یوه فولډر دننه لټون.
  final String? folderPrefix;

  final SortField sort;
  final int limit;
  final int offset;

  bool get hasAnyFilter =>
      text.trim().isNotEmpty ||
      ratings.isNotEmpty ||
      colors.isNotEmpty ||
      categories.isNotEmpty ||
      keywords.isNotEmpty ||
      persons.isNotEmpty ||
      mediaKinds.isNotEmpty ||
      fromJdn != null ||
      toJdn != null ||
      folderPrefix != null;

  int get activeFilterCount =>
      (text.trim().isEmpty ? 0 : 1) +
      (ratings.isEmpty ? 0 : 1) +
      (colors.isEmpty ? 0 : 1) +
      (categories.isEmpty ? 0 : 1) +
      (keywords.isEmpty ? 0 : 1) +
      (persons.isEmpty ? 0 : 1) +
      (mediaKinds.isEmpty ? 0 : 1) +
      ((fromJdn != null || toJdn != null) ? 1 : 0);

  EventQuery copyWith({
    String? text,
    Set<int>? ratings,
    Set<ColorTag>? colors,
    Set<String>? categories,
    Set<String>? keywords,
    Set<String>? persons,
    Set<MediaKind>? mediaKinds,
    CalendarKind? dateKind,
    Object? fromJdn = _sentinel,
    Object? toJdn = _sentinel,
    Object? folderPrefix = _sentinel,
    SortField? sort,
    int? limit,
    int? offset,
  }) =>
      EventQuery(
        text: text ?? this.text,
        ratings: ratings ?? this.ratings,
        colors: colors ?? this.colors,
        categories: categories ?? this.categories,
        keywords: keywords ?? this.keywords,
        persons: persons ?? this.persons,
        mediaKinds: mediaKinds ?? this.mediaKinds,
        dateKind: dateKind ?? this.dateKind,
        fromJdn: fromJdn == _sentinel ? this.fromJdn : fromJdn as int?,
        toJdn: toJdn == _sentinel ? this.toJdn : toJdn as int?,
        folderPrefix:
            folderPrefix == _sentinel ? this.folderPrefix : folderPrefix as String?,
        sort: sort ?? this.sort,
        limit: limit ?? this.limit,
        offset: offset ?? this.offset,
      );

  EventQuery cleared() => EventQuery(sort: sort, dateKind: dateKind);

  static const _sentinel = Object();
}

/// د فلټر پینل لپاره ژوندۍ شمېرې — د Bridge په څېر هر افشن تر څنګ یې شمېره.
class FacetCounts {
  const FacetCounts({
    this.total = 0,
    this.ratings = const {},
    this.colors = const {},
    this.categories = const {},
    this.keywords = const {},
    this.persons = const {},
    this.mediaKinds = const {},
    this.years = const {},
  });

  final int total;
  final Map<int, int> ratings;
  final Map<ColorTag, int> colors;
  final Map<String, int> categories;
  final Map<String, int> keywords;
  final Map<String, int> persons;
  final Map<MediaKind, int> mediaKinds;

  /// د شمسي کال له مخې ویش — د تاریخي وخت‌کرښې لپاره.
  final Map<int, int> years;

  static const empty = FacetCounts();
}

/// یو ساتل شوی لټون — د Bridge د Smart Collection معادل.
class SavedSearch {
  SavedSearch({required this.name, required this.query, this.icon = 'bookmark'});
  final String name;
  final EventQuery query;
  final String icon;
}
