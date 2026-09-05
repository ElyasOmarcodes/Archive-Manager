import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/models/query.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/tri_date_picker.dart';

/// **د فلټر پینل** — د Adobe Bridge د Filter Panel بشپړ معادل.
///
/// هره ډله ژوندۍ شمېرې ښیي، او د ډلو ترمنځ **AND** او د یوې ډلې دننه
/// **OR** عمل کوي — دقیقاً هغه چلند چې مسلکي کاروونکي ورته عادت دي.
class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key});

  static const double width = 288;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final q = s.query;
    final f = s.facets;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(left: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        children: [
          // سرلیک + پاکول
          Container(
            padding: const EdgeInsets.fromLTRB(
                AppTokens.s16, AppTokens.s16, AppTokens.s8, AppTokens.s12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_alt_rounded, size: 17, color: cs.primary),
                const SizedBox(width: AppTokens.s8),
                const Text('فلټرونه',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (q.activeFilterCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      PashtoDigits.to(q.activeFilterCount),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimary),
                    ),
                  ),
                ],
                const Spacer(),
                if (q.hasAnyFilter)
                  TextButton(
                    onPressed: s.clearFilters,
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero),
                    child: const Text('پاک کړه',
                        style: TextStyle(fontSize: 11.5)),
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppTokens.s16),
              children: [
                _RatingGroup(query: q, facets: f),
                const _Gap(),
                _ColorGroup(query: q, facets: f),
                const _Gap(),
                _DateGroup(query: q),
                const _Gap(),
                _TermGroup(
                  title: 'کټګورۍ',
                  icon: Icons.category_rounded,
                  counts: f.categories,
                  selected: q.categories,
                  onChanged: (v) => s.setQuery(q.copyWith(categories: v)),
                ),
                const _Gap(),
                _TermGroup(
                  title: 'کیورډونه',
                  icon: Icons.sell_rounded,
                  counts: f.keywords,
                  selected: q.keywords,
                  onChanged: (v) => s.setQuery(q.copyWith(keywords: v)),
                  searchable: true,
                  prefix: '#',
                ),
                const _Gap(),
                _TermGroup(
                  title: 'شخصیتونه',
                  icon: Icons.groups_rounded,
                  counts: f.persons,
                  selected: q.persons,
                  onChanged: (v) => s.setQuery(q.copyWith(persons: v)),
                  searchable: true,
                ),
                const _Gap(),
                _MediaGroup(query: q, facets: f),
                const SizedBox(height: AppTokens.s40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.s16),
        child: Divider(
            height: 1, color: Theme.of(context).colorScheme.outlineVariant),
      );
}

// ═══════════════════════════════════════════════════════════
//  درجه
// ═══════════════════════════════════════════════════════════

class _RatingGroup extends StatelessWidget {
  const _RatingGroup({required this.query, required this.facets});
  final EventQuery query;
  final FacetCounts facets;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('درجه (ستوري)', icon: Icons.star_rounded),
        for (var r = 5; r >= 0; r--)
          _Row(
            selected: query.ratings.contains(r),
            count: facets.ratings[r] ?? 0,
            onTap: () {
              final next = Set<int>.from(query.ratings);
              next.contains(r) ? next.remove(r) : next.add(r);
              s.setQuery(query.copyWith(ratings: next));
            },
            child: r == 0
                ? Row(
                    children: [
                      Icon(Icons.star_border_rounded,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('بې درجې',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  )
                : StarRating(value: r, size: 14),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  رنګ ټګ
// ═══════════════════════════════════════════════════════════

class _ColorGroup extends StatelessWidget {
  const _ColorGroup({required this.query, required this.facets});
  final EventQuery query;
  final FacetCounts facets;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('رنګ ټګ', icon: Icons.palette_rounded),
        Wrap(
          spacing: AppTokens.s6,
          runSpacing: AppTokens.s6,
          children: [
            for (final c in ColorTag.values)
              if ((facets.colors[c] ?? 0) > 0 || query.colors.contains(c))
                SelectChip(
                  label: c.label,
                  color: c == ColorTag.none ? null : c.color,
                  icon: c == ColorTag.none ? Icons.block_rounded : null,
                  selected: query.colors.contains(c),
                  count: facets.colors[c] ?? 0,
                  onTap: () {
                    final next = Set<ColorTag>.from(query.colors);
                    next.contains(c) ? next.remove(c) : next.add(c);
                    s.setQuery(query.copyWith(colors: next));
                  },
                ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د فایلونو ډول
// ═══════════════════════════════════════════════════════════

class _MediaGroup extends StatelessWidget {
  const _MediaGroup({required this.query, required this.facets});
  final EventQuery query;
  final FacetCounts facets;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('د فایلونو ډول', icon: Icons.perm_media_rounded),
        for (final k in MediaKind.values)
          if ((facets.mediaKinds[k] ?? 0) > 0 || query.mediaKinds.contains(k))
            _Row(
              selected: query.mediaKinds.contains(k),
              count: facets.mediaKinds[k] ?? 0,
              onTap: () {
                final next = Set<MediaKind>.from(query.mediaKinds);
                next.contains(k) ? next.remove(k) : next.add(k);
                s.setQuery(query.copyWith(mediaKinds: next));
              },
              child: Row(
                children: [
                  Icon(mediaIcon(k), size: 14, color: mediaColor(k)),
                  const SizedBox(width: 7),
                  Text(k.label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د نېټې سلسله — درې واړه تقویمونه
// ═══════════════════════════════════════════════════════════

class _DateGroup extends StatelessWidget {
  const _DateGroup({required this.query});
  final EventQuery query;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final has = query.fromJdn != null || query.toJdn != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'د پیښې تاریخ',
          icon: Icons.event_rounded,
          trailing: has
              ? InkWell(
                  onTap: () => s.setQuery(
                      query.copyWith(fromJdn: null, toJdn: null)),
                  child: Icon(Icons.close_rounded,
                      size: 14, color: cs.onSurfaceVariant),
                )
              : null,
        ),
        // د تقویم ټاکنه — یوازې د ښودلو لپاره، پلټنه تل پر JDN ده.
        Row(
          children: [
            for (final k in CalendarKind.values) ...[
              if (k != CalendarKind.values.first) const SizedBox(width: 5),
              Expanded(
                child: SelectChip(
                  label: k.label.replaceAll('هجري ', ''),
                  selected: query.dateKind == k,
                  onTap: () => s.setQuery(query.copyWith(dateKind: k)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppTokens.s12),
        _DateBound(
          label: 'له',
          jdn: query.fromJdn,
          kind: query.dateKind,
          onPick: (d) => s.setQuery(query.copyWith(fromJdn: d?.jdn)),
        ),
        const SizedBox(height: AppTokens.s8),
        _DateBound(
          label: 'تر',
          jdn: query.toJdn,
          kind: query.dateKind,
          onPick: (d) => s.setQuery(query.copyWith(toJdn: d?.jdn)),
        ),
        const SizedBox(height: AppTokens.s12),
        // چټکې لنډې لارې
        Wrap(
          spacing: AppTokens.s6,
          runSpacing: AppTokens.s6,
          children: [
            for (final p in _presets(query.dateKind))
              SelectChip(
                label: p.$1,
                selected: query.fromJdn == p.$2 && query.toJdn == p.$3,
                onTap: () => s.setQuery(
                    query.copyWith(fromJdn: p.$2, toJdn: p.$3)),
              ),
          ],
        ),
      ],
    );
  }

  /// چټکې سلسلې — د اوسني تقویم مطابق.
  List<(String, int, int)> _presets(CalendarKind k) {
    final now = TriDate.now();
    final d = now.dateFor(k);
    (int, int) yearRange(int y) {
      final from = switch (k) {
        CalendarKind.shamsi => TriDate.fromShamsi(y, 1, 1),
        CalendarKind.qamari => TriDate.fromQamari(y, 1, 1),
        CalendarKind.miladi => TriDate.fromGregorian(y, 1, 1),
      };
      final lastMonthLen = TriDate.monthLength(k, y, 12);
      final to = switch (k) {
        CalendarKind.shamsi => TriDate.fromShamsi(y, 12, lastMonthLen),
        CalendarKind.qamari => TriDate.fromQamari(y, 12, lastMonthLen),
        CalendarKind.miladi => TriDate.fromGregorian(y, 12, lastMonthLen),
      };
      return (from.jdn, to.jdn);
    }

    final thisYear = yearRange(d.year);
    final lastYear = yearRange(d.year - 1);
    return [
      ('تېرې ۷ ورځې', now.jdn - 6, now.jdn),
      ('تېره میاشت', now.jdn - 29, now.jdn),
      ('${PashtoDigits.to(d.year)} کال', thisYear.$1, thisYear.$2),
      ('${PashtoDigits.to(d.year - 1)} کال', lastYear.$1, lastYear.$2),
    ];
  }
}

class _DateBound extends StatelessWidget {
  const _DateBound({
    required this.label,
    required this.jdn,
    required this.kind,
    required this.onPick,
  });

  final String label;
  final int? jdn;
  final CalendarKind kind;
  final ValueChanged<TriDate?> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = jdn == null ? null : TriDate.fromJdn(jdn!);

    return InkWell(
      onTap: () async {
        final picked =
            await showTriDatePicker(context, d ?? TriDate.now());
        if (picked != null) onPick(picked);
      },
      borderRadius: AppTokens.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s12, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: AppTokens.brSm,
          border: Border.all(
              color: d == null ? cs.outlineVariant : cs.primary),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(
                d == null ? 'وټاکئ…' : d.textFor(kind),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: d == null ? FontWeight.w400 : FontWeight.w600,
                  color: d == null ? cs.onSurfaceVariant : cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (d != null)
              InkResponse(
                onTap: () => onPick(null),
                radius: 12,
                child: Icon(Icons.close_rounded,
                    size: 13, color: cs.onSurfaceVariant),
              )
            else
              Icon(Icons.event_rounded, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  عمومي د لغتونو ډله (کیورډ / شخصیت / کټګوري)
// ═══════════════════════════════════════════════════════════

class _TermGroup extends StatefulWidget {
  const _TermGroup({
    required this.title,
    required this.icon,
    required this.counts,
    required this.selected,
    required this.onChanged,
    this.searchable = false,
    this.prefix = '',
  });

  final String title;
  final IconData icon;
  final Map<String, int> counts;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool searchable;
  final String prefix;

  @override
  State<_TermGroup> createState() => _TermGroupState();
}

class _TermGroupState extends State<_TermGroup> {
  final _filter = TextEditingController();
  bool _showAll = false;

  static const _collapsedCount = 8;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _filter.text.trim();

    // ټاکل شوي تل پورته — نو کاروونکی یې هیڅکله نه ورکوي.
    var entries = widget.counts.entries
        .where((e) => q.isEmpty || e.key.contains(q))
        .toList()
      ..sort((a, b) {
        final aSel = widget.selected.contains(a.key);
        final bSel = widget.selected.contains(b.key);
        if (aSel != bSel) return aSel ? -1 : 1;
        return b.value.compareTo(a.value);
      });

    for (final s in widget.selected) {
      if (!entries.any((e) => e.key == s)) {
        entries.insert(0, MapEntry(s, 0));
      }
    }

    final hidden = entries.length - _collapsedCount;
    if (!_showAll && hidden > 0) {
      entries = entries.take(_collapsedCount).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          widget.title,
          icon: widget.icon,
          trailing: widget.selected.isEmpty
              ? null
              : InkWell(
                  onTap: () => widget.onChanged(<String>{}),
                  child: Icon(Icons.close_rounded,
                      size: 14, color: cs.onSurfaceVariant),
                ),
        ),
        if (widget.searchable && widget.counts.length > 6) ...[
          TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'په ${widget.title} کې ولټوه…',
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded,
                  size: 15, color: cs.onSurfaceVariant),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 30),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: AppTokens.s8),
        ],
        if (entries.isEmpty)
          Text('هیڅ نه شته',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant))
        else
          for (final e in entries)
            _Row(
              selected: widget.selected.contains(e.key),
              count: e.value,
              onTap: () {
                final next = Set<String>.from(widget.selected);
                next.contains(e.key) ? next.remove(e.key) : next.add(e.key);
                widget.onChanged(next);
              },
              child: Text(
                '${widget.prefix}${e.key}',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        if (hidden > 0)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero),
            child: Text(
              _showAll
                  ? 'لږ وښیه'
                  : 'نور ${PashtoDigits.to(hidden)} وښیه',
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}

/// د فلټر یوه کرښه — چیک بکس + محتوا + شمېره.
class _Row extends StatelessWidget {
  const _Row({
    required this.selected,
    required this.count,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final int count;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = count == 0 && !selected;

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: AppTokens.brSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s6, vertical: 5),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppTokens.fast,
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: selected ? cs.primary : cs.outline,
                      width: 1.4,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded,
                          size: 11, color: cs.onPrimary)
                      : null,
                ),
                const SizedBox(width: AppTokens.s8),
                Expanded(child: child),
                Text(
                  PashtoDigits.to(count),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
