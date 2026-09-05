import 'package:flutter/material.dart';

/// د پروګرام د ډیزاین بنسټیز ټوکنونه — رنګونه، فاصلې، شعاعونه، حرکتونه.
class AppTokens {
  AppTokens._();

  // ── فاصلې ──────────────────────────────────────────────
  static const double s2 = 2, s4 = 4, s6 = 6, s8 = 8, s12 = 12;
  static const double s16 = 16, s20 = 20, s24 = 24, s32 = 32, s40 = 40, s48 = 48;

  // ── شعاعونه ────────────────────────────────────────────
  static const double rSm = 10, rMd = 14, rLg = 20, rXl = 28, rPill = 999;

  static BorderRadius brSm = BorderRadius.circular(rSm);
  static BorderRadius brMd = BorderRadius.circular(rMd);
  static BorderRadius brLg = BorderRadius.circular(rLg);
  static BorderRadius brXl = BorderRadius.circular(rXl);

  // ── د حرکت وختونه ──────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration slower = Duration(milliseconds: 650);

  // نرم، طبیعي منحني — د ټول پروګرام لپاره یو شان
  static const Curve ease = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve spring = Curves.easeOutBack;

  // ── د برانډ رنګونه ─────────────────────────────────────
  static const Color brand = Color(0xFF4F6BED);
  static const Color brandAlt = Color(0xFF7C5CFF);
  static const Color teal = Color(0xFF12B5A5);
  static const Color amber = Color(0xFFF5A524);
  static const Color rose = Color(0xFFF2436B);
  static const Color green = Color(0xFF2BB673);
  static const Color sky = Color(0xFF2AA8F2);
  static const Color violet = Color(0xFF9B5CF6);
  static const Color orange = Color(0xFFFF7A45);

  // ── د نرمو آیکن کاشیو رنګونه (سایډبار) ────────────────
  //
  // هر توکی یو نرم پس‌منظر او یو ډک رنګ لري. په تیاره تیم کې
  // پس‌منظر د ډک رنګ یوه کمزورې بڼه ده، نو د تور پر سر هم ښکلی وي.
  static const Map<TileTone, Color> tileInk = {
    TileTone.blue: Color(0xFF4F7DF3),
    TileTone.amber: Color(0xFFF5A524),
    TileTone.orange: Color(0xFFF97B3D),
    TileTone.green: Color(0xFF2BB673),
    TileTone.teal: Color(0xFF14B8A6),
    TileTone.pink: Color(0xFFF2568F),
    TileTone.purple: Color(0xFF8B5CF6),
    TileTone.slate: Color(0xFF8A94A6),
  };

  static const Map<TileTone, Color> tileBgLight = {
    TileTone.blue: Color(0xFFE8EFFE),
    TileTone.amber: Color(0xFFFEF3E2),
    TileTone.orange: Color(0xFFFDEBE0),
    TileTone.green: Color(0xFFE4F7EC),
    TileTone.teal: Color(0xFFE0F5F2),
    TileTone.pink: Color(0xFFFDE7EF),
    TileTone.purple: Color(0xFFEFE8FD),
    TileTone.slate: Color(0xFFEEF0F3),
  };

  /// د کارتونو رنګین ګرادیانتونه — د ډاشبورډ لپاره.
  static const List<List<Color>> cardGradients = [
    [Color(0xFF4F6BED), Color(0xFF7C5CFF)],
    [Color(0xFF12B5A5), Color(0xFF35D6A4)],
    [Color(0xFFF5A524), Color(0xFFFF7A45)],
    [Color(0xFFF2436B), Color(0xFF9B5CF6)],
    [Color(0xFF2AA8F2), Color(0xFF4F6BED)],
    [Color(0xFF2BB673), Color(0xFF12B5A5)],
  ];
}

/// د سایډبار د آیکن کاشیو رنګ.
enum TileTone { blue, amber, orange, green, teal, pink, purple, slate }

/// د میټاډیټا رنګ‌ټګونه — د Adobe Bridge د Label سیسټم په څېر.
enum ColorTag {
  none('بې‌رنګه', Color(0xFF9AA1AC)),
  red('سور', Color(0xFFE5484D)),
  orange('نارنجي', Color(0xFFF76B15)),
  yellow('ژیړ', Color(0xFFFFC53D)),
  green('شین', Color(0xFF30A46C)),
  blue('آبي', Color(0xFF3E7BFA)),
  purple('بنفش', Color(0xFF8E4EC6)),
  pink('ګلابي', Color(0xFFE93D82)),
  gray('خړ', Color(0xFF6E7681));

  const ColorTag(this.label, this.color);
  final String label;
  final Color color;

  static ColorTag fromName(String? n) =>
      ColorTag.values.firstWhere((e) => e.name == n, orElse: () => ColorTag.none);
}
