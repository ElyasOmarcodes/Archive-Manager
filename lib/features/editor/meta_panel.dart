import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                // ── نوم ──
                const SectionLabel('د پیښې نوم', icon: Icons.title_rounded),
                _TitleField(event: e, onChanged: widget.onChanged),

                const SizedBox(height: AppTokens.s20),
                const SectionLabel('لنډ وضاحت', icon: Icons.notes_rounded),
                _SummaryField(event: e, onChanged: widget.onChanged),

                const SizedBox(height: AppTokens.s20),
                const SectionLabel('درجه', icon: Icons.star_rounded),
                Row(
                  children: [
                    StarRating(
                      value: e.rating,
                      size: 24,
                      onChanged: (v) =>
                          widget.onChanged(() => e.rating = v),
                    ),
                    const SizedBox(width: AppTokens.s12),
                    Text(
                      e.rating == 0 ? 'بې درجې' : '${e.rating} / ۵',
                      style: TextStyle(
                          fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),

                const SizedBox(height: AppTokens.s20),
                const SectionLabel('رنګ ټګ', icon: Icons.palette_rounded),
                ColorTagPicker(
                  value: e.colorTag,
                  onChanged: (c) => widget.onChanged(() => e.colorTag = c),
                ),

                const SizedBox(height: AppTokens.s20),
                const SectionLabel('کټګوري', icon: Icons.category_rounded),
                _VocabField(
                  suggestions: _categories,
                  selected: e.category.isEmpty ? const [] : [e.category],
                  hint: 'کټګوري ولیکئ یا وټاکئ…',
                  single: true,
                  onAdd: (v) => _addTerm(VocabKind.category, v),
                  onToggle: (v) => widget.onChanged(
                      () => e.category = e.category == v ? '' : v),
                ),

                const SizedBox(height: AppTokens.s20),
                const SectionLabel('کیورډونه', icon: Icons.sell_rounded),
                _VocabField(
                  suggestions: _keywords,
                  selected: e.keywords,
                  hint: 'نوی کیورډ ولیکئ…',
                  prefix: '#',
                  onAdd: (v) => _addTerm(VocabKind.keyword, v),
                  onToggle: (v) => widget.onChanged(() {
                    e.keywords.contains(v)
                        ? e.keywords.remove(v)
                        : e.keywords.add(v);
                  }),
                ),

                const SizedBox(height: AppTokens.s20),
                const SectionLabel('شخصیتونه', icon: Icons.groups_rounded),
                _VocabField(
                  suggestions: _persons,
                  selected: e.persons,
                  hint: 'د شخص نوم ولیکئ…',
                  onAdd: (v) => _addTerm(VocabKind.person, v),
                  onToggle: (v) => widget.onChanged(() {
                    e.persons.contains(v)
                        ? e.persons.remove(v)
                        : e.persons.add(v);
                  }),
                ),

                const SizedBox(height: AppTokens.s20),
                const SectionLabel('تاریخ', icon: Icons.event_rounded),
                TriDateField(
                  label: '',
                  value: e.date,
                  onChanged: (d) => widget.onChanged(() => e.date = d),
                ),

                const SizedBox(height: AppTokens.s20),
                const SectionLabel('ضمیمې', icon: Icons.perm_media_rounded),
                _AttachmentSummary(event: e),

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
  bool _expanded = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    _c.clear();
    await widget.onAdd(v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typed = _c.text.trim();

    var available = widget.suggestions
        .where((t) => !widget.selected.contains(t.name))
        .where((t) => typed.isEmpty || t.name.contains(typed))
        .toList();
    final shown = _expanded ? available : available.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ټاکل شوي
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

        // نوی ثبت
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                style: const TextStyle(fontSize: 12),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 9),
                  hintStyle:
                      TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _submit,
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
          ],
        ),

        // وړاندیزونه
        if (shown.isNotEmpty) ...[
          const SizedBox(height: AppTokens.s8),
          Wrap(
            spacing: AppTokens.s6,
            runSpacing: AppTokens.s6,
            children: [
              for (final t in shown)
                SelectChip(
                  label: '${widget.prefix}${t.name}',
                  selected: false,
                  count: t.usageCount > 0 ? t.usageCount : null,
                  onTap: () => widget.onToggle(t.name),
                ),
              if (available.length > 6)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero),
                  child: Text(
                    _expanded ? 'لږ' : '+${available.length - 6}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ],
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
