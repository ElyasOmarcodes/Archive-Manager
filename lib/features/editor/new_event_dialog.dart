import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/text/pashto_text.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/tri_date_picker.dart';

/// د نوې پیښې ډیالوګ پرانیزي — د ډاشبورډ، پیښو او اکسپلورر څخه.
Future<void> showNewEventDialog(BuildContext context, {String? manualParent}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: NewEventDialog(initialManualParent: manualParent),
    ),
  );
}

/// **د پیښې د جوړولو ډیالوګ.**
class NewEventDialog extends StatefulWidget {
  const NewEventDialog({super.key, this.initialManualParent});

  final String? initialManualParent;

  @override
  State<NewEventDialog> createState() => _NewEventDialogState();
}

class _NewEventDialogState extends State<NewEventDialog> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _newCategory = TextEditingController();

  TriDate _date = TriDate.now();
  String _category = '';
  bool _auto = true;
  String? _manualParent;
  List<VocabTerm> _categories = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _manualParent = widget.initialManualParent;
    if (widget.initialManualParent != null) _auto = false;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final list = await context.read<AppState>().vocab(VocabKind.category);
    if (mounted) setState(() => _categories = list);
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  /// د لیکل شوي متن مطابق موجودې کټګورۍ، په ترتیب سره.
  List<VocabTerm> get _categoryMatches {
    final q = _newCategory.text.trim();
    if (q.isEmpty) return const [];
    final scored = <(int, VocabTerm)>[];
    for (final t in _categories) {
      final sc = matchScore(t.name, q);
      if (sc >= 0) scored.add((sc, t));
    }
    scored.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : b.$2.usageCount.compareTo(a.$2.usageCount);
    });
    return [for (final e in scored) e.$2];
  }

  /// آیا لیکل شوی متن دقیقاً یوې موجودې کټګورۍ سره برابر دی؟
  bool get _categoryExact {
    final q = searchKey(_newCategory.text);
    return _categories.any((t) => searchKey(t.name) == q);
  }

  /// نوې کټګوري ثبتوي — سمدلاسه هم په لیست کې ښکاري او هم ټاکل کیږي.
  Future<void> _addCategory() async {
    final name = _newCategory.text.trim();
    if (name.isEmpty) return;
    await context.read<AppState>().addVocab(VocabKind.category, name);
    _newCategory.clear();
    await _loadCategories();
    if (mounted) setState(() => _category = name);
  }

  Future<void> _pickManualFolder() async {
    final s = context.read<AppState>();
    final picked = await s.backend.pickDirectory(
        initial: _manualParent ?? s.settings.archiveRoot);
    if (picked != null && mounted) {
      setState(() {
        _manualParent = picked;
        _auto = false;
      });
    }
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'د پیښې نوم اړین دی');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final s = context.read<AppState>();
    final root = s.settings.archiveRoot!;

    try {
      final folder = await s.backend.prepareEventFolder(
        root: root,
        title: title,
        dateJdn: _date.jdn,
        auto: _auto,
        manualParent: _manualParent,
      );

      final event = EventMetadata(
        id: 'ev-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        folderPath: folder,
        date: _date,
        category: _category,
        summary: _summary.text.trim(),
        blocks: [
          // د پیل لپاره یو عنوان — کاروونکی سمدلاسه لیکل پیلولی شي.
          Block(
              id: 'b-${DateTime.now().microsecondsSinceEpoch}',
              kind: BlockKind.heading,
              text: title,
              level: 1),
        ],
      );

      await s.saveEvent(event);
      if (!mounted) return;
      Navigator.pop(context);
      // سمدلاسه د طراحۍ پاڼې ته ولاړ شه.
      s.openEditor(event);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'د فولډر جوړولو کې ستونزه: $e';
        });
      }
    }
  }

  /// د اتومات حالت د مسیر مخکتنه.
  String get _previewPath {
    final s = context.read<AppState>();
    final root = s.settings.archiveRoot ?? r'E:\Arvitch';
    final name = _title.text.trim().isEmpty ? '‹د پیښې نوم›' : _title.text.trim();
    if (!_auto) return '${_manualParent ?? root}\\$name';
    return '$root\\${_date.shamsi.year}\\'
        '${PashtoMonths.shamsiDari[_date.shamsi.month - 1]}\\'
        '${_date.shamsi.day}\\$name';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── سرلیک ──
            Container(
              padding: const EdgeInsets.all(AppTokens.s20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    AppTokens.brand.withValues(alpha: 0.12),
                    AppTokens.brandAlt.withValues(alpha: 0.06),
                  ],
                ),
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppTokens.brand, AppTokens.brandAlt]),
                      borderRadius: AppTokens.brMd,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: AppTokens.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('نوې پیښه ثبت کړئ',
                            style: t.textTheme.titleLarge),
                        Text('فولډر او میټاډیټا پخپله جوړیږي',
                            style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed:
                        _busy ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── بدنه ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTokens.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, 'د پیښې نوم', required: true),
                    const SizedBox(height: AppTokens.s8),
                    TextField(
                      controller: _title,
                      autofocus: true,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        hintText: 'بېلګه: د کابل او چین تړون',
                        errorText: _error,
                        helperText: 'همدا به د پیښې د فولډر نوم هم وي',
                        helperStyle: TextStyle(
                            fontSize: 10.5, color: cs.onSurfaceVariant),
                      ),
                    ),

                    const SizedBox(height: AppTokens.s20),
                    _label(context, 'کټګوري'),
                    const SizedBox(height: AppTokens.s8),
                    _CategoryChips(
                      categories: _categories,
                      selected: _category,
                      onSelect: (c) => setState(
                          () => _category = _category == c ? '' : c),
                    ),
                    const SizedBox(height: AppTokens.s8),
                    // **لټون + نوې ثبتونه، یو فیلډ کې.**
                    //
                    // پخوا دا یوازې «نوې اضافه کړه» و، نو که ۱۰۰
                    // کټګورۍ وای، کاروونکی باید ټولې چپونه وکتلې
                    // وای. اوس د لیکلو پر مهال وړاندیز راځي —
                    // هماغه چلند چې د ایډیټ پنل کې دی.
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newCategory,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              // که یو موجود سمون ولري، هغه غوره کوو —
                              // نو تکرار نه جوړیږي.
                              final m = _categoryMatches;
                              if (m.isNotEmpty && !_categoryExact) {
                                setState(() {
                                  _category = m.first.name;
                                  _newCategory.clear();
                                });
                              } else {
                                _addCategory();
                              }
                            },
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'کټګوري ولټوئ یا نوې ولیکئ…',
                              isDense: true,
                              prefixIcon: const Icon(Icons.search_rounded,
                                  size: 15),
                              prefixIconConstraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 30),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.s8),
                        IconButton.filledTonal(
                          onPressed: _addCategory,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          tooltip: 'نوې کټګوري اضافه کړه',
                        ),
                      ],
                    ),
                    if (_newCategory.text.trim().isNotEmpty)
                      _CategorySuggestions(
                        matches: _categoryMatches,
                        typed: _newCategory.text.trim(),
                        exact: _categoryExact,
                        onPick: (name) => setState(() {
                          _category = name;
                          _newCategory.clear();
                        }),
                        onCreate: _addCategory,
                      ),

                    const SizedBox(height: AppTokens.s20),
                    TriDateField(
                      value: _date,
                      onChanged: (d) => setState(() => _date = d),
                    ),

                    const SizedBox(height: AppTokens.s20),
                    _label(context, 'لنډ وضاحت (اختیاري)'),
                    const SizedBox(height: AppTokens.s8),
                    TextField(
                      controller: _summary,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'د پیښې په اړه یوه یا دوه کرښې…',
                      ),
                    ),

                    const SizedBox(height: AppTokens.s20),
                    _label(context, 'د پیښې فولډر'),
                    const SizedBox(height: AppTokens.s8),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeTile(
                            icon: Icons.auto_mode_rounded,
                            title: 'اتومات',
                            subtitle: 'کال / میاشت / ورځ',
                            selected: _auto,
                            onTap: () => setState(() => _auto = true),
                          ),
                        ),
                        const SizedBox(width: AppTokens.s12),
                        Expanded(
                          child: _ModeTile(
                            icon: Icons.drive_file_move_rounded,
                            title: 'لاسي',
                            subtitle: 'مسیر پخپله وټاکه',
                            selected: !_auto,
                            onTap: _pickManualFolder,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTokens.s12),
                    // د مسیر مخکتنه
                    AnimatedContainer(
                      duration: AppTokens.base,
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTokens.s12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: AppTokens.brMd,
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.folder_rounded,
                                  size: 13, color: cs.primary),
                              const SizedBox(width: 6),
                              Text('دا فولډر به جوړ شي:',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            _previewPath,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── عملونه ──
            Container(
              padding: const EdgeInsets.all(AppTokens.s16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'تر جوړېدو وروسته سمدلاسه د طراحۍ پاڼې ته ځئ',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('لغوه'),
                  ),
                  const SizedBox(width: AppTokens.s8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: _busy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('پیښه جوړه کړه'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text, {bool required = false}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(text,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
        if (required)
          Text(' *', style: TextStyle(fontSize: 12, color: cs.error)),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<VocabTerm> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Text('لا هیڅ کټګوري نه ده ثبت شوې — لاندې یې اضافه کړئ',
          style: Theme.of(context).textTheme.bodySmall);
    }
    return Wrap(
      spacing: AppTokens.s8,
      runSpacing: AppTokens.s8,
      children: [
        for (final c in categories)
          SelectChip(
            label: c.name,
            selected: selected == c.name,
            count: c.usageCount > 0 ? c.usageCount : null,
            onTap: () => onSelect(c.name),
          ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.brMd,
      child: AnimatedContainer(
        duration: AppTokens.base,
        curve: AppTokens.ease,
        padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s12, vertical: AppTokens.s12),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.10)
              : cs.surfaceContainer,
          borderRadius: AppTokens.brMd,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 19, color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: AppTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? cs.primary : cs.onSurface)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 10.5, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

/// د کټګورۍ ژوندی وړاندیز — د ایډیټ پنل په څېر.
class _CategorySuggestions extends StatelessWidget {
  const _CategorySuggestions({
    required this.matches,
    required this.typed,
    required this.exact,
    required this.onPick,
    required this.onCreate,
  });

  final List<VocabTerm> matches;
  final String typed;
  final bool exact;
  final ValueChanged<String> onPick;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 172),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppTokens.brSm,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final t in matches.take(20))
            InkWell(
              onTap: () => onPick(t.name),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  children: [
                    Icon(Icons.north_west_rounded,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    if (t.usageCount > 0)
                      Text(PashtoDigits.to(t.usageCount),
                          style: TextStyle(
                              fontSize: 10.5, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          if (!exact)
            InkWell(
              onTap: onCreate,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 14, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('نوې جوړه کړه: «$typed»',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: cs.primary)),
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
