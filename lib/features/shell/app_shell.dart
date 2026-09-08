import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/platform/backend.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../dashboard/dashboard_page.dart';
import '../editor/event_editor_page.dart';
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

    return LayoutBuilder(builder: (context, c) {
      // په تنګو کړکیو کې سایډبار پخپله راټولیږي — نو د محتوا لپاره
      // ځای پاتې کیږي او هیڅ برخه بهر نه لویږي.
      final narrow = c.maxWidth < 1000;
      return _buildShell(context, s, forceCollapsed: narrow);
    });
  }

  Widget _buildShell(BuildContext context, AppState s,
      {required bool forceCollapsed}) {
    return Scaffold(body: _shellBody(context, s, forceCollapsed));
  }

  Widget _shellBody(BuildContext context, AppState s, bool forceCollapsed) {
    // پروګرام پښتو (RTL) دی، نو سایډبار ښي طرف ته وي — همدا د
    // ښي‌څخه‌کیڼ لوستلو طبیعي لور دی. په RTL کې د Row لومړی اولاد
    // ښي لور ته ځي.
    return Row(
        children: [
          AppSidebar(forceCollapsed: forceCollapsed),
          Expanded(
            child: Column(
              children: [
                // **پورتنی بار یوازې په ډاشبورډ کې.**
                //
                // ټول‌ځایي لټون، د بیا‌سکن تڼۍ او د تیم ایکن د
                // ډاشبورډ اوزار دي. په نورو پاڼو کې هره پاڼه خپل
                // ټولبار لري (د پیښو فلټر، د اکسپلورر مسیر…) — نو
                // دوه بارونه سر پر سر ناغېړ ځای نیسي.
                //
                // د سکن پرمختګ بایللی نه دی: د سایډبار په پایښت
                // کې ښکاري، نو هره پاڼه کې لیدل کیږي.
                if (s.page == AppPage.dashboard && s.editing == null)
                  const _TopBar(),
                // **ولې دلته `AnimatedSwitcher` نشته؟**
                //
                // هغه د بدلون پر مهال **دواړه** پاڼې په ونه کې ساتي او پر
                // ټوله پردۍ یو `saveLayer` (شفافیت پوړ) جوړوي — یعنې
                // د هرې فریم لپاره دوه پاڼې رسمیږي. دا په ۱۶۰۰×۱۰۰۰ کې
                // ډېر ګران دی، او هماغه ځنډ و چې کاروونکي لیده.
                //
                // اوس پاڼه سمدستي بدلیږي، او د پاڼې خپل توکي په
                // `FadeSlideIn` سره نرم راځي — هماغه ښکلا، خو یوه پاڼه.
                Expanded(child: _body(s)),
              ],
            ),
          ),
        ],
    );
  }

  Widget _body(AppState s) {
    // که پیښه پرانیستل شوې وي، ایډیټر/پریویو د هرې پاڼې پر ځای ښکاري.
    if (s.editing != null) {
      // محتوا لا په لوستلو کې ده — ایډیټر یوازې بشپړې ډیټا سره پیل کیږي.
      if (s.editorLoading) {
        return const Center(
            key: ValueKey('editor-loading'),
            child: SizedBox(
                width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4)));
      }
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
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        // د لټون بکس د پاتې ځای مطابق کوچنی کیږي، خو له ۱۶۰px نه
        // ښکته نه ځي — نو په هیڅ کچه کې بهر نه لویږي.
        //
        // **پام:** دلته `s.scan` مه ګډوئ. پخوا د سکن پر مهال دا
        // عرض کوچنی کېده او د سکن اندیکېټر یې د `Spacer` ځای نیوه —
        // نو د بیا‌سکن او تیم ایکنونه له خپل ځایه ښوېدل. اوس د
        // ټولبار جوړښت د سکن له حالت څخه بشپړ خپلواک دی.
        final reserved = 150 + (s.isDemo ? 120 : 0);
        final searchW = (c.maxWidth - reserved).clamp(160.0, 380.0);
        return Row(
        children: [
          // ټول‌ځایي لټون — هر ځای کې کار کوي
          SearchBox(
            controller: _search,
            width: searchW,
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
          const SizedBox(width: AppTokens.s12),
          // د سکن اندیکېټر د تش ځای **دننه** ژوند کوي — نه د هغه
          // ترڅنګ. نو کله چې راځي یا ځي، هیڅ نور شی نه خوځیږي.
          Expanded(
            child: s.scan == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _ScanIndicator(progress: s.scan!),
                  ),
          ),
          if (s.isDemo && c.maxWidth > 720) const _DemoBadge(),
          const SizedBox(width: AppTokens.s8),
          // د سکن پر مهال همدې تڼۍ کې یو څرخېدونکی ښکاري — نو
          // ایکن خپل ځای نه بایلي، یوازې بڼه یې بدلیږي.
          IconButton(
            tooltip: s.scan != null ? 'سکن روان دی…' : 'آرشیف بیا سکن کړه',
            icon: s.scan != null
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            onPressed: s.scan != null ? null : s.rescanArchive,
          ),
          const _ThemeToggle(),
        ],
        );
      }),
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
