import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/query.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../editor/new_event_dialog.dart';
import 'event_card.dart';
import 'filter_panel.dart';

/// **د ټولو پیښو پاڼه** — ګریډ ویو + د Bridge په څېر فلټر پینل.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _search = TextEditingController();
  bool _showFilters = true;

  @override
  void initState() {
    super.initState();
    _search.text = context.read<AppState>().query.text;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// د تنګو سکرینونو لپاره — فلټرونه د یوې کشېدونکې پاڼې دننه.
  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: ChangeNotifierProvider<AppState>.value(
            value: context.read<AppState>(),
            child: const FilterPanel(sheet: true),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(builder: (context, c) {
      // د فلټر پینل ~۲۹۰px نیسي؛ که ورسته له هغه د ګریډ لپاره
      // بس ځای پاتې نه شي، پینل پخپله پټیږي.
      final canShowFilters = c.maxWidth >= 900;
      final showFilters = _showFilters && canShowFilters;
      return Row(
      children: [
        // په RTL کې لومړی اولاد ښي ته ځي — نو فلټر پینل وروستی
        // (چپ طرف) وي، لکه څنګه چې غوښتل شوی و.
        Expanded(
          child: Column(
            children: [
              // ── سرلیک او وسیلې ──
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTokens.s24,
                    AppTokens.s24, AppTokens.s24, AppTokens.s16),
                child: Column(
                  children: [
                    PageHeader(
                      icon: Icons.auto_awesome_mosaic_rounded,
                      title: 'ټولې پیښې',
                      subtitle: s.loading
                          ? 'بارېږي…'
                          : '${PashtoDigits.to(s.facets.total)} پیښې'
                              '${s.query.hasAnyFilter ? ' (فلټر شوې)' : ''}',
                      actions: [
                        FilledButton.icon(
                          onPressed: () => showNewEventDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('نوې پیښه'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.s16),
                    // په تنګو کچو کې وسیلې ښکته کرښې ته ځي، نه چې
                    // یو له بل سره ونښلي یا بهر ولویږي.
                    Wrap(
                      spacing: AppTokens.s8,
                      runSpacing: AppTokens.s8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: (c.maxWidth -
                                  (showFilters ? FilterPanel.width : 0) -
                                  AppTokens.s24 * 2 -
                                  260)
                              .clamp(180.0, 620.0),
                          child: SearchBox(
                            controller: _search,
                            hint: 'د پیښې نوم، متن، کیورډ یا شخصیت…',
                            onChanged: (v) =>
                                s.setQuery(s.query.copyWith(text: v)),
                          ),
                        ),
                        _SortMenu(),
                        _GridSizeToggle(),
                        if (canShowFilters)
                          IconButton.filledTonal(
                            tooltip: showFilters
                                ? 'فلټرونه پټ کړه'
                                : 'فلټرونه وښیه',
                            onPressed: () =>
                                setState(() => _showFilters = !_showFilters),
                            icon: Icon(
                              showFilters
                                  ? Icons.filter_alt_off_rounded
                                  : Icons.filter_alt_rounded,
                              size: 19,
                            ),
                          )
                        else
                          // په تنګو کچو کې پینل نه ځاییږي، نو فلټرونه
                          // د یوې کشېدونکې پاڼې له لارې ښکاري.
                          IconButton.filledTonal(
                            tooltip: 'فلټرونه',
                            onPressed: () => _openFilterSheet(context),
                            icon: Badge(
                              isLabelVisible: s.query.activeFilterCount > 0,
                              label: Text(PashtoDigits.to(
                                  s.query.activeFilterCount)),
                              child: const Icon(Icons.filter_alt_rounded,
                                  size: 19),
                            ),
                          ),
                      ],
                    ),
                    if (s.query.hasAnyFilter) ...[
                      const SizedBox(height: AppTokens.s12),
                      const _ActiveFilterBar(),
                    ],
                  ],
                ),
              ),

              Divider(height: 1, color: cs.outlineVariant),

              // ── ګریډ ──
              Expanded(
                child: s.loading && s.events.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : s.events.isEmpty
                        ? EmptyState(
                            icon: s.query.hasAnyFilter
                                ? Icons.search_off_rounded
                                : Icons.auto_awesome_mosaic_rounded,
                            title: s.query.hasAnyFilter
                                ? 'هیڅ پایله ونه موندل شوه'
                                : 'لا هیڅ پیښه نه ده ثبت شوې',
                            message: s.query.hasAnyFilter
                                ? 'خپل فلټرونه لږ کم کړئ او بیا هڅه وکړئ.'
                                : 'خپله لومړۍ پیښه ثبت کړئ.',
                            action: s.query.hasAnyFilter
                                ? OutlinedButton.icon(
                                    onPressed: s.clearFilters,
                                    icon: const Icon(Icons.clear_all_rounded,
                                        size: 18),
                                    label: const Text('فلټرونه پاک کړه'),
                                  )
                                : FilledButton.icon(
                                    onPressed: () =>
                                        showNewEventDialog(context),
                                    icon:
                                        const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('نوې پیښه'),
                                  ),
                          )
                        : _Grid(),
              ),
            ],
          ),
        ),

        // ── فلټر پینل ──
        AnimatedSize(
          duration: AppTokens.base,
          curve: AppTokens.emphasized,
          child: showFilters
              ? const FilterPanel()
              : const SizedBox(width: 0, height: double.infinity),
        ),
      ],
      );
    });
  }
}

class _Grid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return LayoutBuilder(builder: (context, c) {
      final target = switch (s.settings.gridSize) {
        1 => 480.0,
        2 => 380.0,
        _ => 300.0,
      };
      final cols = (c.maxWidth / target).floor().clamp(1, 6);
      const gap = AppTokens.s16;
      final w = (c.maxWidth - AppTokens.s24 * 2 - gap * (cols - 1)) / cols;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.s24),
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < s.events.length; i++)
              SizedBox(
                width: w,
                child: FadeSlideIn(
                  delay: Duration(milliseconds: (28 * i).clamp(0, 400)),
                  child: EventCard(event: s.events[i]),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// د فعالو فلټرونو کرښه — هر یو د لرې کولو وړ.
class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = s.query;
    final chips = <Widget>[];

    void add(String label, VoidCallback onRemove, {Color? color}) {
      chips.add(SelectChip(
        label: label,
        selected: true,
        color: color,
        onTap: onRemove,
        onDelete: onRemove,
      ));
    }

    if (q.text.trim().isNotEmpty) {
      add('لټون: «${q.text}»', () => s.setQuery(q.copyWith(text: '')));
    }
    for (final r in q.ratings) {
      add(r == 0 ? 'بې درجې' : '${PashtoDigits.to(r)} ★', () {
        final n = Set<int>.from(q.ratings)..remove(r);
        s.setQuery(q.copyWith(ratings: n));
      });
    }
    for (final c in q.colors) {
      add(c.label, () {
        final n = Set.of(q.colors)..remove(c);
        s.setQuery(q.copyWith(colors: n));
      }, color: c == ColorTag.none ? null : c.color);
    }
    for (final c in q.categories) {
      add(c, () {
        final n = Set.of(q.categories)..remove(c);
        s.setQuery(q.copyWith(categories: n));
      });
    }
    for (final k in q.keywords) {
      add('#$k', () {
        final n = Set.of(q.keywords)..remove(k);
        s.setQuery(q.copyWith(keywords: n));
      });
    }
    for (final p in q.persons) {
      add(p, () {
        final n = Set.of(q.persons)..remove(p);
        s.setQuery(q.copyWith(persons: n));
      });
    }
    for (final m in q.mediaKinds) {
      add(m.label, () {
        final n = Set.of(q.mediaKinds)..remove(m);
        s.setQuery(q.copyWith(mediaKinds: n));
      });
    }
    if (q.fromJdn != null || q.toJdn != null) {
      final from = q.fromJdn == null
          ? '…'
          : TriDate.fromJdn(q.fromJdn!).textFor(q.dateKind);
      final to = q.toJdn == null
          ? '…'
          : TriDate.fromJdn(q.toJdn!).textFor(q.dateKind);
      add('$from — $to',
          () => s.setQuery(q.copyWith(fromJdn: null, toJdn: null)));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: AppTokens.s8,
        runSpacing: AppTokens.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton.icon(
            onPressed: s.clearFilters,
            icon: const Icon(Icons.clear_all_rounded, size: 15),
            label: const Text('ټول پاک کړه', style: TextStyle(fontSize: 11.5)),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero),
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return PopupMenuButton<SortField>(
      tooltip: 'ترتیب',
      initialValue: s.query.sort,
      onSelected: (v) => s.setQuery(s.query.copyWith(sort: v)),
      itemBuilder: (_) => [
        for (final f in SortField.values)
          PopupMenuItem(
            value: f,
            height: 38,
            child: Row(
              children: [
                Icon(
                  s.query.sort == f
                      ? Icons.check_rounded
                      : Icons.swap_vert_rounded,
                  size: 15,
                  color: s.query.sort == f
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.s12),
                Text(f.label),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: AppTokens.brMd,
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert_rounded, size: 16),
            const SizedBox(width: 6),
            Text(s.query.sort.label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 15),
          ],
        ),
      ),
    );
  }
}

class _GridSizeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    const icons = [
      Icons.view_agenda_rounded,
      Icons.grid_view_rounded,
      Icons.apps_rounded,
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            InkWell(
              onTap: () => s.setGridSize(i + 1),
              borderRadius: AppTokens.brSm,
              child: AnimatedContainer(
                duration: AppTokens.fast,
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: s.settings.gridSize == i + 1
                      ? cs.primary.withValues(alpha: 0.14)
                      : null,
                  borderRadius: AppTokens.brSm,
                ),
                child: Icon(
                  icons[i],
                  size: 16,
                  color: s.settings.gridSize == i + 1
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
