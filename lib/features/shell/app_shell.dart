import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/platform/backend.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../dashboard/dashboard_page.dart';
import '../editor/event_editor_page.dart';
import '../editor/new_event_dialog.dart';
import '../events/events_page.dart';
import '../explorer/explorer_page.dart';
import '../../data/models/models.dart';
import '../manage/vocab_page.dart';
import '../settings/settings_page.dart';
import 'sidebar.dart';

/// **د پروګرام اصلي چوکاټ** — سایډبار + سرلیک + د پاڼې محتوا.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const _TopBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppTokens.base,
                    switchInCurve: AppTokens.ease,
                    switchOutCurve: AppTokens.ease,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                                begin: const Offset(0, 0.012), end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    child: _body(s),
                  ),
                ),
              ],
            ),
          ),
          AppSidebar(onNewEvent: () => showNewEventDialog(context)),
        ],
      ),
    );
  }

  Widget _body(AppState s) {
    // که پیښه پرانیستل شوې وي، ایډیټر/پریویو د هرې پاڼې پر ځای ښکاري.
    if (s.editing != null) {
      return EventEditorPage(key: ValueKey('editor-${s.editing!.id}'));
    }
    return switch (s.page) {
      AppPage.dashboard => const DashboardPage(key: ValueKey('dash')),
      AppPage.events => const EventsPage(key: ValueKey('events')),
      AppPage.explorer => const ExplorerPage(key: ValueKey('explorer')),
      AppPage.keywords =>
        const VocabPage(kind: VocabKind.keyword, key: ValueKey('kw')),
      AppPage.persons =>
        const VocabPage(kind: VocabKind.person, key: ValueKey('ps')),
      AppPage.categories =>
        const VocabPage(kind: VocabKind.category, key: ValueKey('cat')),
      AppPage.settings => const SettingsPage(key: ValueKey('settings')),
    };
  }
}

/// پورتنی بار — د آرشیف مسیر، ټول‌ځایي لټون او د تیم بدلون.
class _TopBar extends StatefulWidget {
  const _TopBar();

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          // ټول‌ځایي لټون — هر ځای کې کار کوي
          SearchBox(
            controller: _search,
            width: 340,
            hint: 'په ټول آرشیف کې ولټوه…  (کیورډ، شخصیت، متن)',
            onSubmitted: (v) {
              s.go(AppPage.events);
              s.setQuery(s.query.copyWith(text: v));
            },
            onChanged: (v) {
              if (v.isEmpty && s.query.text.isNotEmpty) {
                s.setQuery(s.query.copyWith(text: ''));
              }
            },
          ),
          const SizedBox(width: AppTokens.s16),
          if (s.scan != null) _ScanIndicator(progress: s.scan!),
          const Spacer(),
          if (s.isDemo) const _DemoBadge(),
          const SizedBox(width: AppTokens.s8),
          IconButton(
            tooltip: 'آرشیف بیا سکن کړه',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: s.scan != null ? null : s.rescanArchive,
          ),
          const _ThemeToggle(),
        ],
      ),
    );
  }
}

/// د سکن ژوندی پرمختګ — د ۵TB ډرایو پر مهال کاروونکی نه ګنګسیږي.
class _ScanIndicator extends StatelessWidget {
  const _ScanIndicator({required this.progress});
  final ScanProgress progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
          const SizedBox(width: AppTokens.s8),
          Text(
            'سکن روان دی — ${PashtoDigits.to(progress.found)} پیښې موندل شوې',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: cs.primary),
          ),
        ],
      ),
    );
  }
}

/// د تیم د بدلون تڼۍ — سپین ↔ تیاره ↔ سیستم.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.settings.theme;
    return IconButton(
      tooltip: 'تیم: ${t.label}',
      onPressed: () {
        final next = switch (t) {
          ThemeChoice.light => ThemeChoice.dark,
          ThemeChoice.dark => ThemeChoice.system,
          ThemeChoice.system => ThemeChoice.light,
        };
        s.setTheme(next);
      },
      icon: AnimatedSwitcher(
        duration: AppTokens.base,
        transitionBuilder: (c, a) => RotationTransition(
            turns: Tween<double>(begin: 0.6, end: 1).animate(a),
            child: FadeTransition(opacity: a, child: c)),
        child: Icon(
          switch (t) {
            ThemeChoice.light => Icons.light_mode_rounded,
            ThemeChoice.dark => Icons.dark_mode_rounded,
            ThemeChoice.system => Icons.brightness_auto_rounded,
          },
          key: ValueKey(t),
          size: 20,
        ),
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTokens.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTokens.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_rounded, size: 13, color: AppTokens.amber),
          const SizedBox(width: 5),
          Text('د نندارې نسخه',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}
