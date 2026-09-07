import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// یوه برخه د حلقې دننه.
class RingSlice {
  const RingSlice({required this.value, required this.color, this.label = ''});
  final double value;
  final Color color;
  final String label;
}

/// **د حلقې چارټ** — د ډرایو د ځای او د فایلونو د ویش لپاره.
///
/// له صفر څخه خپلې وروستۍ کچې ته ځغلي، نو د پاڼې پرانیستل ژوندی وي.
class RingChart extends StatelessWidget {
  const RingChart({
    super.key,
    required this.slices,
    this.size = 132,
    this.thickness = 13,
    this.gapDegrees = 2.5,
    this.center,
  });

  final List<RingSlice> slices;
  final double size;
  final double thickness;

  /// د برخو ترمنځ کوچنۍ تشه — نو رنګونه سره نه ګډیږي.
  final double gapDegrees;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTokens.slower,
      curve: AppTokens.easeInOut,
      builder: (context, t, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                slices: slices,
                thickness: thickness,
                gapRadians: gapDegrees * math.pi / 180,
                progress: t,
                trackColor: cs.surfaceContainerHigh,
              ),
            ),
            if (center != null)
              Opacity(opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0), child: center),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.slices,
    required this.thickness,
    required this.gapRadians,
    required this.progress,
    required this.trackColor,
  });

  final List<RingSlice> slices;
  final double thickness;
  final double gapRadians;
  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(thickness / 2, thickness / 2) &
        Size(size.width - thickness, size.height - thickness);
    final total = slices.fold<double>(0, (a, s) => a + s.value);

    // ── شاليد ──
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = trackColor,
    );
    if (total <= 0) return;

    // **د لیدو وړ لږ‌تر‌لږه قوس.**
    //
    // پخوا هره برخه چې تر تشې (gap) وړه وه، بیخي غورځېده. نو که
    // یو ۹۶GB ډرایو یوازې ۴۷۹MB ډک وي (۰.۵٪)، «کارول شوې» برخه
    // هیڅ نه رسمېده او حلقه تشه ښکارېده — لکه چې خرابه وي.
    //
    // اوس هره برخه چې ارزښت یې تر صفر پورته وي، لږ‌تر‌لږه ~۳°
    // ځای نیسي. دا د ډیټا تحریف نه دی — برخه ریښتیا شته، مونږ
    // یوازې تضمینوو چې د سترګو په واسطه ولیدل شي.
    final minSweep = gapRadians + 0.052;

    // له پورته څخه پیل (‑۹۰°)
    var start = -math.pi / 2;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final real = (s.value / total) * math.pi * 2 * progress;
      // د حرکت پر مهال (progress→۰) لږ‌تر‌لږه هم صفر ته ځي، نو
      // انیمیشن له تشې پیلیږي، نه له درې درجو.
      final sweep = math.max(real, minSweep * progress);
      // د حرکت په پیل کې `sweep` صفر ته نږدې وي — هلته د رسمولو
      // څه نشته، او `SweepGradient` هم صفر پلن قوس نه مني.
      if (sweep <= gapRadians) {
        start += real;
        continue;
      }
      canvas.drawArc(
        rect,
        start + gapRadians / 2,
        sweep - gapRadians,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + sweep,
            colors: [s.color.withValues(alpha: 0.72), s.color],
          ).createShader(rect),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.slices != slices ||
      old.trackColor != trackColor;
}
