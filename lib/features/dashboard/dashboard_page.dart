import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/platform/backend.dart';
import '../../data/models/query.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/ring_chart.dart';
import '../editor/new_event_dialog.dart';
import '../events/event_card.dart';

/// **ډاشبورډ** — د آرشیف یوه نظره انځور.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final stats = s.stats;
    final today = TriDate.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.s20),
      // په ډېرو پراخو سکرینونو کې محتوا مرکز ته راټولوو — بې له دې
      // به کارتونه ډېر اوږده او پلن ښکاري او سترګه به یې نه لولي.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBanner(today: today),
              const SizedBox(height: AppTokens.s20),

              // ── رنګین کارټونه ──
              _StatCards(stats: stats),
              const SizedBox(height: AppTokens.s16),

              // ── ګرافونه ──
              LayoutBuilder(
                builder: (context, c) {
                  final storage = _StorageCard(stats: stats);
                  final media = _MediaBreakdown(stats: stats);
                  final weekly = _WeeklyChart(stats: stats);

                  if (c.maxWidth > 1240) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 4, child: storage),
                          const SizedBox(width: AppTokens.s16),
                          Expanded(flex: 5, child: media),
                          const SizedBox(width: AppTokens.s16),
                          Expanded(flex: 6, child: weekly),
                        ],
                      ),
                    );
                  }
                  if (c.maxWidth > 880) {
                    return Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 4, child: storage),
                              const SizedBox(width: AppTokens.s16),
                              Expanded(flex: 6, child: media),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTokens.s16),
                        weekly,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      storage,
                      const SizedBox(height: AppTokens.s16),
                      media,
                      const SizedBox(height: AppTokens.s16),
                      weekly,
                    ],
                  );
                },
              ),

              const SizedBox(height: AppTokens.s16),
              _RatingSpread(stats: stats),
              const SizedBox(height: AppTokens.s20),
              _RecentEvents(events: stats.recentEvents),
              const SizedBox(height: AppTokens.s24),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د سرلیک بانر
// ═══════════════════════════════════════════════════════════

/// د پاڼې سرلیک — د نرم رنګین شالید سره.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.today});
  final TriDate today;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final dark = t.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTokens.s20),
      decoration: BoxDecoration(
        borderRadius: AppTokens.brLg,
        border: Border.all(color: cs.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: dark
              ? [
                  AppTokens.brand.withValues(alpha: 0.20),
                  cs.surfaceContainerLowest.withValues(alpha: 0.2),
                ]
              : [
                  AppTokens.brand.withValues(alpha: 0.10),
                  AppTokens.brandAlt.withValues(alpha: 0.04),
                ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 620;
          return Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppTokens.brand, AppTokens.brandAlt],
                  ),
                  borderRadius: AppTokens.brMd,
                  boxShadow: [
                    BoxShadow(
                      color: AppTokens.brand.withValues(alpha: 0.36),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.space_dashboard_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: AppTokens.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ډاشبورډ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.headlineSmall,
                    ),
                    Text(
                      'نن  ·  ${s.dateText(today)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.s12),
              if (compact)
                IconButton.filled(
                  onPressed: () => showNewEventDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  tooltip: 'نوې پیښه',
                )
              else
                FilledButton.icon(
                  onPressed: () => showNewEventDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('نوې پیښه'),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د ډرایو ځای
// ═══════════════════════════════════════════════════════════

/// د آرشیف د ډرایو حالت — د حلقې چارټ سره.
///
/// د ۵TB بهرني هارډ لپاره دا تر ټولو مهم عدد دی: څومره ځای پاتې دی.
class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.stats});
  final ArchiveStats stats;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final disk = s.disk;

    final ratio = disk.usedRatio;
    final tone = ratio > 0.9
        ? AppTokens.rose
        : ratio > 0.75
        ? AppTokens.amber
        : AppTokens.brand;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('د ډرایو ځای', icon: Icons.storage_rounded),
          if (!disk.isValid)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.s32),
              child: Center(
                child: Text(
                  'د ډرایو معلومات نشته',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else ...[
            Center(
              child: RingChart(
                size: 148,
                thickness: 14,
                slices: [
                  RingSlice(value: disk.usedBytes.toDouble(), color: tone),
                  RingSlice(
                    value: disk.freeBytes.toDouble(),
                    color: cs.surfaceContainerHighest,
                  ),
                ],
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${PashtoDigits.to((ratio * 100).round())}٪',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: tone,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'ډک',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.s16),
            _kv(context, 'کارول شوی', humanBytes(disk.usedBytes), tone),
            const SizedBox(height: AppTokens.s8),
            _kv(
              context,
              'پاتې',
              humanBytes(disk.freeBytes),
              cs.onSurfaceVariant,
            ),
            const SizedBox(height: AppTokens.s8),
            _kv(
              context,
              'د آرشیف برخه',
              humanBytes(stats.totalBytes),
              AppTokens.teal,
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, Color dot) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTokens.s8),
        Expanded(
          child: Text(
            k,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
        Text(
          v,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  رنګین کارټونه
// ═══════════════════════════════════════════════════════════

class _StatCards extends StatelessWidget {
  const _StatCards({required this.stats});
  final ArchiveStats stats;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final items = [
      (
        'ټولې پیښې',
        stats.eventCount,
        Icons.auto_awesome_mosaic_rounded,
        AppTokens.cardGradients[0],
        '',
        () => s.go(AppPage.events),
      ),
      (
        'ټول فایلونه',
        stats.attachmentCount,
        Icons.perm_media_rounded,
        AppTokens.cardGradients[1],
        humanBytes(stats.totalBytes),
        null,
      ),
      (
        'کیورډونه',
        stats.keywordCount,
        Icons.sell_rounded,
        AppTokens.cardGradients[2],
        '',
        () => s.go(AppPage.keywords),
      ),
      (
        'شخصیتونه',
        stats.personCount,
        Icons.groups_rounded,
        AppTokens.cardGradients[3],
        '',
        () => s.go(AppPage.persons),
      ),
      (
        'کټګورۍ',
        stats.categoryCount,
        Icons.category_rounded,
        AppTokens.cardGradients[4],
        '',
        () => s.go(AppPage.categories),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1180
            ? 5
            : c.maxWidth > 900
            ? 4
            : c.maxWidth > 620
            ? 3
            : c.maxWidth > 380
            ? 2
            : 1;
        const gap = AppTokens.s16;
        // په لوی سکرین کې کارتونه پراخ کیږي، نو قد یې هم لوړیږي —
        // بې له دې به پلن او سطحي ښکاري.
        final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
        final cardH = (cardW * 0.52).clamp(156.0, 190.0);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: cardW,
                // ثابت لوړوالی — نو هیڅ کارت له نورو لوړ نه راځي، آن که
                // یو یې اضافي کرښه ولري.
                height: cardH,
                child: FadeSlideIn(
                  delay: AppTokens.staggerFor(i),
                  child: _GradientCard(
                    label: items[i].$1,
                    value: items[i].$2,
                    icon: items[i].$3,
                    colors: items[i].$4,
                    footnote: items[i].$5,
                    onTap: items[i].$6,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GradientCard extends StatelessWidget {
  const _GradientCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
    this.footnote = '',
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final List<Color> colors;
  final String footnote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      onTap: onTap,
      lift: 5,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppTokens.base,
        curve: AppTokens.ease,
        padding: const EdgeInsets.all(AppTokens.s20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: colors,
          ),
          borderRadius: AppTokens.brLg,
          // نرمه پورتنۍ کرښه — کارت ته د ښیښې احساس ورکوي
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: hovered ? 0.42 : 0.26),
              blurRadius: hovered ? 26 : 16,
              offset: Offset(0, hovered ? 10 : 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: AppTokens.brSm,
                  ),
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const Spacer(),
                if (onTap != null)
                  AnimatedOpacity(
                    duration: AppTokens.fast,
                    opacity: hovered ? 1 : 0.45,
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            // Flexible + FittedBox: عدد د پاتې ځای مطابق کوچنی کیږي،
            // نو په هیڅ کچه کې له کارت بهر نه لویږي.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: CountUp(
                  value,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            // دا کرښه تل ځای نیسي (که تشه هم وي) — نو ټول کارتونه
            // په دننه کې یو شان تنظیم شوي وي.
            SizedBox(
              height: 17,
              child: Text(
                footnote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د فایلونو ویش — د پرمختګ بارونو سره
// ═══════════════════════════════════════════════════════════

class _MediaBreakdown extends StatelessWidget {
  const _MediaBreakdown({required this.stats});
  final ArchiveStats stats;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final entries = stats.mediaBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (a, e) => a + e.value);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(
            'د فایلونو نوعیت او اندازه',
            icon: Icons.donut_small_rounded,
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.s32),
              child: Center(
                child: Text(
                  'لا هیڅ فایل نه دی ثبت شوی',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTokens.s16),
              FadeSlideIn(
                delay: AppTokens.staggerFor(i),
                child: InkWell(
                  onTap: () {
                    s.go(AppPage.events);
                    s.setQuery(s.query.copyWith(mediaKinds: {entries[i].key}));
                  },
                  borderRadius: AppTokens.brSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: LabeledProgress(
                      label: entries[i].key.label,
                      value: entries[i].value,
                      total: total,
                      color: mediaColor(entries[i].key),
                      icon: mediaIcon(entries[i].key),
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د اونۍ فعالیت
// ═══════════════════════════════════════════════════════════

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.stats});
  final ArchiveStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = stats.weeklyActivity;
    final maxV = (data.isEmpty ? 0 : data.reduce((a, b) => a > b ? a : b));
    final top = (maxV < 4 ? 4 : maxV + 1).toDouble();
    final today = TriDate.now();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            'د تېرې اونۍ فعالیت',
            icon: Icons.show_chart_rounded,
            trailing: Text(
              '${PashtoDigits.to(data.fold<int>(0, (a, b) => a + b))} پیښې',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.s12),
          SizedBox(
            height: 186,
            child: BarChart(
              BarChartData(
                maxY: top,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => cs.inverseSurface,
                    getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                      '${PashtoDigits.to(r.toY.round())} پیښې',
                      TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onInverseSurface,
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: top / 4,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: cs.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: top / 4,
                      getTitlesWidget: (v, _) => Text(
                        PashtoDigits.to(v.round()),
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      // دوه کرښې (د اونۍ ورځ + د میاشتې ورځ) ځای غواړي
                      reservedSize: 44,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        final d = TriDate.fromJdn(today.jdn - (6 - i));
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                PashtoMonths.weekDaysShort[d.shamsiWeekDay],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == 6
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: i == 6
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                PashtoDigits.to(d.shamsi.day),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < 7; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (i < data.length ? data[i] : 0).toDouble(),
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: i == 6
                                ? [AppTokens.brandAlt, AppTokens.brand]
                                : [
                                    AppTokens.brand.withValues(alpha: 0.45),
                                    AppTokens.brand.withValues(alpha: 0.85),
                                  ],
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: top,
                            color: cs.surfaceContainer,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د درجې ویش
// ═══════════════════════════════════════════════════════════

class _RatingSpread extends StatelessWidget {
  const _RatingSpread({required this.stats});
  final ArchiveStats stats;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final total = stats.eventCount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(
            'د اهمیت له مخې ویش (ستوري)',
            icon: Icons.star_rounded,
          ),
          LayoutBuilder(
            builder: (context, c) {
              // په تنګو سکرینونو کې شپږ کالمه نه ځاییږي — نو درې کیږي.
              final perRow = c.maxWidth > 720 ? 6 : 3;
              const gap = AppTokens.s12;
              final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var r = 5; r >= 0; r--) ...[
                    SizedBox(
                      width: w,
                      child: HoverLift(
                        onTap: () {
                          s.go(AppPage.events);
                          s.setQuery(s.query.copyWith(ratings: {r}));
                        },
                        builder: (context, hovered) => AnimatedContainer(
                          duration: AppTokens.base,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTokens.s16,
                            horizontal: AppTokens.s8,
                          ),
                          decoration: BoxDecoration(
                            // څومره ډېر ستوري، هومره ډېر ژیړ — نو اهمیت
                            // په یوه نظر لوستل کیږي.
                            color: hovered
                                ? AppTokens.amber.withValues(alpha: 0.16)
                                : AppTokens.amber.withValues(
                                    alpha: 0.028 * r + 0.012,
                                  ),
                            borderRadius: AppTokens.brMd,
                            border: Border.all(
                              color: hovered
                                  ? AppTokens.amber.withValues(alpha: 0.45)
                                  : AppTokens.amber.withValues(
                                      alpha: 0.05 * r + 0.03,
                                    ),
                            ),
                          ),
                          child: Column(
                            children: [
                              r == 0
                                  ? Icon(
                                      Icons.star_border_rounded,
                                      size: 16,
                                      color: cs.onSurfaceVariant,
                                    )
                                  : StarRating(value: r, size: 13),
                              const SizedBox(height: AppTokens.s8),
                              CountUp(
                                stats.ratingSpread[r] ?? 0,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                total == 0
                                    ? '۰٪'
                                    : '${PashtoDigits.to((((stats.ratingSpread[r] ?? 0) / total) * 100).round())}٪',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  وروستۍ پیښې
// ═══════════════════════════════════════════════════════════

class _RecentEvents extends StatelessWidget {
  const _RecentEvents({required this.events});
  final List<EventMetadata> events;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'وروستۍ پیښې',
          icon: Icons.history_rounded,
          trailing: TextButton.icon(
            onPressed: () {
              s.go(AppPage.events);
              s.setQuery(const EventQuery());
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 15),
            label: const Text('ټولې وګوره'),
          ),
        ),
        if (events.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppTokens.s40),
            child: EmptyState(
              icon: Icons.auto_awesome_mosaic_rounded,
              title: 'لا هیڅ پیښه نه ده ثبت شوې',
              message: 'د «نوې پیښه» تڼۍ ووهئ او خپله لومړۍ پیښه ثبت کړئ.',
              action: FilledButton.icon(
                onPressed: () => showNewEventDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('نوې پیښه'),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 1180 ? 3 : (c.maxWidth > 720 ? 2 : 1);
              const gap = AppTokens.s16;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < events.length; i++)
                    SizedBox(
                      width: w,
                      child: FadeSlideIn(
                        delay: AppTokens.staggerFor(i),
                        child: EventCard(event: events[i], compact: true),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
