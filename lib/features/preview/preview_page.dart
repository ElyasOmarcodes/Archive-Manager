import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import 'export_bundle.dart';
import 'pdf_export.dart';

/// **د پیښې د پریویو پاڼه.**
///
/// همدا پاڼه د `index.html` د ښودلو پاڼه هم ده — کاروونکی دلته
/// انځورونه فول‌سکرین کوي، ویډیو/غږ پلې کوي او نور فایلونه د
/// «په بل پروګرام کې پرانیزه» له لارې خلاصوي.
class PreviewPage extends StatelessWidget {
  const PreviewPage({
    super.key,
    required this.event,
    required this.onBack,
    this.onEdit,
  });

  final EventMetadata event;
  final VoidCallback onBack;

  /// د «ایډیټ» تڼۍ — پیښه د طراحۍ پاڼې ته وړي.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── پورتنی بار ──
        Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              // په تنګو کچو کې د متن لرونکې تڼۍ آیکن ته اوړي، نو بار
              // هیڅکله بهر نه لویږي.
              // د «ایډیټ» او بیا د «PDF» تڼیو زیاتېدو سره ټولبار
              // پسې اوږد شو. د بشپړو لیبلونو سره اوس ~۹۰۵px غواړي،
              // نو پوله همدې ته پورته کوو — ګنې پر ۹۰۰×۶۰۰ کړکۍ کې
              // بهر لوېږي (په ازموینه کې ۷۵px).
              final wide = c.maxWidth >= 910;
              return Row(
                children: [
                  IconButton(
                    tooltip: 'بېرته ایډیټر ته',
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: AppTokens.s4),
                  Icon(Icons.visibility_rounded, size: 17, color: cs.primary),
                  if (wide) ...[
                    const SizedBox(width: 6),
                    const Text(
                      'پریویو',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // ── د دوه‌ګوني پرانیستلو تڼۍ ──
                  //
                  // دلته `Flexible` نه کاروو: هغه به د `Spacer` سره د
                  // پاتې ځای پر سر سیالي کوله او تڼۍ به یې راتنګوله.
                  // پرځای یې د `wide` له مخې بڼه بدلوو.
                  // ── PDF ته اکسپورټ ──
                  _ExportPdfButton(event: event, compact: !wide),
                  const SizedBox(width: AppTokens.s8),

                  // ── ایډیټ ──
                  if (onEdit != null) ...[
                    if (wide)
                      FilledButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 17),
                        label: const Text('ایډیټ'),
                      )
                    else
                      IconButton.filled(
                        tooltip: 'ایډیټ',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 19),
                      ),
                    const SizedBox(width: AppTokens.s8),
                  ],
                  _OpenWithButton(folder: event.folderPath, compact: !wide),
                  const SizedBox(width: AppTokens.s8),
                  if (wide)
                    OutlinedButton.icon(
                      onPressed: () => s.backend.openExternally(
                        p.join(event.folderPath, 'index.html'),
                      ),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 17),
                      label: const Text('په براوزر کې'),
                    )
                  else
                    IconButton(
                      tooltip: 'په براوزر کې پرانیزه',
                      onPressed: () => s.backend.openExternally(
                        p.join(event.folderPath, 'index.html'),
                      ),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 19),
                    ),
                ],
              );
            },
          ),
        ),

        // ── محتوا ──
        Expanded(
          child: Container(
            color: cs.surface,
            child: ScrollArea(
                builder: (context, sc) => SingleChildScrollView(
                controller: sc,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s24,
                        vertical: AppTokens.s32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Hero(event: event),
                          const SizedBox(height: AppTokens.s32),
                          for (final b in event.blocks)
                            _BlockView(block: b, folder: event.folderPath),
                          const SizedBox(height: AppTokens.s40),
                          _Footer(event: event),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// د پروژې مسیر د وینډوز یا داخلي اکسپلورر کې پرانیزي.
class _OpenWithButton extends StatelessWidget {
  const _OpenWithButton({required this.folder, this.compact = false});
  final String folder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTokens.brMd,
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _half(
            context,
            icon: Icons.desktop_windows_rounded,
            label: 'وینډوز',
            tooltip: 'په وینډوز اکسپلورر کې وښیه',
            onTap: () => s.backend.revealInFileManager(folder),
            radius: const BorderRadius.horizontal(
              right: Radius.circular(AppTokens.rMd),
            ),
          ),
          Container(width: 1, height: 22, color: cs.outlineVariant),
          _half(
            context,
            icon: Icons.folder_open_rounded,
            label: 'داخلي',
            tooltip: 'په داخلي اکسپلورر کې وښیه',
            onTap: () => s.openInExplorer(folder),
            radius: const BorderRadius.horizontal(
              left: Radius.circular(AppTokens.rMd),
            ),
          ),
        ],
      ),
    );
  }
}

extension on _OpenWithButton {
  Widget _half(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    required BorderRadius radius,
  }) {
    final shape = RoundedRectangleBorder(borderRadius: radius);
    if (compact) {
      return Tooltip(
        message: tooltip,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 38),
            shape: shape,
          ),
          child: Icon(icon, size: 17),
        ),
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: shape,
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.event});
  final EventMetadata event;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Column(
      children: [
        if (event.category.isNotEmpty || event.rating > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.s16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (event.category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      event.category,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                if (event.rating > 0) ...[
                  const SizedBox(width: AppTokens.s12),
                  StarRating(value: event.rating, size: 15),
                ],
              ],
            ),
          ),
        ShaderMask(
          shaderCallback: (r) =>
              LinearGradient(colors: [cs.onSurface, cs.primary])
                  .createShader(r),
          child: Text(
            event.title,
            textAlign: TextAlign.center,
            style: t.textTheme.displaySmall?.copyWith(color: Colors.white),
          ),
        ),
        if (event.summary.isNotEmpty) ...[
          const SizedBox(height: AppTokens.s12),
          Text(
            event.summary,
            textAlign: TextAlign.center,
            style: t.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: AppTokens.s24),
        // درې واړه تقویمونه
        Wrap(
          spacing: AppTokens.s8,
          runSpacing: AppTokens.s8,
          alignment: WrapAlignment.center,
          children: [
            for (final d in [
              ('هجري لمریز', event.date.shamsiText),
              ('هجري قمري', event.date.qamariText),
              ('میلادي', event.date.miladiText),
            ])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s12,
                  vertical: AppTokens.s8,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: AppTokens.brMd,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      d.$1,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      d.$2,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (event.persons.isNotEmpty || event.keywords.isNotEmpty) ...[
          const SizedBox(height: AppTokens.s16),
          Wrap(
            spacing: AppTokens.s6,
            runSpacing: AppTokens.s6,
            alignment: WrapAlignment.center,
            children: [
              for (final p in event.persons)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_rounded, size: 11, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        p,
                        style: TextStyle(fontSize: 11, color: cs.primary),
                      ),
                    ],
                  ),
                ),
              for (final k in event.keywords)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text(
                    '#$k',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppTokens.s24),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                cs.outlineVariant,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block, required this.folder});
  final Block block;
  final String folder;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.s24),
      child: switch (block.kind) {
        BlockKind.heading => Align(
          alignment: AlignmentDirectional.centerStart,
          // `stretch` د قدې محدودیت غواړي؛ دلته قد له متن څخه راځي،
          // نو IntrinsicHeight یې لومړی اندازه کوي.
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  margin: const EdgeInsets.only(left: AppTokens.s12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppTokens.brand, AppTokens.brandAlt],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Flexible(
                  child: Text(
                    block.text,
                    style: TextStyle(
                      fontSize: switch (block.level) {
                        1 => 28.0,
                        2 => 23.0,
                        3 => 19.0,
                        _ => 16.5,
                      },
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // لینکونه پخپله پېژندل کیږي او کلیک‌کېدونکي دي.
        BlockKind.paragraph => LinkedText(
          block.text,
          textAlign: TextAlign.right,
          style: t.textTheme.bodyLarge?.copyWith(height: 1.9),
        ),
        // د جوړ شوي `index.html` د `.quote` سټایل سره سم — هماغه
        // د برانډ رنګ کرښه د پیل خوا ته، هماغه لوی نقل نښه.
        // پخوا دلته یوازې یو ساده چوکاټ و، نو نقل قول د عادي متن
        // په څېر ښکارېده.
        BlockKind.quote => Container(
          padding: const EdgeInsets.all(AppTokens.s24),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: AppTokens.brLg,
            border: Border.all(color: cs.outlineVariant),
            // د پیل خوا ته پنډه رنګه کرښه (RTL کې ښي طرف ته)
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              stops: const [0, 0.006, 0.006],
              colors: [cs.primary, cs.primary, cs.surfaceContainerLowest],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -14,
                end: 4,
                child: Text(
                  '”',
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: cs.primary.withValues(alpha: 0.17),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinkedText(
                    block.text,
                    style: t.textTheme.titleMedium?.copyWith(
                      height: 1.9,
                      fontSize: 16,
                    ),
                  ),
                  if (block.author.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.s12),
                    Text(
                      '— ${block.author}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        BlockKind.divider => Center(
          child: Container(
            width: 160,
            height: 1.5,
            margin: const EdgeInsets.symmetric(vertical: AppTokens.s16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, cs.outline, Colors.transparent],
              ),
            ),
          ),
        ),
        _ => _MediaView(block: block, folder: folder),
      },
    );
  }
}

/// انځور / ویډیو / غږ / نور فایلونه — تل منځ ته.
class _MediaView extends StatelessWidget {
  const _MediaView({required this.block, required this.folder});
  final Block block;
  final String folder;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (block.source.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTokens.s24),
        decoration: BoxDecoration(
          borderRadius: AppTokens.brLg,
          border: Border.all(color: cs.outlineVariant, width: 1.4),
        ),
        child: Center(
          child: Text(
            '${block.kind.label} نه دی ټاکل شوی',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final name = block.source.split('/').last;
    final full = p.join(folder, block.source.replaceAll('/', p.separator));
    final kind = MediaKind.ofPath(name);

    // انځور — وهل یې فول‌سکرین کوي.
    if (block.kind == BlockKind.image && !kIsWeb && File(full).existsSync()) {
      return Column(
        children: [
          GestureDetector(
            onTap: () => _fullscreen(context, full, block.caption),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ClipRRect(
                borderRadius: AppTokens.brLg,
                child: Image.file(
                  File(full),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _card(context, kind, name),
                ),
              ),
            ),
          ),
          if (block.caption.isNotEmpty) _caption(context, block.caption),
        ],
      );
    }

    return Column(
      children: [
        _card(context, kind, name, onTap: () => s.backend.openExternally(full)),
        if (block.caption.isNotEmpty) _caption(context, block.caption),
      ],
    );
  }

  Widget _caption(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: AppTokens.s8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );

  Widget _card(
    BuildContext context,
    MediaKind kind,
    String name, {
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return HoverLift(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppTokens.base,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s20,
          vertical: AppTokens.s24,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: AppTokens.brLg,
          border: Border.all(
            color: hovered ? mediaColor(kind) : cs.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: mediaColor(kind).withValues(alpha: 0.12),
                borderRadius: AppTokens.brMd,
              ),
              child: Icon(mediaIcon(kind), size: 25, color: mediaColor(kind)),
            ),
            const SizedBox(width: AppTokens.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                  ),
                  Text(
                    onTap == null
                        ? kind.label
                        : 'د پرانیستلو لپاره یې ووهئ — ${kind.label}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.open_in_new_rounded,
                size: 17,
                color: mediaColor(kind),
              ),
          ],
        ),
      ),
    );
  }

  void _fullscreen(BuildContext context, String path, String caption) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.93),
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Image.file(File(path))),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 24,
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 26,
              ),
              onPressed: () => Navigator.pop(ctx),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          if (caption.isNotEmpty)
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.event});
  final EventMetadata event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(height: 1, color: cs.outlineVariant),
        const SizedBox(height: AppTokens.s16),
        Wrap(
          spacing: AppTokens.s12,
          alignment: WrapAlignment.center,
          children: [
            Text(
              event.title,
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
            Text('·', style: TextStyle(color: cs.outline)),
            Text(
              event.date.shamsiText,
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
            if (event.attachments.isNotEmpty) ...[
              Text('·', style: TextStyle(color: cs.outline)),
              Text(
                '${event.attachments.length} فایلونه',
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// **د PDF اکسپورټ تڼۍ.**
///
/// دوسیه د پیښې فولډر دننه ساتل کیږي (`<نوم>.pdf`)، نو له نورو
/// شواهدو سره یو ځای پاتې کیږي.
/// **د اکسپورټ تڼۍ — دوه لارې.**
///
/// کاروونکي وویل: «د اکسپورټ برخه کې دوه افشن جوړ کړه — فقط
/// pdf، او د zip چې هم pdf لري داخل کې او هم ضمیمه شوي فایلونه».
///
/// نو یوه منو ده: لومړی یې د چاپ/لېږلو لپاره، دوهم یې د بشپړې
/// بستې لپاره. دواړه هماغه یوه PDF کاروي — نو څه توپیر نه لري
/// چې کوم یو غوره کړې، سند یو دی.
class _ExportPdfButton extends StatefulWidget {
  const _ExportPdfButton({required this.event, this.compact = false});

  final EventMetadata event;
  final bool compact;

  @override
  State<_ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends State<_ExportPdfButton> {
  bool _busy = false;

  Future<void> _run(ExportKind kind) async {
    if (_busy) return;
    setState(() => _busy = true);

    final s = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // انځورونه له ډیسکه راوړو — نو په PDF کې ریښتیا ښکاره شي.
      // ویډیو/غږ نه راوړو: PDF یې نه چلوي، نو یوازې کرښه ورکوو.
      final images = <String, Uint8List>{};
      for (final b in widget.event.blocks) {
        if (b.kind != BlockKind.image || b.source.isEmpty) continue;
        final bytes = await s.backend
            .readBytes(p.join(widget.event.folderPath, b.source));
        if (bytes != null) images[b.source] = Uint8List.fromList(bytes);
      }

      final base = _safeName(widget.event.title);
      final pdf = await EventPdf.build(widget.event, images: images);

      final (name, bytes) = switch (kind) {
        ExportKind.pdf => ('$base.pdf', pdf),
        ExportKind.zip => (
            '$base.zip',
            await ExportBundle.build(
              event: widget.event,
              pdf: pdf,
              pdfName: '$base.pdf',
              readBytes: s.backend.readBytes,
            ),
          ),
      };

      // **د وینډوز خپل «چیرې یې ثبت کړو؟» ډایلوګ.**
      //
      // کاروونکي وویل: «کله چې اکسپورټ کوو نو د وینډوز د ثبت پاڼه
      // راشي». پخوا دوسیه چوپه د پیښې فولډر ته تله. اوس کاروونکی
      // ټاکي — او که لغوه یې کړه، هیڅ نه لیکل کیږي.
      //
      // په ویب/نندارې نسخه کې ډایلوګ نشته، نو هلته پخوانۍ لار
      // پاتې ده (او هغه هم `null` راګرځوي — پیغام یې ښیي).
      String? saved;
      var canceled = false;
      if (s.backend.isReal) {
        // **کوم مسیر لومړی وښیو؟**
        //
        // ۱. هغه چې کاروونکي وروستی ځل وټاکه (تنظیماتو کې پروت دی)
        // ۲. که نه وي: `Documents/د آرشیف نهایي فایلونه`
        //
        // د پیښې پوښۍ نه ښیو — کاروونکي وویل چې وروستی کارول شوی
        // مسیر باید ډیفالټ وي.
        final start = s.settings.exportDir ??
            await s.backend.defaultExportDir();

        saved = await s.backend.saveFileAs(
          fileName: name,
          bytes: bytes,
          initialDirectory: start,
          mimeType: kind == ExportKind.pdf ? 'application/pdf' : 'application/zip',
        );
        canceled = saved == null;
        // راتلونکی ځل هماغه پوښۍ پرانیزي.
        if (saved != null) await s.rememberExportDir(p.dirname(saved));
      } else {
        saved = await s.backend
            .writeBytes(p.join(widget.event.folderPath, name), bytes);
      }

      if (!mounted) return;
      if (canceled) {
        _say(messenger, 'اکسپورټ لغوه شو');
      } else if (saved == null) {
        _say(messenger, 'په دې نسخه کې فایل ثبتول ناشوني دي');
      } else {
        _say(
          messenger,
          'ثبت شو: $name  ·  ${humanBytes(bytes.length)}',
          action: SnackBarAction(
            label: 'پرانیزه',
            onPressed: () => s.backend.openExternally(saved!),
          ),
        );
      }
    } catch (e) {
      if (mounted) _say(messenger, 'اکسپورټ ناکام شو: $e');
    } finally {
      // **دا `mounted` ته نه ګوري.** کاروونکي وویل: «که د وينډوز
      // اکسپلورر بیرته کنسل کړو نو اکسپورټ بټن باندې دوام لرونکی
      // پروګرس راځي چې بیا د کلیک وړ نه وي». علت دا و چې د حالت
      // بیا‌ټاکنه یوازې هغه وخت کېده چې ویجټ ژوندی وي — نو که
      // کاروونکی د ډایلوګ پر مهال بلې پاڼې ته تللی و، بېرغ تر ابده
      // «بوخت» پاتې کېده. اوس بېرغ **تل** پاک شي؛ یوازې د پردې
      // تازه کول د `mounted` تابع دي.
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  /// **یو ټوسټ چې پخپله ځي.**
  ///
  /// کاروونکي وویل: «ټوسټ باید په یوه ټاکلې مودې کې پخپله ورک
  /// شي». نو:
  ///
  /// * مخکینی ټوسټ سمدلاسه لرې کیږي — نو دوه یو پر بل نه پاتې
  ///   کیږي او نوی سمدلاسه ښکاري.
  /// * موده څرګنده ده (۵ ثانیې)، نه د Material پر ډیفالټ پرېښودل
  ///   شوې.
  /// * **`persist: false`** — همدا هغه باګ و. د Material قاعده
  ///   داسې ده: که یو ټوسټ `action` ولري، `persist` پخپله `true`
  ///   کیږي او ټوسټ **هیڅکله پخپله نه ځي**. زمونږ د بریا ټوسټ
  ///   «پرانیزه» تڼۍ لري — نو پر پردې ټینګ پاتې کېده.
  /// * د تړلو ایکن هم لري — که کاروونکی یې لا ژر وغواړي.
  static void _say(ScaffoldMessengerState m, String text,
      {SnackBarAction? action}) {
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: action,
        persist: false,
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating,
        width: 460,
        duration: const Duration(seconds: 5),
      ));
  }

  /// د فایل نوم کې ناروا کرکټرونه لرې کوي.
  static String _safeName(String s) {
    var v = s.trim().replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ');
    v = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (v.isEmpty) v = 'پیښه';
    return v.length > 100 ? v.substring(0, 100) : v;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.ios_share_rounded, size: 17);

    return PopupMenuButton<ExportKind>(
      enabled: !_busy,
      tooltip: 'اکسپورټ',
      position: PopupMenuPosition.under,
      onSelected: _run,
      itemBuilder: (_) => [
        for (final k in ExportKind.values)
          PopupMenuItem(
            value: k,
            child: Row(
              children: [
                Icon(
                  k == ExportKind.pdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.folder_zip_rounded,
                  size: 18,
                  color: cs.primary,
                ),
                const SizedBox(width: AppTokens.s12),
                // **`Expanded` اړین دی.** د منو پلنوالی محدود دی
                // (~۲۵۶px)، او د دوهم افشن توضیح تر هغه اوږده ده —
                // نو پرته له دې، کرښه بهر لویده.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(k.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(k.hint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: widget.compact
          ? SizedBox(
              width: AppTokens.controlH,
              height: AppTokens.controlH,
              child: Center(child: icon),
            )
          : Container(
              height: AppTokens.controlH,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTokens.s16),
              decoration: BoxDecoration(
                borderRadius: AppTokens.brMd,
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: AppTokens.s8),
                  Text(_busy ? 'جوړیږي…' : 'اکسپورټ',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary)),
                  const SizedBox(width: 2),
                  Icon(Icons.expand_more_rounded, size: 16, color: cs.primary),
                ],
              ),
            ),
    );
  }
}
