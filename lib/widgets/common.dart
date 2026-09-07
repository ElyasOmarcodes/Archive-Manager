import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/date/pashto_calendar.dart';
import '../core/text/pashto_text.dart';
import '../core/theme/tokens.dart';
import '../data/models/models.dart';
import '../data/repository/app_state.dart';

// ═══════════════════════════════════════════════════════════
//  حرکتونه
// ═══════════════════════════════════════════════════════════

/// یو ویجټ چې په نرم ډول ښکته/پورته او روښانه کیږي — د لیستونو لپاره.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.05),
    this.duration = AppTokens.enter,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  // یو ځل جوړیږي، نه په هر `build` کې. پخوا یې هر ځل نوی
  // `CurvedAnimation` جوړاوه — هغه اوریدونکي پرېښودل او د هر
  // فریم لپاره یې کار زیاتاوه.
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: AppTokens.ease);
  late final Animation<Offset> _slide =
      Tween(begin: widget.offset, end: Offset.zero).animate(_fade);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ساده ساتل شوی دی په قصد سره. یو «هوښیار» بڼه هم وازمویل شوه —
    // چې د حرکت له پای ته رسېدو روسته پوړونه لرې کړي — خو هغه د ونې
    // بڼه بدلوله، نو ټول کارتونه یو ځل بیا پر ځای شول (relayout).
    // اندازه‌ګیري یې وښوده: ۲۹۵۰ms → ۳۷۰۵ms. نو دا بڼه غوره ده.
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// د ماوس د تېرېدو پر مهال یو څه پورته کېږي — «ژوندی» احساس ورکوي.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.builder,
    this.lift = 3,
    this.scale = 1.0,
    this.onTap,
  });

  final Widget Function(BuildContext, bool hovered) builder;
  final double lift;
  final double scale;
  final VoidCallback? onTap;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedSlide(
          duration: AppTokens.base,
          curve: AppTokens.ease,
          offset: Offset(0, _h ? -widget.lift / 100 : 0),
          child: AnimatedScale(
            duration: AppTokens.base,
            curve: AppTokens.ease,
            scale: _h ? widget.scale : 1.0,
            child: widget.builder(context, _h),
          ),
        ),
      ),
    );
  }
}

/// یو عدد چې له صفر څخه خپلې وروستۍ ارزښت ته ځغلي.
class CountUp extends StatelessWidget {
  const CountUp(this.value,
      {super.key, this.style, this.duration = AppTokens.slower, this.suffix = ''});

  final int value;
  final TextStyle? style;
  final Duration duration;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: AppTokens.easeInOut,
      builder: (_, v, _) => Text(
        '${PashtoDigits.to(v.round())}$suffix',
        style: style,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  بنسټیز اجزا
// ═══════════════════════════════════════════════════════════

/// یو پاک کارت — د پروګرام د ټولو برخو بنسټ.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.s20),
    this.onTap,
    this.accent,
    this.accentTooltip,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// که ورکړل شي، د کارت پورتنۍ څنډه پرې رنګیږي.
  final Color? accent;

  /// د رنګې څنډې تشریح — د ماوس پر تېرېدو ښکاري.
  final String? accentTooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return HoverLift(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppTokens.base,
        curve: AppTokens.ease,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: AppTokens.brLg,
          border: Border.all(
            color: selected
                ? cs.primary
                : hovered && onTap != null
                    ? cs.outline
                    : cs.outlineVariant,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            if (hovered && onTap != null)
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppTokens.brLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (accent != null)
                Tooltip(
                  message: accentTooltip ?? '',
                  child: Container(height: 3, color: accent),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// د پاڼې سرلیک + وضاحت + عملونه.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.icon,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTokens.brand, AppTokens.brandAlt],
              ),
              borderRadius: AppTokens.brMd,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppTokens.s16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: t.textTheme.headlineSmall),
              if (subtitle != null)
                Text(subtitle!, style: t.textTheme.bodySmall),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// د ستورو درجه‌بندي — لوستل او لیکل دواړه.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 18,
    this.color,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = color ?? AppTokens.amber;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          _Star(
            filled: i <= value,
            size: size,
            activeColor: active,
            inactiveColor: cs.outlineVariant,
            // بیا وهل یې پاکوي — د Bridge په څېر.
            onTap: onChanged == null
                ? null
                : () => onChanged!(value == i ? 0 : i),
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({
    required this.filled,
    required this.size,
    required this.activeColor,
    required this.inactiveColor,
    this.onTap,
  });

  final bool filled;
  final double size;
  final Color activeColor, inactiveColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final star = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: filled ? 1 : 0),
      duration: AppTokens.base,
      curve: AppTokens.spring,
      builder: (_, v, _) => Transform.scale(
        scale: 0.85 + 0.15 * v,
        child: Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: Color.lerp(inactiveColor, activeColor, v),
        ),
      ),
    );
    if (onTap == null) return Padding(padding: const EdgeInsets.all(1), child: star);
    return InkResponse(
      onTap: onTap,
      radius: size * 0.8,
      child: Padding(padding: const EdgeInsets.all(2), child: star),
    );
  }
}

/// د رنګ ټګ ټاکونکی — د Bridge د Label سیسټم په څېر.
class ColorTagPicker extends StatelessWidget {
  const ColorTagPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
  });

  final ColorTag value;
  final ValueChanged<ColorTag> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppTokens.s8,
      runSpacing: AppTokens.s8,
      children: [
        for (final c in ColorTag.values)
          Tooltip(
            // معنا هم ښیو — نو کاروونکی پوهیږي چې رنګ څه ښیي.
            message: '${c.label} — ${c.meaning}',
            child: InkResponse(
              onTap: () => onChanged(c),
              radius: size * 0.75,
              child: AnimatedContainer(
                duration: AppTokens.fast,
                curve: AppTokens.ease,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: c == ColorTag.none ? Colors.transparent : c.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value == c ? cs.onSurface : c.color.withValues(alpha: 0.5),
                    width: value == c ? 2.4 : 1.4,
                  ),
                ),
                child: c == ColorTag.none
                    ? Icon(Icons.block_rounded,
                        size: size * 0.6, color: cs.onSurfaceVariant)
                    : value == c
                        ? Icon(Icons.check_rounded,
                            size: size * 0.62, color: Colors.white)
                        : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// د ټاکل شوي رنګ معنا — د رنګ ټاکونکي لاندې یوه کوچنۍ کرښه.
class ColorTagMeaning extends StatelessWidget {
  const ColorTagMeaning({super.key, required this.value});
  final ColorTag value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.s8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: value == ColorTag.none ? cs.outline : value.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '${value.label} · ${value.meaning}',
              style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// یو چیپ چې ټاکل کیدی شي، او اختیاري شمېره ښیي.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.color,
    this.icon,
    this.onDelete,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = color ?? cs.primary;
    final disabled = count == 0 && !selected;

    return Opacity(
      opacity: disabled ? 0.42 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: AppTokens.fast,
            curve: AppTokens.ease,
            padding: EdgeInsets.only(
              right: AppTokens.s12,
              left: onDelete != null ? AppTokens.s6 : AppTokens.s12,
              top: 7,
              bottom: 7,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.14)
                  : cs.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? accent : cs.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14,
                      color: selected ? accent : cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                ] else if (color != null) ...[
                  Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                // اوږد کیورډ یا کټګوري باید چیپ ونه شلوي — کله چې چیپ
                // په تنګ پینل کې وي، متن یې لنډیږي نه چې بهر ووځي.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? accent : cs.onSurface,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.2)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      PashtoDigits.to(count!),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? accent : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  InkResponse(
                    onTap: onDelete,
                    radius: 12,
                    child: Icon(Icons.close_rounded,
                        size: 14, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// د لټون بکس.
class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.controller,
    this.hint = 'لټون…',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.width,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.search_rounded, size: 19,
              color: cs.onSurfaceVariant),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 36),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, v, _) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 17),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                    splashRadius: 15,
                  ),
          ),
        ),
      ),
    );
  }
}

/// یو پرمختګ بار د سرلیک او سلنې سره — د ډاشبورډ لپاره.
class LabeledProgress extends StatelessWidget {
  const LabeledProgress({
    super.key,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    this.icon,
    this.delay = Duration.zero,
  });

  final String label;
  final int value;
  final int total;
  final Color color;
  final IconData? icon;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = total == 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w500)),
            ),
            Text(
              '${PashtoDigits.to(value)}  ·  ${PashtoDigits.to((ratio * 100).round())}٪',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.s8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: AppTokens.slower,
          curve: AppTokens.easeInOut,
          builder: (_, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 7, color: cs.surfaceContainerHigh),
                FractionallySizedBox(
                  widthFactor: v.clamp(0.0, 1.0),
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.65), color],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// خالي حالت — کله چې هیڅ پایله نه وي.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Center(
      child: FadeSlideIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTokens.s20),
            Text(title, style: t.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: AppTokens.s6),
              SizedBox(
                width: 320,
                child: Text(message!,
                    textAlign: TextAlign.center, style: t.textTheme.bodySmall),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTokens.s20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// د یوې برخې سرلیک — د پینلونو دننه.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.icon});
  final String text;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.s12, top: AppTokens.s4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  لینک‌لرونکی متن
// ═══════════════════════════════════════════════════════════

/// **ساده متن چې لینکونه یې پخپله پېژندل کیږي او کلیک‌کېدونکي دي.**
///
/// کاروونکی په پاراګراف کې یوازې پته لیکي — `https://…` یا
/// `www.…` یا بریښنالیک — او دلته پخپله رنګه، ښکته‌کرښه لرونکې
/// او کلیک‌کېدونکې راځي. په یوه کلیک براوزر کې پرانیستل کیږي.
class LinkedText extends StatefulWidget {
  const LinkedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  /// د هرې برخې لپاره یو `TapGestureRecognizer` — باید له منځه
  /// یوسل شي، ګنې حافظه پاتې کیږي.
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final chunks = linkify(widget.text);

    // هیڅ لینک نشته → ساده `Text`، بې اضافي کار.
    if (!chunks.any((c) => c.isLink)) {
      return Text(widget.text, style: base, textAlign: widget.textAlign);
    }

    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();

    final spans = <InlineSpan>[];
    for (final c in chunks) {
      if (!c.isLink || !isSafeUrl(c.url!)) {
        spans.add(TextSpan(text: c.text, style: base));
        continue;
      }
      final tap = TapGestureRecognizer()
        ..onTap = () => _open(context, c.url!);
      _taps.add(tap);
      spans.add(TextSpan(
        text: c.text,
        recognizer: tap,
        style: base.copyWith(
          color: cs.primary,
          decoration: TextDecoration.underline,
          decorationColor: cs.primary.withValues(alpha: 0.4),
          fontWeight: FontWeight.w600,
        ),
      ));
    }

    return RichText(
      textAlign: widget.textAlign ?? TextAlign.start,
      textDirection: Directionality.of(context),
      text: TextSpan(children: spans),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final s = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await s.backend.openExternally(url);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('لینک پرانیستل ونه شو: $url')),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  د ټولېدو وړ برخه
// ═══════════════════════════════════════════════════════════

/// **یوه برخه چې ټولیږي او خپریږي.**
///
/// سرلیک یې د `SectionLabel` په څېر ښکاري، خو کلیک‌کېدونکی دی او
/// یوه غشۍ لري. کله چې ډېرې برخې ولرو (میټاډیټا پینل، فلټر پینل)،
/// کاروونکی هغه چې پرې کار نه کوي ټولولی شي — نو پاڼه لنډه او
/// روښانه پاتې کیږي.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.badge,
    this.trailing,
    this.initiallyExpanded = true,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  /// یوه کوچنۍ تڼۍ چې د سرلیک په څنډه کې ښکاري (لکه «پاک کړه»).
  final Widget? trailing;

  /// یو کوچنی عدد/متن چې د ټولېدو پر مهال هم ښکاري — نو کاروونکی
  /// پوهیږي چې دننه څه شته، بې له پرانیستلو.
  final String? badge;

  final bool initiallyExpanded;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: AppTokens.brSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.s8),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (widget.badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.badge!,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.trailing != null) ...[
                  widget.trailing!,
                  const SizedBox(width: 4),
                ],
                AnimatedRotation(
                  turns: _open ? 0 : -0.25,
                  duration: AppTokens.fast,
                  curve: AppTokens.ease,
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        // `AnimatedSize` د بندېدو پر مهال نرم راټولوي، خو کله چې
        // تړل شوې وي، محتوا بیخي له ونې وځي — نو هیڅ نه رسمیږي.
        AnimatedSize(
          duration: AppTokens.fast,
          curve: AppTokens.ease,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.s4),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ابزارونه
// ═══════════════════════════════════════════════════════════

/// بایټونه انساني بڼې ته: `۳۸۰ MB`
String humanBytes(int bytes) {
  if (bytes <= 0) return '۰';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  final i = (math.log(bytes) / math.log(1024)).floor().clamp(0, units.length - 1);
  final v = bytes / math.pow(1024, i);
  final s = i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(v < 10 ? 1 : 0);
  return '${PashtoDigits.to(s)} ${units[i]}';
}

/// د فایل ډول → آیکن.
IconData mediaIcon(MediaKind k) => switch (k) {
      MediaKind.image => Icons.image_rounded,
      MediaKind.video => Icons.movie_rounded,
      MediaKind.audio => Icons.graphic_eq_rounded,
      MediaKind.document => Icons.description_rounded,
      MediaKind.sheet => Icons.table_chart_rounded,
      MediaKind.archive => Icons.folder_zip_rounded,
      MediaKind.other => Icons.insert_drive_file_rounded,
    };

/// د فایل ډول → رنګ.
Color mediaColor(MediaKind k) => switch (k) {
      MediaKind.image => AppTokens.sky,
      MediaKind.video => AppTokens.rose,
      MediaKind.audio => AppTokens.violet,
      MediaKind.document => AppTokens.teal,
      MediaKind.sheet => AppTokens.green,
      MediaKind.archive => AppTokens.amber,
      MediaKind.other => AppTokens.orange,
    };

/// یو لنډ پیغام ښیي.
void toast(BuildContext context, String message, {bool error = false}) {
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 18,
            color: error ? cs.error : AppTokens.green,
          ),
          const SizedBox(width: AppTokens.s12),
          Expanded(child: Text(message)),
        ],
      ),
      duration: const Duration(seconds: 3),
      width: 420,
    ));
}

/// متن کاپي کوي او خبر ورکوي.
Future<void> copyText(BuildContext context, String text, {String? label}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, '${label ?? 'متن'} کاپي شو');
}
