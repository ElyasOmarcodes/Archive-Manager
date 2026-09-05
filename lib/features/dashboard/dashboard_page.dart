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
      padding: const EdgeInsets.all(AppTokens.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            icon: Icons.space_dashboard_rounded,
            title: 'ډاشبورډ',
            subtitle: 'نن  ·  ${s.dateText(today)}',
            actions: [
              FilledButton.icon(
                onPressed: () => showNewEventDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('نوې پیښه'),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s24),

          // ── رنګین کارټونه ──
          _StatCards(stats: stats),
          const SizedBox(height: AppTokens.s20),

          // ── ګرافونه ──
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 1080;
            final left = _MediaBreakdown(stats: stats);
            final right = _WeeklyChart(stats: stats);
            if (!wide) {
              return Column(children: [
                left,
                const SizedBox(height: AppTokens.s20),
                right
              ]);
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: left),
                  const SizedBox(width: AppTokens.s20),
                  Expanded(flex: 6, child: right),
                ],
              ),
            );
          }),

          const SizedBox(height: AppTokens.s20),
          _RatingSpread(stats: stats),
          const SizedBox(height: AppTokens.s20),
          _RecentEvents(events: stats.recentEvents),
          const SizedBox(height: AppTokens.s24),
        ],
      ),
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
        'ټولې پیښې', stats.eventCount, Icons.auto_awesome_mosaic_rounded,
        AppTokens.cardGradients[0], '', () => s.go(AppPage.events)
      ),
      (
        'ټول فایلونه', stats.attachmentCount, Icons.perm_media_rounded,
        AppTokens.cardGradients[1], humanBytes(stats.totalBytes), null
      ),
      (
        'کیورډونه', stats.keywordCount, Icons.sell_rounded,
        AppTokens.cardGradients[2], '', () => s.go(AppPage.keywords)
      ),
      (
        'شخصیتونه', stats.personCount, Icons.groups_rounded,
        AppTokens.cardGradients[3], '', () => s.go(AppPage.persons)
      ),
      (
        'کټګورۍ', stats.categoryCount, Icons.category_rounded,
        AppTokens.cardGradients[4], '', () => s.go(AppPage.categories)
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 1240 ? 5 : (c.maxWidth > 860 ? 3 : 2);
      const gap = AppTokens.s16;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < items.length; i++)
            SizedBox(
              width: w,
              child: FadeSlideIn(
                delay: Duration(milliseconds: 60 * i),
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
    });
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
          mainAxisSize: MainAxisSize.min,
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
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 16, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.s16),
            CountUp(
              value,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            if (footnote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                footnote,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
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
          const SectionLabel('د فایلونو نوعیت او اندازه',
              icon: Icons.donut_small_rounded),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.s32),
              child: Center(
                child: Text('لا هیڅ فایل نه دی ثبت شوی',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTokens.s16),
              FadeSlideIn(
                delay: Duration(milliseconds: 70 * i),
                child: InkWell(
                  onTap: () {
                    s.go(AppPage.events);
                    s.setQuery(s.query
                        .copyWith(mediaKinds: {entries[i].key}));
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
                  color: cs.primary),
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
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: top / 4,
                      getTitlesWidget: (v, _) => Text(
                        PashtoDigits.to(v.round()),
                        style:
                            TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
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
                                        : cs.onSurfaceVariant),
                              ),
                              Text(
                                PashtoDigits.to(d.shamsi.day),
                                style: TextStyle(
                                    fontSize: 9, color: cs.onSurfaceVariant),
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
                              top: Radius.circular(6)),
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
          const SectionLabel('د اهمیت له مخې ویش (ستوري)',
              icon: Icons.star_rounded),
          Row(
            children: [
              for (var r = 5; r >= 0; r--) ...[
                if (r < 5) const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: HoverLift(
                    onTap: () {
                      s.go(AppPage.events);
                      s.setQuery(s.query.copyWith(ratings: {r}));
                    },
                    builder: (context, hovered) => AnimatedContainer(
                      duration: AppTokens.base,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.s16, horizontal: AppTokens.s8),
                      decoration: BoxDecoration(
                        color: hovered
                            ? AppTokens.amber.withValues(alpha: 0.10)
                            : cs.surfaceContainer,
                        borderRadius: AppTokens.brMd,
                        border: Border.all(
                          color: hovered
                              ? AppTokens.amber.withValues(alpha: 0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          r == 0
                              ? Icon(Icons.star_border_rounded,
                                  size: 16, color: cs.onSurfaceVariant)
                              : StarRating(value: r, size: 13),
                          const SizedBox(height: AppTokens.s8),
                          CountUp(
                            stats.ratingSpread[r] ?? 0,
                            style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface),
                          ),
                          Text(
                            total == 0
                                ? '۰٪'
                                : '${PashtoDigits.to((((stats.ratingSpread[r] ?? 0) / total) * 100).round())}٪',
                            style: TextStyle(
                                fontSize: 10.5, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
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
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 1300 ? 3 : (c.maxWidth > 820 ? 2 : 1);
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
                      delay: Duration(milliseconds: 55 * i),
                      child: EventCard(event: events[i], compact: true),
                    ),
                  ),
              ],
            );
          }),
      ],
    );
  }
}
