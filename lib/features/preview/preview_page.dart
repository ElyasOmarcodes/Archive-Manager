import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **د پیښې د پریویو پاڼه.**
///
/// همدا پاڼه د `index.html` د ښودلو پاڼه هم ده — کاروونکی دلته
/// انځورونه فول‌سکرین کوي، ویډیو/غږ پلې کوي او نور فایلونه د
/// «په بل پروګرام کې پرانیزه» له لارې خلاصوي.
class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key, required this.event, required this.onBack});

  final EventMetadata event;
  final VoidCallback onBack;

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
          child: Row(
            children: [
              IconButton(
                tooltip: 'بېرته ایډیټر ته',
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                onPressed: onBack,
              ),
              const SizedBox(width: AppTokens.s8),
              Icon(Icons.visibility_rounded, size: 17, color: cs.primary),
              const SizedBox(width: 6),
              const Text(
                'پریویو',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              // ── د دوه‌ګوني پرانیستلو تڼۍ ──
              _OpenWithButton(folder: event.folderPath),
              const SizedBox(width: AppTokens.s8),
              OutlinedButton.icon(
                onPressed: () => s.backend.openExternally(
                  p.join(event.folderPath, 'index.html'),
                ),
                icon: const Icon(Icons.open_in_browser_rounded, size: 17),
                label: const Text('په براوزر کې'),
              ),
            ],
          ),
        ),

        // ── محتوا ──
        Expanded(
          child: Container(
            color: cs.surface,
            child: Scrollbar(
              child: SingleChildScrollView(
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
  const _OpenWithButton({required this.folder});
  final String folder;

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
          TextButton.icon(
            onPressed: () => s.backend.revealInFileManager(folder),
            icon: const Icon(Icons.desktop_windows_rounded, size: 16),
            label: const Text('وینډوز', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(AppTokens.rMd),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 22, color: cs.outlineVariant),
          TextButton.icon(
            onPressed: () => s.openInExplorer(folder),
            icon: const Icon(Icons.folder_open_rounded, size: 16),
            label: const Text('داخلي', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(AppTokens.rMd),
                ),
              ),
            ),
          ),
        ],
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
        BlockKind.paragraph => Text(
          block.text,
          textAlign: TextAlign.right,
          style: t.textTheme.bodyLarge?.copyWith(height: 1.9),
        ),
        BlockKind.quote => Container(
          padding: const EdgeInsets.all(AppTokens.s24),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: AppTokens.brLg,
            border: Border.all(color: cs.outlineVariant),
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
                  Text(
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
