import 'dart:io' show File;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **د یو بلاک ایډیټر** — چپ لور ته د ډراګ او حذف کنټرولونه.
class BlockEditor extends StatefulWidget {
  const BlockEditor({
    super.key,
    required this.block,
    required this.index,
    required this.total,
    required this.eventFolder,
    required this.onRemove,
    required this.onUp,
    required this.onDown,
    required this.onAttach,
    required this.onChanged,
  });

  final Block block;
  final int index, total;
  final String eventFolder;
  final VoidCallback onRemove, onUp, onDown, onChanged;
  final Future<void> Function(String path) onAttach;

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  bool _hover = false;
  bool _dropping = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── چپ لور: کنټرولونه ──
          AnimatedOpacity(
            duration: AppTokens.fast,
            opacity: _hover ? 1 : 0.28,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, left: AppTokens.s8),
              child: Column(
                children: [
                  // د ډراګ لاستی
                  Draggable<int>(
                    data: widget.index,
                    axis: Axis.vertical,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: AppTokens.brMd,
                          boxShadow: [
                            BoxShadow(
                                color: cs.shadow.withValues(alpha: 0.3),
                                blurRadius: 16)
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_indicator_rounded,
                                size: 15, color: cs.onPrimary),
                            const SizedBox(width: 6),
                            Text(widget.block.kind.label,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onPrimary)),
                          ],
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.25,
                      child: _iconBtn(
                          context, Icons.drag_indicator_rounded, null,
                          tooltip: ''),
                    ),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Tooltip(
                        message: 'ونیسئ او ځای یې بدل کړئ',
                        child: _iconBtn(
                            context, Icons.drag_indicator_rounded, null,
                            tooltip: ''),
                      ),
                    ),
                  ),
                  _iconBtn(context, Icons.keyboard_arrow_up_rounded,
                      widget.index == 0 ? null : widget.onUp,
                      tooltip: 'پورته'),
                  _iconBtn(context, Icons.keyboard_arrow_down_rounded,
                      widget.index == widget.total - 1 ? null : widget.onDown,
                      tooltip: 'ښکته'),
                  _iconBtn(context, Icons.delete_outline_rounded,
                      widget.onRemove,
                      tooltip: 'حذف', danger: true),
                ],
              ),
            ),
          ),

          // ── محتوا ──
          Expanded(
            child: DropTarget(
              enable: widget.block.kind.needsFile,
              onDragEntered: (_) => setState(() => _dropping = true),
              onDragExited: (_) => setState(() => _dropping = false),
              onDragDone: (d) async {
                setState(() => _dropping = false);
                if (d.files.isNotEmpty) {
                  await widget.onAttach(d.files.first.path);
                }
              },
              child: AnimatedContainer(
                duration: AppTokens.fast,
                margin: const EdgeInsets.only(bottom: AppTokens.s8),
                padding: const EdgeInsets.all(AppTokens.s16),
                decoration: BoxDecoration(
                  color: _dropping
                      ? cs.primary.withValues(alpha: 0.07)
                      : _hover
                          ? cs.surfaceContainerLow
                          : Colors.transparent,
                  borderRadius: AppTokens.brLg,
                  border: Border.all(
                    color: _dropping
                        ? cs.primary
                        : _hover
                            ? cs.outlineVariant
                            : Colors.transparent,
                    width: _dropping ? 1.8 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BlockHeader(block: widget.block, visible: _hover,
                        onChanged: widget.onChanged),
                    _content(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback? onTap,
      {required String tooltip, bool danger = false}) {
    final cs = Theme.of(context).colorScheme;
    final btn = InkResponse(
      onTap: onTap,
      radius: 15,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? cs.outlineVariant
              : danger
                  ? cs.error
                  : cs.onSurfaceVariant,
        ),
      ),
    );
    return tooltip.isEmpty ? btn : Tooltip(message: tooltip, child: btn);
  }

  Widget _content(BuildContext context) {
    final b = widget.block;
    return switch (b.kind) {
      BlockKind.heading => _TextField(
          block: b,
          onChanged: widget.onChanged,
          hint: 'عنوان دلته ولیکئ…',
          style: TextStyle(
            fontSize: switch (b.level) { 1 => 26.0, 2 => 21.0, 3 => 18.0, _ => 16.0 },
            fontWeight: FontWeight.w800,
            height: 1.5,
          ),
        ),
      BlockKind.paragraph => _TextField(
          block: b,
          onChanged: widget.onChanged,
          hint: 'خپل متن دلته ولیکئ…',
          maxLines: null,
          style: const TextStyle(fontSize: 14.5, height: 1.9),
        ),
      BlockKind.quote => _QuoteEditor(block: b, onChanged: widget.onChanged),
      BlockKind.divider => const _DividerPreview(),
      _ => _FileBlock(
          block: b,
          eventFolder: widget.eventFolder,
          onAttach: widget.onAttach,
          onChanged: widget.onChanged,
          dropping: _dropping,
        ),
    };
  }
}

/// د بلاک پورتنی بار — ډول، د عنوان کچه، د متن لور.
class _BlockHeader extends StatelessWidget {
  const _BlockHeader({
    required this.block,
    required this.visible,
    required this.onChanged,
  });

  final Block block;
  final bool visible;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: AppTokens.fast,
      child: !visible
          ? const SizedBox(width: double.infinity, height: 0)
          : Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s12),
              child: Row(
                children: [
                  Text(
                    block.kind.label,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: AppTokens.s12),
                  // د عنوان کچه
                  if (block.kind == BlockKind.heading)
                    for (var l = 1; l <= 4; l++) ...[
                      InkWell(
                        onTap: () {
                          block.level = l;
                          onChanged();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          margin: const EdgeInsets.only(left: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: block.level == l
                                ? cs.primary.withValues(alpha: 0.14)
                                : cs.surfaceContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('H$l',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: block.level == l
                                      ? cs.primary
                                      : cs.onSurfaceVariant)),
                        ),
                      ),
                    ],
                  // د فایلونو د تنظیم لور
                  if (block.kind.needsFile && block.kind != BlockKind.audio)
                    for (final a in const [
                      ('right', Icons.format_align_right_rounded),
                      ('center', Icons.format_align_center_rounded),
                      ('left', Icons.format_align_left_rounded),
                    ]) ...[
                      InkWell(
                        onTap: () {
                          block.align = a.$1;
                          onChanged();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          margin: const EdgeInsets.only(left: 3),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: block.align == a.$1
                                ? cs.primary.withValues(alpha: 0.14)
                                : cs.surfaceContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(a.$2,
                              size: 13,
                              color: block.align == a.$1
                                  ? cs.primary
                                  : cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  const Spacer(),
                ],
              ),
            ),
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    required this.block,
    required this.onChanged,
    required this.hint,
    this.style,
    this.maxLines = 1,
  });

  final Block block;
  final VoidCallback onChanged;
  final String hint;
  final TextStyle? style;
  final int? maxLines;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.block.text);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      style: widget.style,
      maxLines: widget.maxLines,
      minLines: 1,
      textAlign: TextAlign.right,
      onChanged: (v) {
        widget.block.text = v;
        widget.onChanged();
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
        hintStyle: widget.style?.copyWith(
            color: Theme.of(context).colorScheme.outline,
            fontWeight: FontWeight.w400),
      ),
    );
  }
}

class _QuoteEditor extends StatefulWidget {
  const _QuoteEditor({required this.block, required this.onChanged});
  final Block block;
  final VoidCallback onChanged;

  @override
  State<_QuoteEditor> createState() => _QuoteEditorState();
}

class _QuoteEditorState extends State<_QuoteEditor> {
  late final _text = TextEditingController(text: widget.block.text);
  late final _author = TextEditingController(text: widget.block.author);

  @override
  void dispose() {
    _text.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppTokens.brMd,
        border: BorderDirectional(
            start: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            maxLines: null,
            minLines: 1,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 15.5, fontWeight: FontWeight.w500, height: 1.9),
            onChanged: (v) {
              widget.block.text = v;
              widget.onChanged();
            },
            decoration: InputDecoration(
              hintText: 'نقل قول دلته ولیکئ…',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintStyle: TextStyle(color: cs.outline, fontSize: 15.5),
            ),
          ),
          const SizedBox(height: AppTokens.s8),
          Row(
            children: [
              Text('—',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _author,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant),
                  onChanged: (v) {
                    widget.block.author = v;
                    widget.onChanged();
                  },
                  decoration: InputDecoration(
                    hintText: 'د ویونکي نوم…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintStyle: TextStyle(color: cs.outline, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DividerPreview extends StatelessWidget {
  const _DividerPreview();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 160,
        height: 1.5,
        margin: const EdgeInsets.symmetric(vertical: AppTokens.s12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            cs.outline,
            Colors.transparent,
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د فایل بلاکونه
// ═══════════════════════════════════════════════════════════

class _FileBlock extends StatefulWidget {
  const _FileBlock({
    required this.block,
    required this.eventFolder,
    required this.onAttach,
    required this.onChanged,
    required this.dropping,
  });

  final Block block;
  final String eventFolder;
  final Future<void> Function(String) onAttach;
  final VoidCallback onChanged;
  final bool dropping;

  @override
  State<_FileBlock> createState() => _FileBlockState();
}

class _FileBlockState extends State<_FileBlock> {
  late final _caption = TextEditingController(text: widget.block.caption);

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final s = context.read<AppState>();
    final exts = switch (widget.block.kind) {
      BlockKind.image => MediaKind.image.extensions,
      BlockKind.video => MediaKind.video.extensions,
      BlockKind.audio => MediaKind.audio.extensions,
      _ => null,
    };
    final files = await s.backend.pickFiles(extensions: exts);
    if (files.isNotEmpty) await widget.onAttach(files.first);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = widget.block;
    final hasFile = b.source.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasFile)
          // خالي ساحه — دوه لارې: ډراپ یا انتخاب.
          InkWell(
            onTap: _browse,
            borderRadius: AppTokens.brLg,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.s32),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: AppTokens.brLg,
                border: Border.all(
                  color: widget.dropping ? cs.primary : cs.outlineVariant,
                  width: widget.dropping ? 2 : 1.4,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    widget.dropping
                        ? Icons.download_rounded
                        : switch (b.kind) {
                            BlockKind.image => Icons.add_photo_alternate_rounded,
                            BlockKind.video => Icons.video_call_rounded,
                            BlockKind.audio => Icons.mic_rounded,
                            _ => Icons.upload_file_rounded,
                          },
                    size: 30,
                    color: widget.dropping ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppTokens.s12),
                  Text(
                    widget.dropping
                        ? 'دلته یې پرېږدئ'
                        : 'فایل دلته راکش کړئ، یا یې د انتخاب لپاره ووهئ',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: widget.dropping ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'انتخاب شوی فایل به پخپله attachments ته ولېږدول شي',
                    style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          _FilePreview(
            block: b,
            eventFolder: widget.eventFolder,
            onReplace: _browse,
            onClear: () {
              b.source = '';
              widget.onChanged();
              setState(() {});
            },
          ),

        if (hasFile) ...[
          const SizedBox(height: AppTokens.s12),
          TextField(
            controller: _caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5),
            onChanged: (v) {
              b.caption = v;
              widget.onChanged();
            },
            decoration: const InputDecoration(
              hintText: 'د فایل وضاحت (اختیاري)…',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilePreview extends StatelessWidget {
  const _FilePreview({
    required this.block,
    required this.eventFolder,
    required this.onReplace,
    required this.onClear,
  });

  final Block block;
  final String eventFolder;
  final VoidCallback onReplace, onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = block.source.split('/').last;
    final full = p.join(eventFolder, block.source.replaceAll('/', p.separator));

    Widget body;
    if (block.kind == BlockKind.image && !kIsWeb && File(full).existsSync()) {
      body = ClipRRect(
        borderRadius: AppTokens.brMd,
        child: Image.file(File(full),
            height: 220, fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _placeholder(cs, name)),
      );
    } else {
      body = _placeholder(cs, name);
    }

    return Column(
      children: [
        body,
        const SizedBox(height: AppTokens.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(mediaIcon(MediaKind.ofPath(name)),
                size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: 5),
            Flexible(
              child: Text(name,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr),
            ),
            const SizedBox(width: AppTokens.s12),
            TextButton.icon(
              onPressed: onReplace,
              icon: const Icon(Icons.swap_horiz_rounded, size: 14),
              label: const Text('بدل کړه', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.link_off_rounded, size: 14),
              label: const Text('لرې کړه', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  foregroundColor: cs.error),
            ),
          ],
        ),
      ],
    );
  }

  Widget _placeholder(ColorScheme cs, String name) {
    final kind = MediaKind.ofPath(name);
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: mediaColor(kind).withValues(alpha: 0.08),
        borderRadius: AppTokens.brMd,
        border: Border.all(color: mediaColor(kind).withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(mediaIcon(kind), size: 34, color: mediaColor(kind)),
          const SizedBox(height: AppTokens.s8),
          Text(kind.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mediaColor(kind))),
        ],
      ),
    );
  }
}
