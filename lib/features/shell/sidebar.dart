import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **سایډبار** — د پښتو RTL لپاره ښي طرف ته.
///
/// دوه حالته لري: **پراخ** (آیکن + متن) او **ټول شوی** (یوازې آیکن).
/// د دواړو ترمنځ بدلون یوه یوازینۍ انیمیشن چلوي — نو سور، متن او
/// بیجونه ټول سره یوځای او نرم حرکت کوي، نه دا چې یو دم ورک شي.
class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    this.forceCollapsed = false,
  });


  /// کله چې کړکۍ تنګه شي، سایډبار پخپله راټولیږي.
  final bool forceCollapsed;

  static const double expandedWidth = 258;
  static const double collapsedWidth = 78;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppTokens.slow,
    value: 1,
  );

  /// ۰ = بشپړ ټول شوی، ۱ = بشپړ پراخ.
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: AppTokens.emphasized,
    reverseCurve: AppTokens.emphasized.flipped,
  );

  bool _lastOpen = true;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _sync(bool open) {
    if (open == _lastOpen) return;
    _lastOpen = open;
    open ? _c.forward() : _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final open = s.sidebarExpanded && !widget.forceCollapsed;

    // د بنا پر مهال setState نه شو کولی — نو انیمیشن وروسته پیلوو.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(open));

    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final t = _t.value;
        final width = AppSidebar.collapsedWidth +
            (AppSidebar.expandedWidth - AppSidebar.collapsedWidth) * t;

        return Container(
          width: width,
          decoration: BoxDecoration(
            // **سایډبار باید له پاڼې څخه بېل ښکاري.**
            // پخوا په سپین تیم کې دواړه نږدې سپین وو، نو سرحد یې نه
            // معلومېده. اوس سایډبار یوه پوړۍ توره ده تر پاڼې —
            // لږ، خو بس چې پوله یې واضح شي.
            color: dark ? cs.surfaceContainerLow : cs.surfaceContainer,
            border: Border(
                right: BorderSide(color: cs.outline.withValues(alpha: 0.45))),
            boxShadow: [
              if (dark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(6, 0),
                ),
            ],
          ),
          child: ClipRect(
            child: Column(
              children: [
                _Brand(t: t, onToggle: s.toggleSidebar, locked: widget.forceCollapsed),
                // د «نوې پیښه» تڼۍ دلته نه ده — په ډاشبورډ، د پیښو
                // پاڼه او اکسپلورر کې شته، نو سایډبار یوازې ناوبري ده.
                const SizedBox(height: AppTokens.s8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s12),
                    children: [
                      _GroupLabel('آرشیف', t: t),
                      for (final p in const [
                        AppPage.dashboard,
                        AppPage.events,
                        AppPage.explorer,
                      ])
                        _NavItem(page: p, t: t, count: _countFor(s, p)),

                      _GroupLabel('مدیریت', t: t),
                      for (final p in const [
                        AppPage.keywords,
                        AppPage.categories,
                        AppPage.persons,
                      ])
                        _NavItem(page: p, t: t, count: _countFor(s, p)),

                      _GroupLabel('نور', t: t),
                      _NavItem(page: AppPage.settings, t: t),
                      const SizedBox(height: AppTokens.s24),
                    ],
                  ),
                ),
                _DriveFooter(t: t),
              ],
            ),
          ),
        );
      },
    );
  }

  static int? _countFor(AppState s, AppPage p) => switch (p) {
        AppPage.events => s.stats.eventCount,
        AppPage.keywords => s.stats.keywordCount,
        AppPage.persons => s.stats.personCount,
        AppPage.categories => s.stats.categoryCount,
        _ => null,
      };
}

// ═══════════════════════════════════════════════════════════
//  د پراخېدو ګډ مرستندوی
// ═══════════════════════════════════════════════════════════

/// هغه محتوا چې یوازې په پراخ حالت کې ښکاري.
///
/// د پراخېدو پر مهال لومړی ځای جوړیږي، بیا متن راښکاره کیږي — نو
/// حرکت طبیعي وي، نه چې متن د تنګ ځای دننه ونښلي.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.t, required this.child, this.axis = Axis.horizontal});

  final double t;
  final Widget child;
  final Axis axis;

  /// متن یوازې د حرکت په دویمه نیمایي کې راڅرګندیږي.
  static double fade(double t) => ((t - 0.45) / 0.55).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    if (t <= 0.001) return const SizedBox.shrink();
    return ClipRect(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: axis == Axis.horizontal ? t : null,
        heightFactor: axis == Axis.vertical ? t : null,
        child: Opacity(opacity: fade(t), child: child),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  سرلیک
// ═══════════════════════════════════════════════════════════

class _Brand extends StatelessWidget {
  const _Brand({required this.t, required this.onToggle, required this.locked});

  final double t;
  final VoidCallback onToggle;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.s12, AppTokens.s16, AppTokens.s12, AppTokens.s16),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: cs.outline.withValues(alpha: 0.28))),
      ),
      child: Row(
        children: [
          // ── د ټولولو/پراخولو تڼۍ (چپ) ──
          _Reveal(
            t: t,
            child: Padding(
              padding: const EdgeInsets.only(left: AppTokens.s4),
              child: IconButton(
                tooltip: 'سایډبار وتړه',
                onPressed: locked ? null : onToggle,
                icon: const Icon(Icons.keyboard_double_arrow_right_rounded,
                    size: 19),
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          // ── نوم + نسخه ──
          Expanded(
            child: _Reveal(
              t: t,
              child: Padding(
                padding: const EdgeInsets.only(left: AppTokens.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('د آرشیف مدیریت',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            height: 1.3)),
                    Text(
                      'v1.1.0 · ${driveLabel(s.settings.archiveRoot)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: cs.onSurfaceVariant,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── نښه (تل ښي طرف ته) ──
          _AppMark(t: t, onTap: locked ? null : onToggle),
        ],
      ),
    );
  }

  static String driveLabel(String? root) {
    if (root == null || root.isEmpty) return 'ARCHIVE';
    final seg =
        root.split(RegExp(r'[\\/]')).where((e) => e.trim().isNotEmpty).toList();
    if (seg.isEmpty) return 'ARCHIVE';
    return seg.last.toUpperCase();
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.t, this.onTap});
  final double t;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // په ټول شوي حالت کې نښه یو څه لویه شي — نو د وهلو ښه هدف وي.
    final size = 38 + (1 - t) * 4;

    return Tooltip(
      message: t < 0.5 ? 'سایډبار پرانیزه' : '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: AppTokens.base,
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF4F8DF9), Color(0xFF4F6BED)],
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F8DF9).withValues(alpha: 0.42),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(Icons.hub_rounded, color: Colors.white, size: size * 0.52),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د ډلې سرلیک
// ═══════════════════════════════════════════════════════════

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {required this.t});
  final String text;
  final double t;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // په ټول شوي حالت کې سرلیک یوې کرښې ته اوړي.
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.s16, bottom: AppTokens.s8),
      child: Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [
          Opacity(
            opacity: 1 - _Reveal.fade(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s8),
              child: Divider(height: 1, color: cs.outlineVariant),
            ),
          ),
          _Reveal(
            t: t,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s8),
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د ناوبرۍ توکی
// ═══════════════════════════════════════════════════════════

class _NavItem extends StatefulWidget {
  const _NavItem({required this.page, required this.t, this.count});

  final AppPage page;
  final double t;
  final int? count;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // `watch` به د AppState د هر بدلون سره دا توکی بیا جوړ کړ —
    // آن کله چې یوازې د لټون پایلې بدلې شوې وي. `select` یوازې د
    // فعال حالت پر بدلون بیا جوړوي.
    final active = context.select<AppState, bool>(
        (s) => s.page == widget.page && s.editing == null);
    final t = widget.t;
    final ink = AppTokens.tileInk[widget.page.tone]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Tooltip(
        message: t < 0.5 ? widget.page.title : '',
        waitDuration: const Duration(milliseconds: 300),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: () => context.read<AppState>().go(widget.page),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: AppTokens.base,
              curve: AppTokens.ease,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s6, vertical: 6),
              decoration: BoxDecoration(
                // سایډبار اوس یو څه تور دی، نو فعال توکی روښانه کیږي
                // (نه تور) — پر سپین تیم کې دا ښه توپیر جوړوي.
                color: active
                    ? (dark
                        ? ink.withValues(alpha: 0.16)
                        : cs.surfaceContainerLowest)
                    : _hover
                        ? (dark
                            ? Colors.white.withValues(alpha: 0.045)
                            : cs.surfaceContainerLowest
                                .withValues(alpha: 0.62))
                        : null,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: active && dark
                      ? ink.withValues(alpha: 0.32)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  // ① آیکن — تل تر ټولو ښي لور ته
                  _IconTile(
                    tone: widget.page.tone,
                    icon: widget.page.icon,
                    active: active,
                    hovered: _hover,
                  ),

                  // ② متن — آیکن ته ورپسې
                  //
                  // `Expanded` نه `Flexible`+`Spacer`: هغه دواړه د پاتې
                  // ځای پر سر سیالي کوله او متن یې پرې کاوه.
                  Expanded(
                    child: _Reveal(
                      t: t,
                      child: Padding(
                        padding: const EdgeInsets.only(
                            right: AppTokens.s12, left: AppTokens.s8),
                        child: Text(
                          widget.page.title,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? (dark ? Colors.white : cs.onSurface)
                                : cs.onSurface.withValues(alpha: 0.86),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ③ شمېره — تر ټولو چپ لور ته
                  if (widget.count != null)
                    _Reveal(
                      t: t,
                      child: _CountBadge(count: widget.count!, active: active),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// نرمه رنګینه آیکن کاشۍ.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.tone,
    required this.icon,
    this.active = false,
    this.hovered = false,
  });

  final TileTone tone;
  final IconData icon;
  final bool active;
  final bool hovered;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = AppTokens.tileInk[tone]!;

    // په تیاره تیم کې نرم پس‌منظر د سطحې او ډک رنګ ترمنځ یوه ګډه ده —
    // نو کاشۍ روښانه ښکاري خو سترګې نه ځوروي.
    final bg = dark
        ? Color.lerp(cs.surfaceContainerHigh, ink,
            active ? 0.30 : (hovered ? 0.22 : 0.16))!
        : active
            ? Color.lerp(AppTokens.tileBgLight[tone]!, ink, 0.12)!
            : AppTokens.tileBgLight[tone]!;

    final fg = dark ? Color.lerp(ink, Colors.white, 0.24)! : ink;

    return AnimatedContainer(
      duration: AppTokens.base,
      curve: AppTokens.ease,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          if (active)
            BoxShadow(
              color: ink.withValues(alpha: dark ? 0.30 : 0.24),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: AnimatedScale(
        duration: AppTokens.base,
        curve: AppTokens.spring,
        scale: hovered ? 1.08 : 1.0,
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.active});
  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? (dark
                ? Colors.white.withValues(alpha: 0.10)
                : cs.surfaceContainerHigh)
            : (dark
                ? Colors.white.withValues(alpha: 0.055)
                : cs.surfaceContainerHigh.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        PashtoDigits.to(grouped(count)),
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  /// `12486` → `12,486`
  static String grouped(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

// ═══════════════════════════════════════════════════════════
//  د ډرایو حالت
// ═══════════════════════════════════════════════════════════

class _DriveFooter extends StatelessWidget {
  const _DriveFooter({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final disk = s.disk;
    final connected = s.settings.archiveRoot != null && !s.rootMissing;
    final label = _Brand.driveLabel(s.settings.archiveRoot);

    final ratio = disk.usedRatio;
    final barColor = ratio > 0.9
        ? AppTokens.rose
        : ratio > 0.75
            ? AppTokens.amber
            : cs.primary;

    return Container(
      padding: const EdgeInsets.all(AppTokens.s12),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: cs.outline.withValues(alpha: 0.28))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // په ټول شوي حالت کې یوازې نښه پاتې کیږي — نو مرکز ته یې راولو
              if (t < 0.5) const Spacer(),
              _Dot(ok: connected),
              Expanded(
                child: _Reveal(
                  t: t,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface),
                    ),
                  ),
                ),
              ),
              if (disk.isValid)
                _Reveal(
                  t: t,
                  child: Text(
                    '${humanBytes(disk.usedBytes)} / ${humanBytes(disk.totalBytes)}',
                    maxLines: 1,
                    softWrap: false,
                    style:
                        TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          if (disk.isValid) ...[
            const SizedBox(height: AppTokens.s8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: AppTokens.slower,
              curve: AppTokens.easeInOut,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(height: 5, color: cs.surfaceContainerHigh),
                    FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            barColor.withValues(alpha: 0.65),
                            barColor,
                          ]),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _Reveal(
              t: t,
              axis: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    '${humanBytes(disk.freeBytes)} پاتې  ·  '
                    '${PashtoDigits.to(s.stats.eventCount)} پیښې',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
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

class _Dot extends StatelessWidget {
  const _Dot({required this.ok});
  final bool ok;

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: ok ? AppTokens.green : AppTokens.rose,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:
                  (ok ? AppTokens.green : AppTokens.rose).withValues(alpha: 0.6),
              blurRadius: 6,
            ),
          ],
        ),
      );
}
