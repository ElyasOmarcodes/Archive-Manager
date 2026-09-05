import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **سایډبار** — د پښتو RTL لپاره ښي طرف ته.
///
/// هر توکی یوه نرمه رنګینه آیکن کاشۍ لري، او د شمېر بیج یې بل لور ته —
/// نو لیست په یوه نظر لوستل کیږي او رنګونه د پېژندنې لار جوړوي.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.onNewEvent,
    this.forceCollapsed = false,
  });

  final VoidCallback onNewEvent;

  /// کله چې کړکۍ تنګه شي، سایډبار پخپله راټولیږي — بې له دې چې
  /// د کاروونکي خپله خوښه بدله کړي.
  final bool forceCollapsed;

  static const double expandedWidth = 252;
  static const double collapsedWidth = 76;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final open = s.sidebarExpanded && !forceCollapsed;

    return AnimatedContainer(
      duration: AppTokens.base,
      curve: AppTokens.emphasized,
      width: open ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(right: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        children: [
          _Brand(open: open),
          // تل ښکاره — نو نوې پیښه هر وخت یو کلیک لرې وي.
          Padding(
            padding: EdgeInsets.fromLTRB(
                open ? AppTokens.s12 : AppTokens.s12,
                AppTokens.s12,
                open ? AppTokens.s12 : AppTokens.s12,
                AppTokens.s4),
            child: _NewEventButton(open: open, onTap: onNewEvent),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                  horizontal: open ? AppTokens.s12 : AppTokens.s8),
              children: [
                _GroupLabel('آرشیف', open: open),
                for (final p in const [
                  AppPage.dashboard,
                  AppPage.events,
                  AppPage.explorer,
                ])
                  _NavItem(page: p, open: open, count: _countFor(s, p)),

                _GroupLabel('مدیریت', open: open),
                for (final p in const [
                  AppPage.keywords,
                  AppPage.categories,
                  AppPage.persons,
                ])
                  _NavItem(page: p, open: open, count: _countFor(s, p)),

                _GroupLabel('نور', open: open),
                _NavItem(page: AppPage.settings, open: open),
                const SizedBox(height: AppTokens.s24),
              ],
            ),
          ),
          _DriveFooter(open: open),
        ],
      ),
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
//  سرلیک
// ═══════════════════════════════════════════════════════════

class _Brand extends StatelessWidget {
  const _Brand({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
          open ? AppTokens.s12 : AppTokens.s8, AppTokens.s16, AppTokens.s12, AppTokens.s16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          if (open)
            IconButton(
              tooltip: 'سایډبار وتړه',
              icon: const Icon(Icons.view_sidebar_outlined, size: 19),
              onPressed: s.toggleSidebar,
              splashRadius: 18,
              visualDensity: VisualDensity.compact,
            ),
          if (open) ...[
            // Flexible — نو د اوږد ډرایو نوم سره هم سرلیک بهر نه لویږي
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('د آرشیف مدیریت',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          height: 1.3)),
                  Text(
                    'v1.0.1 · ${_driveLabel(s.settings.archiveRoot)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant,
                        height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.s8),
          ],
          _AppMark(compact: !open, onTap: open ? null : s.toggleSidebar),
        ],
      ),
    );
  }

  static String _driveLabel(String? root) {
    if (root == null || root.isEmpty) return 'ARCHIVE';
    final seg = root
        .split(RegExp(r'[\\/]'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (seg.isEmpty) return 'ARCHIVE';
    return seg.last.toUpperCase();
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.compact, this.onTap});
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF3B82F6), Color(0xFF4F6BED)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
    );

    if (onTap == null) return mark;
    return Tooltip(
      message: 'سایډبار پرانیزه',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: mark,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د ډلې سرلیک
// ═══════════════════════════════════════════════════════════

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {required this.open});
  final String text;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!open) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s12, vertical: AppTokens.s8),
        child: Divider(height: 1, color: cs.outlineVariant),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.s8, AppTokens.s20, AppTokens.s8, AppTokens.s8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د ناوبرۍ توکی
// ═══════════════════════════════════════════════════════════

class _NavItem extends StatelessWidget {
  const _NavItem({required this.page, required this.open, this.count});

  final AppPage page;
  final bool open;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final active = s.page == page && s.editing == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: open ? '' : page.title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => s.go(page),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: AppTokens.fast,
              curve: AppTokens.ease,
              padding: EdgeInsets.symmetric(
                  horizontal: open ? AppTokens.s8 : 0, vertical: 7),
              decoration: BoxDecoration(
                // فعال توکی یو خنثی نرم پس‌منظر لري — رنګ یوازې د
                // آیکن کاشۍ کې دی، نو لیست ارام او پاک ښکاري.
                color: active ? cs.surfaceContainerHigh : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment:
                    open ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  if (open && count != null) ...[
                    _CountBadge(count: count!, active: active),
                    const SizedBox(width: AppTokens.s8),
                  ] else if (open)
                    const SizedBox(width: 2),
                  if (open) const Spacer(),
                  if (open)
                    Flexible(
                      child: Text(
                        page.title,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  if (open) const SizedBox(width: AppTokens.s12),
                  _IconTile(tone: page.tone, icon: page.icon, active: active),
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
  });

  final TileTone tone;
  final IconData icon;
  final bool active;

  static const double size = 34;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = AppTokens.tileInk[tone]!;
    // په تیاره تیم کې نرم پس‌منظر د ډک رنګ کمزورې بڼه ده.
    final bg = dark
        ? ink.withValues(alpha: active ? 0.26 : 0.18)
        : AppTokens.tileBgLight[tone]!;

    return AnimatedContainer(
      duration: AppTokens.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(icon, size: size * 0.5, color: dark ? ink : ink),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: active ? cs.surfaceContainerHighest : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        PashtoDigits.to(_grouped(count)),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  /// `12486` → `12,486`
  static String _grouped(int n) {
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
//  د نوې پیښې تڼۍ
// ═══════════════════════════════════════════════════════════

class _NewEventButton extends StatelessWidget {
  const _NewEventButton({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: open ? '' : 'نوې پیښه',
      child: SizedBox(
        width: double.infinity,
        height: 42,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: open ? const Text('نوې پیښه') : const SizedBox.shrink(),
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: open ? 14 : 0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د ډرایو حالت
// ═══════════════════════════════════════════════════════════

class _DriveFooter extends StatelessWidget {
  const _DriveFooter({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final disk = s.disk;
    final connected = s.settings.archiveRoot != null && !s.rootMissing;
    final label = _Brand._driveLabel(s.settings.archiveRoot);

    if (!open) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.s12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Center(child: _Dot(ok: connected)),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.s12, AppTokens.s12, AppTokens.s12, AppTokens.s12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (disk.isValid)
                Text(
                  '${humanBytes(disk.usedBytes)} / ${humanBytes(disk.totalBytes)}',
                  style: TextStyle(
                      fontSize: 10.5, color: cs.onSurfaceVariant),
                ),
              const Spacer(),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface),
                ),
              ),
              const SizedBox(width: 6),
              _Dot(ok: connected),
            ],
          ),
          if (disk.isValid) ...[
            const SizedBox(height: AppTokens.s8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: disk.usedRatio),
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
                          // ۹۰٪+ سور — ډرایو نږدې ډک دی
                          color: v > 0.9
                              ? AppTokens.rose
                              : v > 0.75
                                  ? AppTokens.amber
                                  : cs.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${humanBytes(disk.freeBytes)} پاتې  ·  '
              '${PashtoDigits.to(s.stats.eventCount)} پیښې',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                connected ? 'چمتو' : 'ډرایو نه دی وصل',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
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
              color: (ok ? AppTokens.green : AppTokens.rose)
                  .withValues(alpha: 0.5),
              blurRadius: 5,
            ),
          ],
        ),
      );
}
