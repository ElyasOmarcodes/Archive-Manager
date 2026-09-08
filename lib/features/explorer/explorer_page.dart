import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/query.dart';
import '../../data/platform/backend.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../editor/new_event_dialog.dart';
import 'explorer_tree.dart';
import 'thumbnail.dart';

enum ExplorerView {
  grid('لوی آیکنونه', Icons.grid_view_rounded),
  list('لیست', Icons.view_list_rounded),
  details('تفصیل', Icons.table_rows_rounded);

  const ExplorerView(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum ExplorerSort {
  name('نوم'),
  size('اندازه'),
  modified('د بدلون نېټه'),
  type('ډول');

  const ExplorerSort(this.label);
  final String label;
}

/// **داخلي فایل اکسپلورر** — د وینډوز اکسپلورر بشپړ معادل.
class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final _pathCtl = TextEditingController();
  final _searchCtl = TextEditingController();
  final _focus = FocusNode();

  String _path = '';
  List<FsEntry> _entries = const [];
  bool _loading = false;

  final _selected = <String>{};
  String? _anchor;

  final _back = <String>[];
  final _forward = <String>[];

  ExplorerView _view = ExplorerView.grid;
  ExplorerSort _sort = ExplorerSort.name;
  bool _asc = true;
  bool _showTree = true;

  /// د کاپي/کټ کلپ‌بورډ.
  static final _clip = <String>[];
  static bool _clipCut = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final target = s.consumeExplorerTarget() ?? s.settings.archiveRoot ?? '';
    _open(target, push: false);
  }

  @override
  void dispose() {
    _pathCtl.dispose();
    _searchCtl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  //  ناوبري
  // ═══════════════════════════════════════════════════════

  Future<void> _open(String path, {bool push = true}) async {
    if (path.isEmpty) return;
    if (push && _path.isNotEmpty && _path != path) {
      _back.add(_path);
      _forward.clear();
    }
    setState(() {
      _path = path;
      _pathCtl.text = path;
      _loading = true;
      _selected.clear();
    });
    final list = await context.read<AppState>().backend.listDirectory(path);
    if (mounted) {
      setState(() {
        _entries = list;
        _loading = false;
      });
    }
  }

  void _goBack() {
    if (_back.isEmpty) return;
    _forward.add(_path);
    _open(_back.removeLast(), push: false);
  }

  void _goForward() {
    if (_forward.isEmpty) return;
    _back.add(_path);
    _open(_forward.removeLast(), push: false);
  }

  void _goUp() {
    final sep = _path.contains(r'\') ? r'\' : '/';
    final parts = _path.split(sep)..removeWhere((e) => e.isEmpty);
    if (parts.length <= 1) return;
    parts.removeLast();
    final up = _path.startsWith('/')
        ? '/${parts.join('/')}'
        : parts.join(sep) + (parts.length == 1 ? sep : '');
    _open(up);
  }

  // ═══════════════════════════════════════════════════════
  //  ټاکنه
  // ═══════════════════════════════════════════════════════

  List<FsEntry> get _visible {
    final q = _searchCtl.text.trim().toLowerCase();

    // **پټ فایلونه.** د پروګرام خپل ثبت فایلونه (`metadata.json`،
    // `content.json`) او هر څه چې وینډوز یې پټ ګڼي — یوازې هغه
    // وخت ښکاري چې کاروونکی یې د ټولبار له تڼۍ وغواړي.
    final showHidden = context.read<AppState>().settings.showHiddenFiles;
    final base =
        showHidden ? _entries : _entries.where((e) => !e.isHidden).toList();

    var list = q.isEmpty
        ? [...base]
        : base.where((e) => e.name.toLowerCase().contains(q)).toList();

    list.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      final r = switch (_sort) {
        ExplorerSort.name =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ExplorerSort.size => a.sizeBytes.compareTo(b.sizeBytes),
        ExplorerSort.modified => (a.modified ?? DateTime(0))
            .compareTo(b.modified ?? DateTime(0)),
        ExplorerSort.type => a.extension.compareTo(b.extension),
      };
      return _asc ? r : -r;
    });
    return list;
  }

  void _tap(FsEntry e, {bool ctrl = false, bool shift = false}) {
    setState(() {
      if (shift && _anchor != null) {
        final list = _visible;
        final a = list.indexWhere((x) => x.path == _anchor);
        final b = list.indexWhere((x) => x.path == e.path);
        if (a >= 0 && b >= 0) {
          _selected.clear();
          for (var i = a < b ? a : b; i <= (a < b ? b : a); i++) {
            _selected.add(list[i].path);
          }
        }
      } else if (ctrl) {
        _selected.contains(e.path)
            ? _selected.remove(e.path)
            : _selected.add(e.path);
        _anchor = e.path;
      } else {
        _selected
          ..clear()
          ..add(e.path);
        _anchor = e.path;
      }
    });
  }

  void _selectAll() =>
      setState(() => _selected.addAll(_visible.map((e) => e.path)));

  void _deselectAll() => setState(_selected.clear);

  void _invertSelection() => setState(() {
        final all = _visible.map((e) => e.path).toSet();
        final inv = all.difference(_selected);
        _selected
          ..clear()
          ..addAll(inv);
      });

  /// ټول د یو ډول فایلونه وټاکه — «End all type» چې غوښتل شوی و.
  void _selectSameType() {
    if (_selected.isEmpty) return;
    final exts = _visible
        .where((e) => _selected.contains(e.path))
        .map((e) => e.isDirectory ? '<dir>' : e.extension)
        .toSet();
    setState(() {
      for (final e in _visible) {
        if (exts.contains(e.isDirectory ? '<dir>' : e.extension)) {
          _selected.add(e.path);
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  //  عملیات
  // ═══════════════════════════════════════════════════════

  ArchiveBackend get _be => context.read<AppState>().backend;

  void _copy({bool cut = false}) {
    if (_selected.isEmpty) return;
    _clip
      ..clear()
      ..addAll(_selected);
    _clipCut = cut;
    toast(context,
        '${PashtoDigits.to(_clip.length)} توکي ${cut ? 'کټ' : 'کاپي'} شول');
  }

  Future<void> _paste() async {
    if (_clip.isEmpty) return;
    await _be.copyEntries(_clip, _path, move: _clipCut);
    if (_clipCut) _clip.clear();
    if (mounted) {
      toast(context, 'توکي ولېږدول شول');
      _open(_path, push: false);
    }
  }

  Future<void> _delete() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف تایید کړئ'),
          content: Text(
              '${PashtoDigits.to(_selected.length)} توکي به د تل لپاره '
              'حذف شي. دا کار بیرته نه ګرځي.'),
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
    await _be.deleteEntries(_selected.toList());
    if (mounted) {
      toast(context, 'توکي حذف شول');
      _open(_path, push: false);
    }
  }

  Future<void> _rename(FsEntry e) async {
    final ctl = TextEditingController(text: e.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نوم بدل کړئ'),
          content: SizedBox(
            width: 340,
            child: TextField(
                controller: ctl,
                autofocus: true,
                onSubmitted: (v) => Navigator.pop(ctx, v)),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('لغوه')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctl.text),
                child: const Text('بدل کړه')),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (name == null || name.trim().isEmpty || name == e.name) return;
    await _be.renameEntry(e.path, name.trim());
    if (mounted) _open(_path, push: false);
  }

  Future<void> _newFolder() async {
    final ctl = TextEditingController(text: 'نوی فولډر');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نوی فولډر'),
          content: SizedBox(
            width: 340,
            child: TextField(
                controller: ctl,
                autofocus: true,
                onSubmitted: (v) => Navigator.pop(ctx, v)),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('لغوه')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctl.text),
                child: const Text('جوړ کړه')),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (name == null || name.trim().isEmpty) return;
    await _be.createFolder(_path, name.trim());
    if (mounted) _open(_path, push: false);
  }

  void _activate(FsEntry e) {
    if (e.isDirectory) {
      _open(e.path);
    } else {
      _be.openExternally(e.path);
    }
  }

  // ═══════════════════════════════════════════════════════
  //  بنا
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            _selectAll,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copy,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true): () =>
            _copy(cut: true),
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
        const SingleActivator(LogicalKeyboardKey.delete): _delete,
        const SingleActivator(LogicalKeyboardKey.escape): _deselectAll,
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            _open(_path, push: false),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Column(
          // **stretch اړین دی.** د `Column` ډیفالټ `center` دی، نو د
          // ټولبار کانټینر یوازې د خپلې محتوا هومره عرض نیوه او په
          // منځ کې راټول ښکارېده. اوس د وینډو بشپړ عرض نیسي.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(context),
            _pathBar(context),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              // په RTL کې لومړی اولاد ښي لور ته ځي — د وينډوز اکسپلورر
              // په څېر، د فولډرونو ونه ښي طرف ته.
              child: Row(
                children: [
                  if (_showTree)
                    ExplorerTree(
                      current: _path,
                      onOpen: _open,
                    ),
                  Expanded(child: _content(context)),
                ],
              ),
            ),
            _statusBar(context),
          ],
        ),
      ),
    );
  }

  // ── وسیلې بار ──
  Widget _toolbar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final has = _selected.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16, vertical: AppTokens.s12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Wrap(
        spacing: AppTokens.s4,
        runSpacing: AppTokens.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // New +
          PopupMenuButton<String>(
            tooltip: 'نوی',
            onSelected: (v) {
              if (v == 'folder') _newFolder();
              if (v == 'event') {
                showNewEventDialog(context, manualParent: _path);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'folder',
                child: Row(children: [
                  Icon(Icons.create_new_folder_rounded, size: 16),
                  SizedBox(width: 10),
                  Text('نوی فولډر'),
                ]),
              ),
              PopupMenuItem(
                value: 'event',
                child: Row(children: [
                  Icon(Icons.auto_awesome_mosaic_rounded, size: 16),
                  SizedBox(width: 10),
                  Text('نوې پیښه دلته'),
                ]),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s16, vertical: 9),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: AppTokens.brMd,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 17, color: cs.onPrimary),
                  const SizedBox(width: 5),
                  Text('نوی',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimary)),
                ],
              ),
            ),
          ),
          _sep(cs),

          _tool(context, Icons.content_copy_rounded, 'کاپي (Ctrl+C)',
              has ? _copy : null),
          _tool(context, Icons.content_cut_rounded, 'کټ (Ctrl+X)',
              has ? () => _copy(cut: true) : null),
          _tool(context, Icons.content_paste_rounded, 'پیسټ (Ctrl+V)',
              _clip.isEmpty ? null : _paste),
          _tool(context, Icons.drive_file_rename_outline_rounded, 'نوم بدلول',
              _selected.length == 1
                  ? () => _rename(
                      _visible.firstWhere((e) => e.path == _selected.first))
                  : null),
          _tool(context, Icons.delete_outline_rounded, 'حذف (Delete)',
              has ? _delete : null, danger: true),

          _sep(cs),

          // ټاکنه
          PopupMenuButton<String>(
            tooltip: 'ټاکنه',
            onSelected: (v) => switch (v) {
              'all' => _selectAll(),
              'none' => _deselectAll(),
              'invert' => _invertSelection(),
              _ => _selectSameType(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('ټول وټاکه  (Ctrl+A)')),
              PopupMenuItem(value: 'none', child: Text('ټاکنه پاکه کړه')),
              PopupMenuItem(value: 'invert', child: Text('ټاکنه برعکس کړه')),
              PopupMenuItem(
                  value: 'type', child: Text('ټول همدا ډول فایلونه وټاکه')),
            ],
            child: _toolBox(
                context, Icons.checklist_rounded, 'ټاکنه', hasArrow: true),
          ),

          SearchBox(
            controller: _searchCtl,
            width: 200,
            hint: 'په دې فولډر کې ولټوه…',
            onChanged: (_) => setState(() {}),
          ),

          // Sort
          PopupMenuButton<ExplorerSort>(
            tooltip: 'ترتیب',
            onSelected: (v) => setState(() {
              if (_sort == v) {
                _asc = !_asc;
              } else {
                _sort = v;
                _asc = true;
              }
            }),
            itemBuilder: (_) => [
              for (final s in ExplorerSort.values)
                PopupMenuItem(
                  value: s,
                  child: Row(children: [
                    Icon(
                      _sort == s
                          ? (_asc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                          : Icons.sort_rounded,
                      size: 15,
                    ),
                    const SizedBox(width: 10),
                    Text(s.label),
                  ]),
                ),
            ],
            child: _toolBox(context, Icons.sort_rounded, _sort.label,
                hasArrow: true),
          ),

          // View
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: AppTokens.brMd,
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final v in ExplorerView.values)
                  Tooltip(
                    message: v.label,
                    child: InkWell(
                      onTap: () => setState(() => _view = v),
                      borderRadius: AppTokens.brSm,
                      child: AnimatedContainer(
                        duration: AppTokens.fast,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: _view == v
                              ? cs.primary.withValues(alpha: 0.14)
                              : null,
                          borderRadius: AppTokens.brSm,
                        ),
                        child: Icon(v.icon,
                            size: 16,
                            color: _view == v
                                ? cs.primary
                                : cs.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _tool(context, Icons.account_tree_rounded, 'د فولډرونو ونه',
              () => setState(() => _showTree = !_showTree),
              active: _showTree),

          // **پټ فایلونه.** د پروګرام خپل ثبت فایلونه پټ دي (نو
          // محیط صفا وي)، خو څوک چې یې لیدل غواړي، همدلته یې
          // راښکاره کولی شي.
          _tool(
            context,
            context.watch<AppState>().settings.showHiddenFiles
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            'پټ فایلونه وښایه',
            () => context.read<AppState>().toggleHiddenFiles(),
            active: context.watch<AppState>().settings.showHiddenFiles,
          ),
        ],
      ),
    );
  }

  Widget _sep(ColorScheme cs) => Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: AppTokens.s8),
      color: cs.outlineVariant);

  Widget _tool(BuildContext context, IconData icon, String tip,
      VoidCallback? onTap,
      {bool danger = false, bool active = false}) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        splashRadius: 18,
        style: IconButton.styleFrom(
          foregroundColor: danger
              ? cs.error
              : active
                  ? cs.primary
                  : null,
          backgroundColor:
              active ? cs.primary.withValues(alpha: 0.12) : null,
        ),
      ),
    );
  }

  Widget _toolBox(BuildContext context, IconData icon, String label,
      {bool hasArrow = false}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppTokens.s12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
          if (hasArrow) const Icon(Icons.expand_more_rounded, size: 14),
        ],
      ),
    );
  }

  // ── د مسیر بار ──
  Widget _pathBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sep = _path.contains(r'\') ? r'\' : '/';
    final parts = _path.split(sep).where((e) => e.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16, vertical: AppTokens.s8),
      color: cs.surface,
      child: Row(
        children: [
          _tool(context, Icons.arrow_forward_rounded, 'شاته',
              _back.isEmpty ? null : _goBack),
          _tool(context, Icons.arrow_back_rounded, 'مخکې',
              _forward.isEmpty ? null : _goForward),
          _tool(context, Icons.arrow_upward_rounded, 'پورتنی فولډر', _goUp),
          _tool(context, Icons.refresh_rounded, 'تازه کړه (F5)',
              () => _open(_path, push: false)),
          const SizedBox(width: AppTokens.s4),

          // د مسیر بریډکرمبونه
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s8),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: AppTokens.brMd,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_rounded, size: 15, color: cs.primary),
                  const SizedBox(width: AppTokens.s8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: parts.length,
                      itemBuilder: (context, i) {
                        final upTo = _path.startsWith('/')
                            ? '/${parts.take(i + 1).join('/')}'
                            : parts.take(i + 1).join(sep) +
                                (i == 0 ? sep : '');
                        return Row(
                          children: [
                            InkWell(
                              onTap: () => _open(upTo),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 4),
                                child: Text(
                                  parts[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: i == parts.length - 1
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: i == parts.length - 1
                                        ? cs.onSurface
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            if (i < parts.length - 1)
                              Icon(Icons.chevron_left_rounded,
                                  size: 14, color: cs.outline),
                          ],
                        );
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'مسیر کاپي کړه',
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    onPressed: () => copyText(context, _path, label: 'مسیر'),
                    splashRadius: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── محتوا ──
  Widget _content(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _visible;
    if (items.isEmpty) {
      return EmptyState(
        icon: _searchCtl.text.isEmpty
            ? Icons.folder_off_rounded
            : Icons.search_off_rounded,
        title: _searchCtl.text.isEmpty
            ? 'دا فولډر تش دی'
            : 'هیڅ پایله ونه موندل شوه',
      );
    }

    return GestureDetector(
      onTap: _deselectAll,
      behavior: HitTestBehavior.translucent,
      child: switch (_view) {
        ExplorerView.grid => _gridView(items),
        ExplorerView.list => _listView(items, details: false),
        ExplorerView.details => _listView(items, details: true),
      },
    );
  }

  Widget _gridView(List<FsEntry> items) => LayoutBuilder(
        builder: (context, c) {
          final cols = (c.maxWidth / 132).floor().clamp(2, 12);
          return GridView.builder(
            padding: const EdgeInsets.all(AppTokens.s16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: AppTokens.s8,
              crossAxisSpacing: AppTokens.s8,
              childAspectRatio: 0.92,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _EntryTile(
              entry: items[i],
              selected: _selected.contains(items[i].path),
              grid: true,
              onTap: (ctrl, shift) =>
                  _tap(items[i], ctrl: ctrl, shift: shift),
              onDouble: () => _activate(items[i]),
              onMenu: (pos) => _contextMenu(context, items[i], pos),
            ),
          );
        },
      );

  Widget _listView(List<FsEntry> items, {required bool details}) => Column(
        children: [
          if (details) _detailsHeader(context),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s12, vertical: AppTokens.s8),
              itemCount: items.length,
              itemBuilder: (context, i) => _EntryTile(
                entry: items[i],
                selected: _selected.contains(items[i].path),
                grid: false,
                details: details,
                onTap: (ctrl, shift) =>
                    _tap(items[i], ctrl: ctrl, shift: shift),
                onDouble: () => _activate(items[i]),
                onMenu: (pos) => _contextMenu(context, items[i], pos),
              ),
            ),
          ),
        ],
      );

  Widget _detailsHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget h(String label, ExplorerSort s, {int flex = 1}) => Expanded(
          flex: flex,
          child: InkWell(
            onTap: () => setState(() {
              if (_sort == s) {
                _asc = !_asc;
              } else {
                _sort = s;
                _asc = true;
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant)),
                  if (_sort == s)
                    Icon(
                        _asc
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: cs.primary),
                ],
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.only(right: 46, left: AppTokens.s16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: LayoutBuilder(builder: (context, c) => Row(children: [
        h('نوم', ExplorerSort.name, flex: 4),
        if (c.maxWidth > 620) h('د بدلون نېټه', ExplorerSort.modified, flex: 2),
        if (c.maxWidth > 480) h('ډول', ExplorerSort.type),
        h('اندازه', ExplorerSort.size),
      ])),
    );
  }

  // ── د راسته کلیک مینو ──
  void _contextMenu(BuildContext context, FsEntry e, Offset pos) {
    if (!_selected.contains(e.path)) _tap(e);
    final s = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    // **پام:** دلته `RelativeRect.fromLTRB(dx, dy, dx, dy)` مه کاروئ.
    //
    // `RelativeRect` له **هرې څنډې** فاصلې اخلي — درېیم ارزښت یې «له
    // ښي څنډې څومره لرې» معنا لري، نه «د x مختصات». نو په ۲۵۶۰px
    // کړکۍ کې پر x=۸۰۰ رایټ‌کلیک منو له ښي څنډې ۸۰۰px لرې غورځوله —
    // یعنې د کلیک ځای څخه لرې، د فولډرونو د ونې ترڅنګ.
    //
    // سمه لار: د ماوس نقطه د اوورلې د اندازې په نسبت وسنجول شي.
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(pos.dx, pos.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
            value: 'open',
            child: Row(children: [
              Icon(e.isDirectory
                  ? Icons.folder_open_rounded
                  : Icons.open_in_new_rounded, size: 16),
              const SizedBox(width: 10),
              Text(e.isDirectory ? 'پرانیزه' : 'په بل پروګرام کې پرانیزه'),
            ])),
        if (e.isEventFolder)
          const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_rounded, size: 16),
                SizedBox(width: 10),
                Text('پیښه ایډیټ کړه'),
              ])),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: 'copy',
            child: Row(children: [
              Icon(Icons.content_copy_rounded, size: 16),
              SizedBox(width: 10),
              Text('کاپي'),
            ])),
        const PopupMenuItem(
            value: 'cut',
            child: Row(children: [
              Icon(Icons.content_cut_rounded, size: 16),
              SizedBox(width: 10),
              Text('کټ'),
            ])),
        if (_clip.isNotEmpty)
          const PopupMenuItem(
              value: 'paste',
              child: Row(children: [
                Icon(Icons.content_paste_rounded, size: 16),
                SizedBox(width: 10),
                Text('پیسټ'),
              ])),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: 'rename',
            child: Row(children: [
              Icon(Icons.drive_file_rename_outline_rounded, size: 16),
              SizedBox(width: 10),
              Text('نوم بدل کړه'),
            ])),
        const PopupMenuItem(
            value: 'reveal',
            child: Row(children: [
              Icon(Icons.desktop_windows_rounded, size: 16),
              SizedBox(width: 10),
              Text('په وینډوز کې وښیه'),
            ])),
        const PopupMenuItem(
            value: 'path',
            child: Row(children: [
              Icon(Icons.link_rounded, size: 16),
              SizedBox(width: 10),
              Text('مسیر کاپي کړه'),
            ])),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 10),
              Text('حذف',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ])),
      ],
    ).then((v) async {
      if (!mounted || v == null) return;
      switch (v) {
        case 'open':
          _activate(e);
        case 'edit':
          // د دې فولډر پیښه په ایندکس کې ومومه او ایډیټر یې پرانیزه.
          final list = await s.backend
              .search(EventQuery(folderPrefix: e.path, limit: 1));
          if (list.isNotEmpty && mounted) s.openEditor(list.first);
        case 'copy':
          _copy();
        case 'cut':
          _copy(cut: true);
        case 'paste':
          await _paste();
        case 'rename':
          await _rename(e);
        case 'reveal':
          await s.backend.revealInFileManager(e.path);
        case 'path':
          await Clipboard.setData(ClipboardData(text: e.path));
          messenger.showSnackBar(
              const SnackBar(content: Text('مسیر کاپي شو'), width: 300));
        case 'delete':
          await _delete();
      }
    });
  }

  // ── حالت بار ──
  Widget _statusBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _visible;
    final dirs = items.where((e) => e.isDirectory).length;
    final files = items.length - dirs;
    final selSize = items
        .where((e) => _selected.contains(e.path))
        .fold(0, (a, e) => a + e.sizeBytes);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(
            '${PashtoDigits.to(dirs)} فولډرونه  ·  '
            '${PashtoDigits.to(files)} فایلونه',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(width: AppTokens.s16),
            Container(width: 1, height: 14, color: cs.outlineVariant),
            const SizedBox(width: AppTokens.s16),
            Text(
              '${PashtoDigits.to(_selected.length)} ټاکل شوي'
              '${selSize > 0 ? '  ·  ${humanBytes(selSize)}' : ''}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.primary),
            ),
          ],
          const Spacer(),
          if (_clip.isNotEmpty)
            Text(
              '${PashtoDigits.to(_clip.length)} توکي په کلپ‌بورډ کې'
              '${_clipCut ? ' (کټ)' : ''}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د یوه توکي کاشۍ
// ═══════════════════════════════════════════════════════════

class _EntryTile extends StatefulWidget {
  const _EntryTile({
    required this.entry,
    required this.selected,
    required this.grid,
    required this.onTap,
    required this.onDouble,
    required this.onMenu,
    this.details = false,
  });

  final FsEntry entry;
  final bool selected, grid, details;
  final void Function(bool ctrl, bool shift) onTap;
  final VoidCallback onDouble;
  final void Function(Offset) onMenu;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _hover = false;

  Color _color(ColorScheme cs) {
    if (widget.entry.isEventFolder) return AppTokens.brand;
    if (widget.entry.isDirectory) return AppTokens.amber;
    return mediaColor(widget.entry.kind);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.entry;
    final color = _color(cs);

    void handleTap() {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final ctrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
          keys.contains(LogicalKeyboardKey.controlRight);
      final shift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
          keys.contains(LogicalKeyboardKey.shiftRight);
      widget.onTap(ctrl, shift);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: handleTap,
        onDoubleTap: widget.onDouble,
        onSecondaryTapUp: (d) => widget.onMenu(d.globalPosition),
        child: AnimatedContainer(
          duration: AppTokens.fast,
          curve: AppTokens.ease,
          margin: widget.grid
              ? EdgeInsets.zero
              : const EdgeInsets.only(bottom: 2),
          padding: widget.grid
              ? const EdgeInsets.all(AppTokens.s8)
              : const EdgeInsets.symmetric(
                  horizontal: AppTokens.s12, vertical: AppTokens.s8),
          decoration: BoxDecoration(
            color: widget.selected
                ? cs.primary.withValues(alpha: 0.14)
                : _hover
                    ? cs.surfaceContainer
                    : null,
            borderRadius: AppTokens.brMd,
            border: Border.all(
              color: widget.selected ? cs.primary : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: widget.grid ? _gridBody(cs, color, e) : _rowBody(cs, color, e),
        ),
      ),
    );
  }

  Widget _gridBody(ColorScheme cs, Color color, FsEntry e) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              FileThumb(entry: e, size: 46, color: color),
              if (e.isEventFolder)
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        size: 12, color: AppTokens.green),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            e.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.4),
          ),
          if (!e.isDirectory)
            Text(humanBytes(e.sizeBytes),
                style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)),
        ],
      );

  Widget _rowBody(ColorScheme cs, Color color, FsEntry e) {
    final date = e.modified == null
        ? '—'
        : TriDate.fromDateTime(e.modified!).shamsiNumeric;

    if (!widget.details) {
      return Row(
        children: [
          FileThumb(entry: e, size: 22, color: color),
          const SizedBox(width: AppTokens.s12),
          Expanded(
            child: Text(e.name,
                style: const TextStyle(fontSize: 12.5),
                overflow: TextOverflow.ellipsis),
          ),
          if (e.isEventFolder)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              margin: const EdgeInsets.only(left: AppTokens.s8),
              decoration: BoxDecoration(
                color: AppTokens.brand.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('پیښه',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.brand)),
            ),
          if (!e.isDirectory)
            Text(humanBytes(e.sizeBytes),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      );
    }

    // کالمونه د سرلیک سره یو شان پټیږي، نو کرښې تل سمې لیکه شوې وي.
    return LayoutBuilder(builder: (context, c) {
      return Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                FileThumb(entry: e, size: 20, color: color),
                const SizedBox(width: AppTokens.s8),
                Expanded(
                  child: Text(e.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          if (c.maxWidth > 620)
            Expanded(
              flex: 2,
              child: Text(date,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ),
          if (c.maxWidth > 480)
            Expanded(
              child: Text(
                e.isDirectory ? 'فولډر' : (e.extension.toUpperCase()),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: Text(
              e.isDirectory ? '—' : humanBytes(e.sizeBytes),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      );
    });
  }
}
