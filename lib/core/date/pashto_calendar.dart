import 'package:hijri/hijri_calendar.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// کوم تقویم چې کاروونکي ته ښکاري.
enum CalendarKind {
  shamsi('هجري لمریز'),
  qamari('هجري قمري'),
  miladi('میلادي');

  const CalendarKind(this.label);
  final String label;
}

/// د پښتو میاشتو نومونه — د افغانستان رسمي تقویم.
class PashtoMonths {
  PashtoMonths._();

  /// هجري لمریز (شمسي) — د افغانستان رسمي نومونه.
  static const List<String> shamsi = [
    'وری', 'غویی', 'غبرګولی', 'چنګاښ', 'زمری', 'وږی',
    'تله', 'لړم', 'لیندۍ', 'مرغومی', 'سلواغه', 'کب',
  ];

  /// د دري/ایراني معادل — ځینې کاروونکي دې نومونو ته عادت لري.
  static const List<String> shamsiDari = [
    'حمل', 'ثور', 'جوزا', 'سرطان', 'اسد', 'سنبله',
    'میزان', 'عقرب', 'قوس', 'جدي', 'دلو', 'حوت',
  ];

  /// هجري قمري.
  static const List<String> qamari = [
    'محرم', 'صفر', 'ربیع‌الاول', 'ربیع‌الثاني', 'جمادی‌الاول', 'جمادی‌الثاني',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذي‌القعده', 'ذي‌الحجه',
  ];

  /// میلادي.
  static const List<String> miladi = [
    'جنوري', 'فبروري', 'مارچ', 'اپریل', 'می', 'جون',
    'جولای', 'اګست', 'سپتمبر', 'اکتوبر', 'نومبر', 'ډسمبر',
  ];

  /// د اونۍ ورځې — د شنبې څخه پیل (د شمسي تقویم ترتیب).
  static const List<String> weekDays = [
    'شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه',
  ];

  static const List<String> weekDaysShort = [
    'ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج',
  ];
}

/// پښتو/فارسي عددونه.
class PashtoDigits {
  PashtoDigits._();
  static const _eastern = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  /// لاتیني عددونه پښتو ته اړوي: `1405` → `۱۴۰۵`
  static String to(Object input) {
    final s = input.toString();
    final b = StringBuffer();
    for (final ch in s.codeUnits) {
      if (ch >= 0x30 && ch <= 0x39) {
        b.write(_eastern[ch - 0x30]);
      } else {
        b.writeCharCode(ch);
      }
    }
    return b.toString();
  }

  /// پښتو عددونه بېرته لاتیني ته — د ان‌پټ د پارس کولو لپاره.
  static String from(String s) {
    final b = StringBuffer();
    for (final ch in s.runes) {
      if (ch >= 0x06F0 && ch <= 0x06F9) {
        b.write(ch - 0x06F0); // فارسي
      } else if (ch >= 0x0660 && ch <= 0x0669) {
        b.write(ch - 0x0660); // عربي
      } else {
        b.writeCharCode(ch);
      }
    }
    return b.toString();
  }
}

/// یو ساده درې‌برخیز تاریخ (کال/میاشت/ورځ) په یوه ټاکلي تقویم کې.
class CalDate {
  const CalDate(this.year, this.month, this.day);
  final int year, month, day;

  Map<String, dynamic> toJson() => {'y': year, 'm': month, 'd': day};
  static CalDate fromJson(Map<String, dynamic> j) =>
      CalDate(j['y'] as int, j['m'] as int, j['d'] as int);

  @override
  String toString() => '$year-$month-$day';

  @override
  bool operator ==(Object other) =>
      other is CalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// **د پروګرام د تاریخ زړه.**
///
/// یو ځل تاریخ ورکړئ — درې واړه تقویمونه او یو **Julian Day Number** ترلاسه کړئ.
/// د JDN له امله د هر تقویم د «له… تر…» پلټنه یوازې یو عددي پرتله ده،
/// نو د میلیونونو ریکارډونو فلټر هم په میلي‌ثانیو کې ترسره کیږي.
class TriDate {
  TriDate._(this.jdn, this.gregorian, this.shamsi, this.qamari);

  /// Julian Day Number — د ټولو تقویمونو ګډ، ایندکس شوی بنسټ.
  final int jdn;
  final CalDate gregorian;
  final CalDate shamsi;
  final CalDate qamari;

  // ── جوړونکي ────────────────────────────────────────────

  static TriDate fromDateTime(DateTime dt) => fromGregorian(dt.year, dt.month, dt.day);

  static TriDate now() => fromDateTime(DateTime.now());

  static TriDate fromGregorian(int y, int m, int d) {
    final g = Gregorian(y, m, d);
    final j = g.toJalali();
    final hc = HijriCalendar.fromDate(DateTime(y, m, d));
    return TriDate._(
      g.julianDayNumber,
      CalDate(y, m, d),
      CalDate(j.year, j.month, j.day),
      CalDate(hc.hYear, hc.hMonth, hc.hDay),
    );
  }

  static TriDate fromShamsi(int y, int m, int d) {
    final g = Jalali(y, m, d).toGregorian();
    return fromGregorian(g.year, g.month, g.day);
  }

  static TriDate fromQamari(int y, int m, int d) {
    final g = HijriCalendar().hijriToGregorian(y, m, d);
    return fromGregorian(g.year, g.month, g.day);
  }

  static TriDate fromJdn(int jdn) {
    final g = Gregorian.fromJulianDayNumber(jdn);
    return fromGregorian(g.year, g.month, g.day);
  }

  DateTime get dateTime =>
      DateTime(gregorian.year, gregorian.month, gregorian.day);

  /// د اونۍ ورځ، د شنبې څخه ۰..۶ — د شمسي جدول لپاره.
  int get shamsiWeekDay => Jalali(shamsi.year, shamsi.month, shamsi.day).weekDay - 1;

  // ── بڼه ورکول (formatting) ─────────────────────────────

  String get shamsiText =>
      '${PashtoDigits.to(shamsi.day)} ${PashtoMonths.shamsiDari[shamsi.month - 1]} ${PashtoDigits.to(shamsi.year)}';

  String get shamsiTextPashto =>
      '${PashtoDigits.to(shamsi.day)} ${PashtoMonths.shamsi[shamsi.month - 1]} ${PashtoDigits.to(shamsi.year)}';

  String get qamariText =>
      '${PashtoDigits.to(qamari.day)} ${PashtoMonths.qamari[qamari.month - 1]} ${PashtoDigits.to(qamari.year)}';

  String get miladiText =>
      '${PashtoDigits.to(gregorian.day)} ${PashtoMonths.miladi[gregorian.month - 1]} ${PashtoDigits.to(gregorian.year)}';

  /// عددي بڼه: `۱۴۰۵/۰۶/۱۳`
  String get shamsiNumeric => '${PashtoDigits.to(shamsi.year)}/'
      '${PashtoDigits.to(shamsi.month.toString().padLeft(2, '0'))}/'
      '${PashtoDigits.to(shamsi.day.toString().padLeft(2, '0'))}';

  String textFor(CalendarKind k) => switch (k) {
        CalendarKind.shamsi => shamsiText,
        CalendarKind.qamari => qamariText,
        CalendarKind.miladi => miladiText,
      };

  CalDate dateFor(CalendarKind k) => switch (k) {
        CalendarKind.shamsi => shamsi,
        CalendarKind.qamari => qamari,
        CalendarKind.miladi => gregorian,
      };

  static List<String> monthsFor(CalendarKind k) => switch (k) {
        CalendarKind.shamsi => PashtoMonths.shamsiDari,
        CalendarKind.qamari => PashtoMonths.qamari,
        CalendarKind.miladi => PashtoMonths.miladi,
      };

  /// د یوې میاشتې د ورځو شمېر په ټاکلي تقویم کې.
  static int monthLength(CalendarKind k, int y, int m) => switch (k) {
        CalendarKind.shamsi => Jalali(y, m, 1).monthLength,
        CalendarKind.qamari => HijriCalendar().getDaysInMonth(y, m),
        CalendarKind.miladi => Gregorian(y, m, 1).monthLength,
      };

  // ── JSON ───────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'jdn': jdn,
        'shamsi': {...shamsi.toJson(), 'text': shamsiText},
        'qamari': {...qamari.toJson(), 'text': qamariText},
        'miladi': {...gregorian.toJson(), 'text': miladiText},
        'iso': dateTime.toIso8601String().substring(0, 10),
      };

  static TriDate fromJson(Map<String, dynamic> j) {
    if (j['jdn'] is int) return fromJdn(j['jdn'] as int);
    final g = j['miladi'] as Map<String, dynamic>;
    return fromGregorian(g['y'] as int, g['m'] as int, g['d'] as int);
  }

  @override
  String toString() => 'TriDate($shamsiText | $qamariText | $miladiText)';
}
