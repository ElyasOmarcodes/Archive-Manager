import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/text/pashto_text.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/tri_date_picker.dart';

/// **د میټاډیټا چپ پینل** — درجه، رنګ، کیورډونه، شخصیتونه، کټګوري، تاریخ.
class MetaPanel extends StatefulWidget {
  const MetaPanel({
    super.key,
    required this.event,
    required this.onChanged,
    this.sheet = false,
  });

  final EventMetadata event;
  final void Function(void Function()) onChanged;

  /// کله چې په تنګ سکرین کې د کشېدونکې پاڼې دننه ښکاري.
  final bool sheet;

  @override
  State<MetaPanel> createState() => _MetaPanelState();
}

class _MetaPanelState extends State<MetaPanel> {
  List<VocabTerm> _keywords = const [];
  List<VocabTerm> _persons = const [];
  List<VocabTerm> _categories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppState>();
    final k = await s.vocab(VocabKind.keyword);
    final p = await s.vocab(VocabKind.person);
    final c = await s.vocab(VocabKind.category);
    if (mounted) {
      setState(() {
        _keywords = k;
        _persons = p;
        _categories = c;
      });
    }
  }

  /// نوی لغت ثبتوي — د لغتونو لیست ته هم اضافه کیږي، نو د مدیریت
  /// پاڼه کې هم سمدلاسه ښکاري.
  Future<void> _addTerm(VocabKind kind, String name) async {
    final v = name.trim();
    if (v.isEmpty) return;
    await context.read<AppState>().addVocab(kind, v);
    widget.onChanged(() {
      final list = switch (kind) {
        VocabKind.keyword => widget.event.keywords,
        VocabKind.person => widget.event.persons,
        VocabKind.category => <String>[],
      };
      if (kind == VocabKind.category) {
        widget.event.category = v;
      } else if (!list.contains(v)) {
        list.add(v);
      }
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.event;

    return Container(
      width: widget.sheet ? null : 292,
      decoration: BoxDecoration(
        color: widget.sheet ? null : cs.surfaceContainerLow,
        border: widget.sheet
            ? null
            : Border(right: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.s16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 17, color: cs.primary),
                const SizedBox(width: AppTokens.s8),
                const Text('میټاډیټا',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const Spacer(),
                Tooltip(
                  message: 'دا معلومات د چټک لټون بنسټ دي — په '
                      'metadata.json کې ساتل کیږي',
                  child: Icon(Icons.help_outline_rounded,
                      size: 15, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppTokens.s16),
              children: [
                CollapsibleSection(
                  title: 'د پیښې نوم',
                  icon: Icons.title_rounded,
                  child: _TitleField(event: e, onChanged: widget.onChanged),
                ),
                CollapsibleSection(
                  title: 'لنډ وضاحت',
                  icon: Icons.notes_rounded,
                  child: _SummaryField(event: e, onChanged: widget.onChanged),
                ),
                CollapsibleSection(
                  title: 'درجه',
                  icon: Icons.star_rounded,
                  badge: e.rating == 0 ? null : PashtoDigits.to(e.rating),
                  child: Row(
                    children: [
                      StarRating(
                        value: e.rating,
                        size: 24,
                        onChanged: (v) => widget.onChanged(() => e.rating = v),
                      ),
                      const SizedBox(width: AppTokens.s12),
                      Text(
                        e.rating == 0 ? 'بې درجې' : '${e.rating} / ۵',
                        style: TextStyle(
                            fontSize: 11.5, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                CollapsibleSection(
                  title: 'رنګ ټګ',
                  icon: Icons.palette_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ColorTagPicker(
                        value: e.colorTag,
                        onChanged: (c) =>
                            widget.onChanged(() => e.colorTag = c),
                      ),
                      ColorTagMeaning(value: e.colorTag),
                    ],
                  ),
                ),
                CollapsibleSection(
                  title: 'کټګوري',
                  icon: Icons.category_rounded,
                  badge: e.category.isEmpty ? null : '۱',
                  child: _VocabField(
                    suggestions: _categories,
                    selected: e.category.isEmpty ? const [] : [e.category],
                    hint: 'کټګوري ولټوئ یا نوې ولیکئ…',
                    single: true,
                    onAdd: (v) => _addTerm(VocabKind.category, v),
                    onToggle: (v) => widget.onChanged(
                        () => e.category = e.category == v ? '' : v),
                  ),
                ),
                CollapsibleSection(
                  title: 'کیورډونه',
                  icon: Icons.sell_rounded,
                  badge: e.keywords.isEmpty
                      ? null
                      : PashtoDigits.to(e.keywords.length),
                  child: _VocabField(
                    suggestions: _keywords,
                    selected: e.keywords,
                    hint: 'کیورډ ولټوئ یا نوی ولیکئ…',
                    prefix: '#',
                    onAdd: (v) => _addTerm(VocabKind.keyword, v),
                    onToggle: (v) => widget.onChanged(() {
                      e.keywords.contains(v)
                          ? e.keywords.remove(v)
                          : e.keywords.add(v);
                    }),
                  ),
                ),
                CollapsibleSection(
                  title: 'شخصیتونه',
                  icon: Icons.groups_rounded,
                  badge: e.persons.isEmpty
                      ? null
                      : PashtoDigits.to(e.persons.length),
                  child: _VocabField(
                    suggestions: _persons,
                    selected: e.persons,
                    hint: 'شخصیت ولټوئ یا نوی ولیکئ…',
                    onAdd: (v) => _addTerm(VocabKind.person, v),
                    onToggle: (v) => widget.onChanged(() {
                      e.persons.contains(v)
                          ? e.persons.remove(v)
                          : e.persons.add(v);
                    }),
                  ),
                ),
                CollapsibleSection(
                  title: 'تاریخ',
                  icon: Icons.event_rounded,
                  child: TriDateField(
                    label: '',
                    value: e.date,
                    onChanged: (d) => widget.onChanged(() => e.date = d),
                  ),
                ),
                CollapsibleSection(
                  title: 'ضمیمې',
                  icon: Icons.perm_media_rounded,
                  badge: e.attachmentCount == 0
                      ? null
                      : PashtoDigits.to(e.attachmentCount),
                  child: _AttachmentSummary(event: e),
                ),
                const SizedBox(height: AppTokens.s40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleField extends StatefulWidget {
  const _TitleField({required this.event, required this.onChanged});
  final EventMetadata event;
  final void Function(void Function()) onChanged;

  @override
  State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  late final _c = TextEditingController(text: widget.event.title);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        onChanged: (v) => widget.onChanged(() => widget.event.title = v),
        decoration: const InputDecoration(isDense: true),
      );
}

class _SummaryField extends StatefulWidget {
  const _SummaryField({required this.event, required this.onChanged});
  final EventMetadata event;
  final void Function(void Function()) onChanged;

  @override
  State<_SummaryField> createState() => _SummaryFieldState();
}

class _SummaryFieldState extends State<_SummaryField> {
  late final _c = TextEditingController(text: widget.event.summary);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        maxLines: 3,
        style: const TextStyle(fontSize: 12.5, height: 1.7),
        onChanged: (v) => widget.onChanged(() => widget.event.summary = v),
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'د پیښې لنډه خلاصه…',
        ),
      );
}

/// د لغتونو ساحه — ټاکل شوي چیپونه + وړاندیزونه + د نوي ثبت.
class _VocabField extends StatefulWidget {
  const _VocabField({
    required this.suggestions,
    required this.selected,
    required this.hint,
    required this.onAdd,
    required this.onToggle,
    this.prefix = '',
    this.single = false,
  });

  final List<VocabTerm> suggestions;
  final List<String> selected;
  final String hint;
  final Future<void> Function(String) onAdd;
  final ValueChanged<String> onToggle;
  final String prefix;
  final bool single;

  @override
  State<_VocabField> createState() => _VocabFieldState();
}

class _VocabFieldState extends State<_VocabField> {
  final _c = TextEditingController();
  final _focus = FocusNode();
  bool _expanded = false;

  /// څومره وړاندیز په ډیفالټ کې ښکاري (تر «ټول وښایه» دمخه).
  static const _visible = 10;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit([String? forced]) async {
    final v = (forced ?? _c.text).trim();
    if (v.isEmpty) return;
    _c.clear();
    setState(() {});
    await widget.onAdd(v);
  }

  /// هغه توکي چې لا نه دي ټاکل شوي.
  List<VocabTerm> get _available => widget.suggestions
      .where((t) => !widget.selected.contains(t.name))
      .toList();

  /// **ژوندی وړاندیز** — د لیکل شوي متن مطابق، په ترتیب سره.
  ///
  /// دقیق مطابقت مخکې، بیا هغه چې له پیل څخه سمون خوري. که د
  /// ۱۰۰۰ کیورډونو منځ کې «کاب» ولیکئ، «کابل» به لومړی وي.
  List<VocabTerm> _matches(String q) {
    final scored = <(int, VocabTerm)>[];
    for (final t in _available) {
      final sc = matchScore(t.name, q);
      if (sc >= 0) scored.add((sc, t));
    }
    scored.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : b.$2.usageCount.compareTo(a.$2.usageCount);
    });
    return [for (final e in scored) e.$2];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typed = _c.text.trim();

    // د لیکلو پر مهال: ژوندی لیست. بې لیکلو: ډېر کارېدونکي چپونه.
    final live = typed.isEmpty ? const <VocabTerm>[] : _matches(typed);
    final exact = live.any((t) => searchKey(t.name) == searchKey(typed));

    final byUse = _available
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    final chips = _expanded ? byUse : byUse.take(_visible).toList();
    final hidden = byUse.length - chips.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── ټاکل شوي ──
        if (widget.selected.isNotEmpty) ...[
          Wrap(
            spacing: AppTokens.s6,
            runSpacing: AppTokens.s6,
            children: [
              for (final v in widget.selected)
                SelectChip(
                  label: '${widget.prefix}$v',
                  selected: true,
                  onTap: () => widget.onToggle(v),
                  onDelete: () => widget.onToggle(v),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
        ],

        // ── د لیکلو فیلډ ──
        //
        // دا فیلډ **دوه کاره** کوي: هم لټون، هم د نوي توکي جوړول.
        // نو که ۱۰۰۰ کیورډونه ولرو، اړتیا نشته چې ټول وګورو —
        // نوم یې ولیکه، وړاندیز به راشي.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                focusNode: _focus,
                style: const TextStyle(fontSize: 12),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  // که د لیکل شوي متن سره یو موجود توکی سم وي،
                  // هماغه غوره کوو — نو تکرار نه جوړیږي.
                  if (live.isNotEmpty && !exact) {
                    widget.onToggle(live.first.name);
                    _c.clear();
                    setState(() {});
                  } else {
                    _submit();
                  }
                },
                decoration: InputDecoration(
                  hintText: widget.hint,
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 15, color: cs.onSurfaceVariant),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  suffixIcon: typed.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 26, minHeight: 26),
                          onPressed: () {
                            _c.clear();
                            setState(() {});
                          },
                        ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  hintStyle:
                      TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'نوی ثبت کړه',
              child: InkWell(
                onTap: typed.isEmpty ? null : () => _submit(),
                borderRadius: AppTokens.brSm,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typed.isEmpty
                        ? cs.surfaceContainer
                        : cs.primary.withValues(alpha: 0.14),
                    borderRadius: AppTokens.brSm,
                  ),
                  child: Icon(Icons.add_rounded,
                      size: 16,
                      color: typed.isEmpty ? cs.onSurfaceVariant : cs.primary),
                ),
              ),
            ),
          ],
        ),

        // ── ژوندی وړاندیز (د لیکلو پر مهال) ──
        if (typed.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 190),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: AppTokens.brSm,
              border: Border.all(color: cs.outlineVariant),
            ),
            child: live.isEmpty
                ? _NewTermRow(text: typed, prefix: widget.prefix,
                    onTap: () => _submit())
                : ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final t in live.take(30))
                        _SuggestionRow(
                          term: t,
                          prefix: widget.prefix,
                          query: typed,
                          onTap: () {
                            widget.onToggle(t.name);
                            _c.clear();
                            setState(() {});
                          },
                        ),
                      // که دقیق سمون نه وي، د نوي جوړولو کرښه هم راشي
                      if (!exact)
                        _NewTermRow(text: typed, prefix: widget.prefix,
                            onTap: () => _submit()),
                    ],
                  ),
          ),
        ],

        // ── ډېر کارېدونکي (بې لیکلو) ──
        if (typed.isEmpty && chips.isNotEmpty) ...[
          const SizedBox(height: AppTokens.s8),
          Wrap(
            spacing: AppTokens.s6,
            runSpacing: AppTokens.s6,
            children: [
              for (final t in chips)
                SelectChip(
                  label: '${widget.prefix}${t.name}',
                  selected: false,
                  count: t.usageCount > 0 ? t.usageCount : null,
                  onTap: () => widget.onToggle(t.name),
                ),
              // **یوولسم توکی** — رنګی او متفاوت.
              if (hidden > 0 || _expanded)
                _ShowAllChip(
                  expanded: _expanded,
                  hidden: hidden,
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// د وړاندیز یوه کرښه — سمون‌خوړونکې برخه یې پړسېدلې ښکاري.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.term,
    required this.prefix,
    required this.query,
    required this.onTap,
  });

  final VocabTerm term;
  final String prefix;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Icon(Icons.north_west_rounded,
                size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: _Highlighted(
                text: '$prefix${term.name}',
                query: query,
                base: TextStyle(fontSize: 12, color: cs.onSurface),
                hit: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cs.primary),
              ),
            ),
            if (term.usageCount > 0)
              Text(
                PashtoDigits.to(term.usageCount),
                style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// «نوی جوړ کړه» کرښه.
class _NewTermRow extends StatelessWidget {
  const _NewTermRow(
      {required this.text, required this.prefix, required this.onTap});

  final String text;
  final String prefix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 14, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'نوی جوړ کړه: «$prefix$text»',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: cs.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// د سمون‌خوړونکې برخې پړسول.
class _Highlighted extends StatelessWidget {
  const _Highlighted({
    required this.text,
    required this.query,
    required this.base,
    required this.hit,
  });

  final String text;
  final String query;
  final TextStyle base;
  final TextStyle hit;

  @override
  Widget build(BuildContext context) {
    // د نورمال شوي متن پر سر لټوو، خو **اصلي** متن ښیو — نو
    // «كابل» او «کابل» دواړه سم پړسیږي.
    final n = searchKey(text);
    final q = searchKey(query);
    final at = q.isEmpty ? -1 : n.indexOf(q);
    if (at < 0 || n.length != text.length) {
      return Text(text, style: base, overflow: TextOverflow.ellipsis);
    }
    // **`Text.rich` او نه `RichText`.**
    //
    // د `RichText` ریښه‌یی `TextSpan` که سټایل ونه لري، فونټ نه
    // ټاکل کیږي — نو CanvasKit یو داسې فونټ ټاکي چې پښتو حروف
    // نه لري او متن **بیخي نه رسمیږي** (تشه کرښه). دا په ازموینو
    // کې نه ښکاري، ځکه هلته بل رینډرر دی. `Text.rich` ریښه ته
    // سټایل ورکوي، نو فونټ تل معلوم وي.
    return Text.rich(
      TextSpan(children: [
        if (at > 0) TextSpan(text: text.substring(0, at), style: base),
        TextSpan(text: text.substring(at, at + q.length), style: hit),
        if (at + q.length < text.length)
          TextSpan(text: text.substring(at + q.length), style: base),
      ]),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// **«ټول وښایه»** — یوولسم، رنګی او متفاوت توکی.
class _ShowAllChip extends StatelessWidget {
  const _ShowAllChip({
    required this.expanded,
    required this.hidden,
    required this.onTap,
  });

  final bool expanded;
  final int hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: cs.primary,
            ),
            const SizedBox(width: 4),
            Text(
              expanded ? 'لږ وښایه' : 'ټول وښایه (${PashtoDigits.to(hidden)})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentSummary extends StatelessWidget {
  const _AttachmentSummary({required this.event});
  final EventMetadata event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (event.attachments.isEmpty) {
      return Text('لا هیڅ فایل نه دی ضمیمه شوی',
          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant));
    }
    final by = event.mediaBreakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppTokens.s6,
          runSpacing: AppTokens.s6,
          children: [
            for (final e in by.entries)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: mediaColor(e.key).withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mediaIcon(e.key), size: 12, color: mediaColor(e.key)),
                    const SizedBox(width: 4),
                    Text('${e.value} ${e.key.label}',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: mediaColor(e.key))),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.s8),
        Text('ټوله اندازه: ${humanBytes(event.totalBytes)}',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
