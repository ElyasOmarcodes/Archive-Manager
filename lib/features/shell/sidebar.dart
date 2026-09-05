import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';

/// **ښکلی سایډبار** — راټولېدونکی، د نرم حرکت سره.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, required this.onNewEvent});

  final VoidCallback onNewEvent;

  static const double expandedWidth = 246;
  static const double collapsedWidth = 74;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final open = s.sidebarExpanded;

    return AnimatedContainer(
      duration: AppTokens.base,
      curve: AppTokens.emphasized,
      width: open ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          left: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          _Brand(open: open),
          const SizedBox(height: AppTokens.s8),
          _NewEventButton(open: open, onTap: onNewEvent),
          const SizedBox(height: AppTokens.s16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12),
              children: [
                _group(context, 'اصلي', open),
                for (final p in [AppPage.dashboard, AppPage.events, AppPage.explorer])
                  _NavItem(page: p, open: open),
                const SizedBox(height: AppTokens.s12),
                _group(context, 'میټاډیټا', open),
                for (final p in [
                  AppPage.keywords,
                  AppPage.persons,
                  AppPage.categories
                ])
                  _NavItem(page: p, open: open),
                const SizedBox(height: AppTokens.s12),
                _group(context, 'نور', open),
                _NavItem(page: AppPage.settings, open: open),
              ],
            ),
          ),
          _Footer(open: open),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String label, bool open) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: AppTokens.fast,
      child: open
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.s12, AppTokens.s8, AppTokens.s12, AppTokens.s6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          : const SizedBox(height: AppTokens.s12),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.s16, AppTokens.s20, AppTokens.s12, AppTokens.s16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppTokens.brand, AppTokens.brandAlt],
              ),
              borderRadius: AppTokens.brMd,
              boxShadow: [
                BoxShadow(
                  color: AppTokens.brand.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: Colors.white, size: 20),
          ),
          if (open) ...[
            const SizedBox(width: AppTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('د آرشیف مدیر',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface),
                      overflow: TextOverflow.ellipsis),
                  Text('چټک لټون او تنظیم',
                      style: TextStyle(
                          fontSize: 10.5, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
          IconButton(
            tooltip: open ? 'سایډبار وتړه' : 'سایډبار پرانیزه',
            icon: AnimatedRotation(
              duration: AppTokens.base,
              turns: open ? 0 : 0.5,
              child: const Icon(Icons.menu_open_rounded, size: 19),
            ),
            onPressed: s.toggleSidebar,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _NewEventButton extends StatelessWidget {
  const _NewEventButton({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: Tooltip(
          message: open ? '' : 'نوې پیښه',
          child: FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: open
                ? const Text('نوې پیښه')
                : const SizedBox.shrink(),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: open ? 16 : 0),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.page, required this.open});
  final AppPage page;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final active = s.page == page && s.editing == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Tooltip(
        message: open ? '' : page.title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => s.go(page),
            borderRadius: AppTokens.brMd,
            child: AnimatedContainer(
              duration: AppTokens.fast,
              curve: AppTokens.ease,
              padding: EdgeInsets.symmetric(
                  horizontal: open ? AppTokens.s12 : 0, vertical: 11),
              decoration: BoxDecoration(
                color: active ? cs.primary.withValues(alpha: 0.12) : null,
                borderRadius: AppTokens.brMd,
              ),
              child: Row(
                mainAxisAlignment: open
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  // د فعال توکي رنګینه کرښه
                  if (open)
                    AnimatedContainer(
                      duration: AppTokens.base,
                      curve: AppTokens.ease,
                      width: 3,
                      height: active ? 18 : 0,
                      margin: const EdgeInsets.only(left: AppTokens.s8),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  Icon(
                    page.icon,
                    size: 19,
                    color: active ? cs.primary : cs.onSurfaceVariant,
                  ),
                  if (open) ...[
                    const SizedBox(width: AppTokens.s12),
                    Expanded(
                      child: Text(
                        page.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final root = s.settings.archiveRoot ?? '—';

    return Container(
      padding: const EdgeInsets.all(AppTokens.s12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: open
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage_rounded,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        root,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${PashtoDigits.to(s.stats.eventCount)} پیښې  ·  '
                  '${PashtoDigits.to(s.stats.attachmentCount)} فایلونه',
                  style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
                ),
              ],
            )
          : Center(
              child: Icon(Icons.storage_rounded,
                  size: 17, color: cs.onSurfaceVariant),
            ),
    );
  }
}
