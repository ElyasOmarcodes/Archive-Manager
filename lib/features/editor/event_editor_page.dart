import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../preview/preview_page.dart';
import 'block_widgets.dart';
import 'html_builder.dart';
import 'meta_panel.dart';

/// **د پیښې د طراحۍ پاڼه** — ډراګ او ډراپ ویجټ جوړونکی.
class EventEditorPage extends StatefulWidget {
  const EventEditorPage({super.key});

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  late EventMetadata _event;
  bool _dirty = false;
  bool _saving = false;
  bool _dropping = false;

  @override
  void initState() {
    super.initState();
    // یو کاپي پر مخ کار کوو — تر «ثبت» پورې اصلي ډیټا نه بدلیږي.
    _event = context.read<AppState>().editing!.copyWith();
  }

  void _mutate(void Function() f) {
    setState(() {
      f();
      _dirty = true;
    });
  }

  // ── د بلاکونو عملیات ───────────────────────────────────

  void _addBlock(BlockKind kind, {int? at}) {
    final b = Block(
      id: 'b-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      level: kind == BlockKind.heading ? 2 : 2,
    );
    _mutate(() {
      if (at == null || at > _event.blocks.length) {
        _event.blocks.add(b);
      } else {
        _event.blocks.insert(at, b);
      }
    });
  }

  void _removeBlock(int i) => _mutate(() => _event.blocks.removeAt(i));

  void _moveBlock(int from, int to) {
    if (from == to) return;
    _mutate(() {
      final b = _event.blocks.removeAt(from);
      _event.blocks.insert(to > from ? to - 1 : to, b);
    });
  }

  void _shift(int i, int delta) {
    final to = i + delta;
    if (to < 0 || to >= _event.blocks.length) return;
    _mutate(() {
      final b = _event.blocks.removeAt(i);
      _event.blocks.insert(to, b);
    });
  }

  /// یو فایل `attachments/` ته انتقالوي او بلاک ورسره تړي.
  Future<void> _attachTo(Block block, String sourcePath) async {
    final s = context.read<AppState>();
    try {
      final att = await s.backend.attachFile(
        eventFolder: _event.folderPath,
        sourcePath: sourcePath,
      );
      _mutate(() {
        block.source = att.relativePath;
        if (block.caption.isEmpty) block.caption = att.name;
        _event.attachments
          ..removeWhere((a) => a.relativePath == att.relativePath)
          ..add(att);
        // د فایل له ډول سره سم بلاک پخپله سم کیږي.
        block.kind = switch (att.kind) {
          MediaKind.image => BlockKind.image,
          MediaKind.video => BlockKind.video,
          MediaKind.audio => BlockKind.audio,
          _ => BlockKind.file,
        };
      });
      if (mounted) toast(context, '«${att.name}» ضمیمه شو');
    } catch (e) {
      if (mounted) toast(context, 'د فایل ضمیمه کول ونه شول: $e', error: true);
    }
  }

  /// د بهر څخه راغورځول شوي فایلونه — هر یو خپل بلاک جوړوي.
  Future<void> _onExternalDrop(List<String> paths) async {
    for (final path in paths) {
      final kind = MediaKind.ofPath(path);
      final blockKind = switch (kind) {
        MediaKind.image => BlockKind.image,
        MediaKind.video => BlockKind.video,
        MediaKind.audio => BlockKind.audio,
        _ => BlockKind.file,
      };
      final b = Block(
        id: 'b-${DateTime.now().microsecondsSinceEpoch}-${path.hashCode}',
        kind: blockKind,
      );
      _mutate(() => _event.blocks.add(b));
      await _attachTo(b, path);
    }
  }

  Future<void> _save({bool thenPreview = false}) async {
    setState(() => _saving = true);
    final s = context.read<AppState>();
    final html = buildEventHtml(_event);
    await s.saveEvent(_event, html: html);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    toast(context, 'پیښه ثبت شوه او index.html تازه شو');
    if (thenPreview) s.openEditor(_event, preview: true);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ناثبت شوي بدلونونه'),
          content: const Text(
              'ستاسو ځینې بدلونونه لا ثبت شوي نه دي. ایا وتل غواړئ؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('پاتې کېږم')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('پرته له ثبت وتل')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx, true);
                await _save();
              },
              child: const Text('ثبت او وتل'),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (s.previewMode) {
      return PreviewPage(
        event: _event,
        onBack: () => s.setPreview(false),
      );
    }

    return Column(
      children: [
        _Toolbar(
          event: _event,
          dirty: _dirty,
          saving: _saving,
          onSave: _save,
          onPreview: () async {
            if (_dirty) await _save(thenPreview: true);
            if (mounted) s.setPreview(true);
          },
          onBack: () async {
            if (await _confirmLeave()) {
              if (mounted) s.closeEditor();
            }
          },
        ),
        Expanded(
          // په RTL کې د Row لومړی اولاد **ښي** لور ته ځي.
          // نو د ویجټونو پالېټ لومړی (ښي) او د میټاډیټا پینل وروستی
          // (چپ) — لکه څنګه چې غوښتل شوی و.
          child: Row(
            children: [
              // ── ښي: د ویجټونو پالېټ ──
              _Palette(onAdd: _addBlock),

              // ── منځ: د پاڼې جوړونه ──
              Expanded(
                child: DropTarget(
                  onDragEntered: (_) => setState(() => _dropping = true),
                  onDragExited: (_) => setState(() => _dropping = false),
                  onDragDone: (d) {
                    setState(() => _dropping = false);
                    _onExternalDrop(d.files.map((f) => f.path).toList());
                  },
                  child: AnimatedContainer(
                    duration: AppTokens.fast,
                    decoration: BoxDecoration(
                      color: _dropping
                          ? cs.primary.withValues(alpha: 0.06)
                          : null,
                      border: _dropping
                          ? Border.all(color: cs.primary, width: 2)
                          : null,
                    ),
                    child: _Canvas(
                      event: _event,
                      onAdd: _addBlock,
                      onRemove: _removeBlock,
                      onMove: _moveBlock,
                      onShift: _shift,
                      onAttach: _attachTo,
                      onChanged: () => _mutate(() {}),
                      dropping: _dropping,
                    ),
                  ),
                ),
              ),

              // ── چپ: د میټاډیټا پینل ──
              MetaPanel(
                event: _event,
                onChanged: (f) => _mutate(f),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  پورتنی بار
// ═══════════════════════════════════════════════════════════

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.event,
    required this.dirty,
    required this.saving,
    required this.onSave,
    required this.onPreview,
    required this.onBack,
  });

  final EventMetadata event;
  final bool dirty, saving;
  final Future<void> Function({bool thenPreview}) onSave;
  final VoidCallback onPreview, onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = context.read<AppState>();

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'بېرته',
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            onPressed: onBack,
          ),
          const SizedBox(width: AppTokens.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (dirty) ...[
                      const SizedBox(width: AppTokens.s8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTokens.amber.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('ناثبت',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTokens.amber)),
                      ),
                    ],
                  ],
                ),
                Text(
                  event.folderPath,
                  style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.s16),
          OutlinedButton.icon(
            onPressed: () => s.backend.revealInFileManager(event.folderPath),
            icon: const Icon(Icons.folder_open_rounded, size: 17),
            label: const Text('فولډر پرانیزه'),
          ),
          const SizedBox(width: AppTokens.s8),
          OutlinedButton.icon(
            onPressed: onPreview,
            icon: const Icon(Icons.visibility_rounded, size: 17),
            label: const Text('پریویو'),
          ),
          const SizedBox(width: AppTokens.s8),
          FilledButton.icon(
            onPressed: saving ? null : () => onSave(),
            icon: saving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 17),
            label: Text(dirty ? 'ثبت / اپډیټ' : 'ثبت شوی'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د پاڼې تخته
// ═══════════════════════════════════════════════════════════

class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.event,
    required this.onAdd,
    required this.onRemove,
    required this.onMove,
    required this.onShift,
    required this.onAttach,
    required this.onChanged,
    required this.dropping,
  });

  final EventMetadata event;
  final void Function(BlockKind, {int? at}) onAdd;
  final void Function(int) onRemove;
  final void Function(int from, int to) onMove;
  final void Function(int i, int delta) onShift;
  final Future<void> Function(Block, String) onAttach;
  final VoidCallback onChanged;
  final bool dropping;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (event.blocks.isEmpty) {
      return EmptyState(
        icon: Icons.dashboard_customize_rounded,
        title: 'پاڼه لا تشه ده',
        message: 'له ښي پالېټ څخه یو ویجټ ووهئ، یا فایلونه دلته '
            'له بهره راکش کړئ.',
      );
    }

    return Stack(
      children: [
        Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppTokens.s24, AppTokens.s24, AppTokens.s24, 120),
            itemCount: event.blocks.length + 1,
            itemBuilder: (context, i) {
              // وروستی — د پای د غورځولو ساحه
              if (i == event.blocks.length) {
                return _DropSlot(index: i, onMove: onMove, tall: true);
              }
              return Column(
                children: [
                  _DropSlot(index: i, onMove: onMove),
                  BlockEditor(
                    key: ValueKey(event.blocks[i].id),
                    block: event.blocks[i],
                    index: i,
                    total: event.blocks.length,
                    eventFolder: event.folderPath,
                    onRemove: () => onRemove(i),
                    onUp: () => onShift(i, -1),
                    onDown: () => onShift(i, 1),
                    onAttach: (p) => onAttach(event.blocks[i], p),
                    onChanged: onChanged,
                  ),
                ],
              );
            },
          ),
        ),
        if (dropping)
          Positioned(
            bottom: AppTokens.s24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.s20, vertical: AppTokens.s12),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_rounded,
                        size: 18, color: cs.onPrimary),
                    const SizedBox(width: AppTokens.s8),
                    Text('فایلونه دلته پرېږدئ',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimary)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// د دوو بلاکونو ترمنځ د غورځولو ساحه — د ډراګ پر مهال ښکاره کیږي.
class _DropSlot extends StatefulWidget {
  const _DropSlot({
    required this.index,
    required this.onMove,
    this.tall = false,
  });

  final int index;
  final void Function(int from, int to) onMove;
  final bool tall;

  @override
  State<_DropSlot> createState() => _DropSlotState();
}

class _DropSlotState extends State<_DropSlot> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != widget.index,
      onAcceptWithDetails: (d) => widget.onMove(d.data, widget.index),
      builder: (context, candidates, _) {
        final active = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: AppTokens.fast,
          curve: AppTokens.ease,
          height: active ? 44 : (widget.tall ? 60 : 10),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: active ? cs.primary.withValues(alpha: 0.10) : null,
            borderRadius: AppTokens.brMd,
            border: active
                ? Border.all(color: cs.primary, width: 1.6)
                : null,
          ),
          child: active
              ? Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.south_rounded, size: 15, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('دلته یې کېږده',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: cs.primary)),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د ویجټونو پالېټ
// ═══════════════════════════════════════════════════════════

class _Palette extends StatelessWidget {
  const _Palette({required this.onAdd});
  final void Function(BlockKind, {int? at}) onAdd;

  static const _icons = {
    BlockKind.heading: Icons.title_rounded,
    BlockKind.paragraph: Icons.notes_rounded,
    BlockKind.quote: Icons.format_quote_rounded,
    BlockKind.image: Icons.image_rounded,
    BlockKind.video: Icons.movie_rounded,
    BlockKind.audio: Icons.graphic_eq_rounded,
    BlockKind.file: Icons.attach_file_rounded,
    BlockKind.divider: Icons.horizontal_rule_rounded,
  };

  static const _colors = {
    BlockKind.heading: AppTokens.brand,
    BlockKind.paragraph: AppTokens.teal,
    BlockKind.quote: AppTokens.violet,
    BlockKind.image: AppTokens.sky,
    BlockKind.video: AppTokens.rose,
    BlockKind.audio: AppTokens.brandAlt,
    BlockKind.file: AppTokens.orange,
    BlockKind.divider: AppTokens.green,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(left: BorderSide(color: cs.outlineVariant)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.s12),
        children: [
          const SectionLabel('ویجټونه', icon: Icons.widgets_rounded),
          for (final k in BlockKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s6),
              child: HoverLift(
                onTap: () => onAdd(k),
                lift: 2,
                builder: (context, hovered) => AnimatedContainer(
                  duration: AppTokens.fast,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.s12, vertical: 10),
                  decoration: BoxDecoration(
                    color: hovered
                        ? _colors[k]!.withValues(alpha: 0.10)
                        : cs.surfaceContainerLowest,
                    borderRadius: AppTokens.brMd,
                    border: Border.all(
                      color: hovered
                          ? _colors[k]!.withValues(alpha: 0.5)
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_icons[k], size: 17, color: _colors[k]),
                      const SizedBox(width: AppTokens.s12),
                      Expanded(
                        child: Text(k.label,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      AnimatedOpacity(
                        duration: AppTokens.fast,
                        opacity: hovered ? 1 : 0,
                        child: Icon(Icons.add_rounded,
                            size: 14, color: _colors[k]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppTokens.s16),
          Container(
            padding: const EdgeInsets.all(AppTokens.s12),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: AppTokens.brMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 13, color: cs.primary),
                    const SizedBox(width: 5),
                    Text('لارښوونه',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: cs.primary)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'فایلونه له وینډوز څخه مستقیم دې تختې ته راکش کړئ — '
                  'پخپله به `attachments` ته ولېږدیږي.',
                  style: TextStyle(
                      fontSize: 10.5, height: 1.7, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
