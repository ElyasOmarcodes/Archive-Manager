import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/models/query.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **د کیورډونو / اشخاصو / کټګوریو مدیریت پاڼه.**
///
/// یو نوم چې دلته بدل شي، په ټوله میټاډیټا کې سمدلاسه تازه کیږي —
/// یوازې هغه پیښې بیا لیکل کیږي چې دا لغت کاروي.
class VocabPage extends StatefulWidget {
  const VocabPage({super.key, required this.kind});
  final VocabKind kind;

  @override
  State<VocabPage> createState() => _VocabPageState();
}

class _VocabPageState extends State<VocabPage> {
  final _search = TextEditingController();
  final _add = TextEditingController();
  List<VocabTerm> _terms = const [];
  bool _loading = true;
  _SortBy _sort = _SortBy.usage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VocabPage old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _add.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await context.read<AppState>().vocab(widget.kind);
    if (mounted) {
      setState(() {
        _terms = list;
        _loading = false;
      });
    }
  }

  IconData get _icon => switch (widget.kind) {
        VocabKind.keyword => Icons.sell_rounded,
        VocabKind.person => Icons.groups_rounded,
        VocabKind.category => Icons.category_rounded,
      };

  String get _prefix => widget.kind == VocabKind.keyword ? '#' : '';

  List<VocabTerm> get _visible {
    final q = _search.text.trim();
    var list = q.isEmpty
        ? [..._terms]
        : _terms.where((t) => t.name.contains(q)).toList();
    list.sort((a, b) => switch (_sort) {
          _SortBy.usage => b.usageCount.compareTo(a.usageCount),
          _SortBy.name => a.name.compareTo(b.name),
          _SortBy.unused => a.usageCount.compareTo(b.usageCount),
        });
    return list;
  }

  Future<void> _addTerm() async {
    final v = _add.text.trim();
    if (v.isEmpty) return;
    if (_terms.any((t) => t.name == v)) {
      toast(context, 'دا ${widget.kind.singular} مخکې ثبت دی', error: true);
      return;
    }
    _add.clear();
    await context.read<AppState>().addVocab(widget.kind, v);
    await _load();
    if (mounted) toast(context, '«$v» اضافه شو');
  }

  Future<void> _rename(VocabTerm t) async {
    // د async تشې دمخه یې نیسو — وروسته context ممکن نور معتبر نه وي.
    final state = context.read<AppState>();
    final ctl = TextEditingController(text: t.name);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('${widget.kind.singular} ایډیټ کړئ'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: ctl,
                    autofocus: true,
                    onSubmitted: (x) => Navigator.pop(ctx, x)),
                if (t.usageCount > 0) ...[
                  const SizedBox(height: AppTokens.s16),
                  Container(
                    padding: const EdgeInsets.all(AppTokens.s12),
                    decoration: BoxDecoration(
                      color: AppTokens.amber.withValues(alpha: 0.11),
                      borderRadius: AppTokens.brMd,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 15, color: AppTokens.amber),
                        const SizedBox(width: AppTokens.s8),
                        Expanded(
                          child: Text(
                            'دا نوم په ${PashtoDigits.to(t.usageCount)} '
                            'پیښو کې کارول شوی — ټولې به پخپله تازه شي.',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('لغوه')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctl.text),
                child: const Text('ثبت کړه')),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (v == null || v.trim().isEmpty || v.trim() == t.name) return;

    final n = await state.renameVocab(widget.kind, t.name, v.trim());
    await _load();
    if (mounted) {
      toast(context,
          n == 0 ? 'نوم بدل شو' : '${PashtoDigits.to(n)} پیښې تازه شوې');
    }
  }

  Future<void> _delete(VocabTerm t) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف تایید کړئ'),
          content: Text(t.usageCount == 0
              ? '«${t.name}» به له لیسته لرې شي.'
              : '«${t.name}» په ${PashtoDigits.to(t.usageCount)} پیښو کې '
                  'کارول شوی. یوازې له لیسته لرې کیږي — د پیښو میټاډیټا '
                  'نه بدلیږي.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('لغوه')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              child: const Text('حذف کړه'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await state.deleteVocab(widget.kind, t.name);
    await _load();
    if (mounted) toast(context, '«${t.name}» حذف شو');
  }

  /// دا لغت د فلټر په توګه پلې کوي او پیښو پاڼې ته ځي.
  void _showUsage(VocabTerm t) {
    final s = context.read<AppState>();
    s.go(AppPage.events);
    s.setQuery(switch (widget.kind) {
      VocabKind.keyword => const EventQuery().copyWith(keywords: {t.name}),
      VocabKind.person => const EventQuery().copyWith(persons: {t.name}),
      VocabKind.category => const EventQuery().copyWith(categories: {t.name}),
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _visible;
    final unused = _terms.where((t) => t.usageCount == 0).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTokens.s24, AppTokens.s24, AppTokens.s24, AppTokens.s16),
          child: Column(
            children: [
              PageHeader(
                icon: _icon,
                title: 'د ${widget.kind.plural} مدیریت',
                subtitle: _loading
                    ? 'بارېږي…'
                    : '${PashtoDigits.to(_terms.length)} ${widget.kind.plural}'
                        '${unused > 0 ? '  ·  ${PashtoDigits.to(unused)} ناکارول شوي' : ''}',
              ),
              const SizedBox(height: AppTokens.s16),
              Row(
                children: [
                  Expanded(
                    child: SearchBox(
                      controller: _search,
                      hint: 'په ${widget.kind.plural} کې ولټوه…',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppTokens.s12),
                  PopupMenuButton<_SortBy>(
                    tooltip: 'ترتیب',
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => [
                      for (final s in _SortBy.values)
                        PopupMenuItem(value: s, child: Text(s.label)),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.s12, vertical: 9),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: AppTokens.brMd,
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_rounded, size: 15),
                          const SizedBox(width: 5),
                          Text(_sort.label,
                              style: const TextStyle(fontSize: 12)),
                          const Icon(Icons.expand_more_rounded, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.s12),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _add,
                      onSubmitted: (_) => _addTerm(),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'نوی ${widget.kind.singular}…',
                        prefixIcon: Icon(_icon, size: 17),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 38, minHeight: 36),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          onPressed: _addTerm,
                          splashRadius: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? EmptyState(
                      icon: _icon,
                      title: _search.text.isEmpty
                          ? 'لا هیڅ ${widget.kind.singular} نه دی ثبت شوی'
                          : 'هیڅ پایله ونه موندل شوه',
                      message: _search.text.isEmpty
                          ? 'د پورتنۍ ساحې له لارې یې اضافه کړئ، یا د '
                              'پیښې په ثبت کې پخپله جوړیږي.'
                          : null,
                    )
                  : _TermGrid(
                      items: items,
                      prefix: _prefix,
                      icon: _icon,
                      onEdit: _rename,
                      onDelete: _delete,
                      onShow: _showUsage,
                    ),
        ),
      ],
    );
  }
}

enum _SortBy {
  usage('ډېر کارول شوي'),
  name('الفبا'),
  unused('لږ کارول شوي');

  const _SortBy(this.label);
  final String label;
}

/// **د لغتونو ګریډ** — د کرښې پر ځای فشرده کارتونه.
///
/// پخوا هر کیورډ یوه بشپړه کرښه نیوله، نو د ۳۶ کیورډونو لیست
/// اوږد او تش ښکارېده. اوس هر کارت ~۲۶۰px دی، نو په یوه پرده کې
/// لسګونه ښکاري. ګریډ `builder` دی، نو د زرګونو لغتونو لیست هم
/// یوازې هغه څه جوړوي چې پر پردې دي.
class _TermGrid extends StatelessWidget {
  const _TermGrid({
    required this.items,
    required this.prefix,
    required this.icon,
    required this.onEdit,
    required this.onDelete,
    required this.onShow,
  });

  final List<VocabTerm> items;
  final String prefix;
  final IconData icon;
  final void Function(VocabTerm) onEdit, onDelete, onShow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = AppTokens.s12;
      final cols = (c.maxWidth / 280).floor().clamp(1, 6);
      final w = (c.maxWidth - AppTokens.s24 * 2 - gap * (cols - 1)) / cols;
      final rows = (items.length + cols - 1) ~/ cols;

      return ListView.builder(
        padding: const EdgeInsets.all(AppTokens.s24),
        itemCount: rows,
        itemBuilder: (context, r) {
          final start = r * cols;
          final end = (start + cols).clamp(0, items.length);
          return Padding(
            padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : gap),
            // `IntrinsicHeight` اړین دی: `stretch` بوله لوړوالی غواړي،
            // خو د `ListView` دننه لوړوالی نامحدود دی. له دې پرته
            // هر layout یوه استثنا اچوي.
            child: IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < end; i++) ...[
                  if (i != start) const SizedBox(width: gap),
                  SizedBox(
                    width: w,
                    child: FadeSlideIn(
                      delay: AppTokens.staggerFor(i - start),
                      child: _TermCard(
                        term: items[i],
                        prefix: prefix,
                        icon: icon,
                        onEdit: () => onEdit(items[i]),
                        onDelete: () => onDelete(items[i]),
                        onShow: () => onShow(items[i]),
                      ),
                    ),
                  ),
                ],
                // وروستۍ کرښه ډکه نه وي — پاتې ځای تش پرېږده
                if (end - start < cols)
                  for (var k = end - start; k < cols; k++) ...[
                    const SizedBox(width: gap),
                    SizedBox(width: w),
                  ],
              ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({
    required this.term,
    required this.prefix,
    required this.icon,
    required this.onEdit,
    required this.onDelete,
    required this.onShow,
  });

  final VocabTerm term;
  final String prefix;
  final IconData icon;
  final VoidCallback onEdit, onDelete, onShow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unused = term.usageCount == 0;

    return HoverLift(
      lift: 2,
      onTap: unused ? null : onShow,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppTokens.fast,
        padding: const EdgeInsets.fromLTRB(
            AppTokens.s12, AppTokens.s12, AppTokens.s8, AppTokens.s8),
        decoration: BoxDecoration(
          color: hovered ? cs.surfaceContainer : cs.surfaceContainerLowest,
          borderRadius: AppTokens.brMd,
          border: Border.all(color: hovered ? cs.outline : cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: unused
                        ? cs.surfaceContainerHigh
                        : cs.primary.withValues(alpha: 0.11),
                    borderRadius: AppTokens.brSm,
                  ),
                  child: Icon(icon,
                      size: 14,
                      color: unused ? cs.onSurfaceVariant : cs.primary),
                ),
                const SizedBox(width: AppTokens.s8),
                Expanded(
                  child: Text(
                    '$prefix${term.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: unused
                        ? cs.surfaceContainerHigh
                        : AppTokens.green.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unused
                        ? 'نه کارول کیږي'
                        : '${PashtoDigits.to(term.usageCount)} پیښې',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: unused ? cs.onSurfaceVariant : AppTokens.green,
                    ),
                  ),
                ),
                const Spacer(),
                // د ځای ساتلو لپاره کوچني ایکنونه، بې پډنګه
                _MiniAction(
                  icon: Icons.edit_rounded,
                  tip: 'ایډیټ',
                  onTap: onEdit,
                ),
                _MiniAction(
                  icon: Icons.delete_outline_rounded,
                  tip: 'حذف',
                  color: cs.error,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.tip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.brSm,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 15, color: color ?? cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

