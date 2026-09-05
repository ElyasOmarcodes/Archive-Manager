import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/platform/backend.dart';
import '../../widgets/common.dart';

/// **د فایل ټامنیل** — د انځورونو لپاره ریښتینی کوچنی انځور،
/// د نورو لپاره رنګین آیکن.
///
/// انځورونه د `cacheWidth` په مرسته لوستل کیږي، نو یو ۴۰MB انځور هم
/// یوازې د ټامنیل په کچه حافظه نیسي — نه بشپړ.
class FileThumb extends StatelessWidget {
  const FileThumb({
    super.key,
    required this.entry,
    required this.size,
    this.color,
  });

  final FsEntry entry;
  final double size;
  final Color? color;

  static const _maxThumbBytes = 40 * 1024 * 1024;

  IconData get _icon {
    if (entry.isEventFolder) return Icons.auto_awesome_mosaic_rounded;
    if (entry.isDirectory) return Icons.folder_rounded;
    return mediaIcon(entry.kind);
  }

  Color _tint(BuildContext context) {
    if (color != null) return color!;
    if (entry.isEventFolder) return AppTokens.brand;
    if (entry.isDirectory) return AppTokens.amber;
    return mediaColor(entry.kind);
  }

  bool get _canThumb =>
      !kIsWeb &&
      !entry.isDirectory &&
      entry.kind == MediaKind.image &&
      entry.sizeBytes > 0 &&
      entry.sizeBytes <= _maxThumbBytes &&
      entry.path.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tint = _tint(context);

    if (!_canThumb) return _iconOnly(tint);

    final file = File(entry.path);
    if (!file.existsSync()) return _iconOnly(tint);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.rSm),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // یوازې د اړتیا وړ پکسلونه لوستل کیږي (۲× د ښکلا لپاره)
        cacheWidth: (size * 2).round(),
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        // که انځور خراب وي یا نه لوستل کیږي، آیکن ته ورګرځو
        errorBuilder: (_, _, _) => _iconOnly(tint),
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync || frame != null) {
            return AnimatedOpacity(
              opacity: 1,
              duration: AppTokens.fast,
              child: child,
            );
          }
          return _iconOnly(tint, faded: true);
        },
      ),
    );
  }

  Widget _iconOnly(Color tint, {bool faded = false}) => SizedBox(
        width: size,
        height: size,
        child: Opacity(
          opacity: faded ? 0.35 : 1,
          child: Icon(_icon, size: size * 0.8, color: tint),
        ),
      );
}
