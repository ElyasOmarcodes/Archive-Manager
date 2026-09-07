import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';

import 'window_controls.dart'
    if (dart.library.io) 'window_controls_io.dart';

/// **د پروګرام خپل ټایټل بار — د macOS په څېر.**
///
/// د وینډوز اصلي بار پټ دی. پرځای یې دا کرښه راځي:
///
/// ```
/// ● ● ●            د آرشیف چټک مدیر            [حالت]
/// ```
///
/// * درې ګردې تڼۍ **چپ لور ته** — دقیقاً لکه macOS. رنګونه یې هم
///   هماغه دي: سور (تړل)، ژیړ (ښکته)، شین (لوی/کوچنی).
/// * ایکنونه یوازې د ماوس د تېرېدو پر مهال ښکاري — نوی macOS
///   همداسې کوي؛ په عادي حالت کې یوازې پاک رنګین دایرې دي.
/// * سرلیک په **منځ** کې، نری او خړ — نه ډبل، نه ځلېدونکی.
/// * ټوله کرښه د **کش کولو** وړ ده، او دوه‌ځله کلیک یې لوی/کوچنی
///   کوي — لکه هر عادي کړکۍ.
///
/// **پام:** دا په RTL کې هم چپ لور ته پاتې کیږي. د macOS تڼۍ د
/// ژبې له لوري سره نه ګرځي، نو مونږ یې هم `Directionality` په
/// `ltr` کې تړو.
class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key});

  /// د بار لوړوالی — د macOS معیار ته نږدې.
  static const double height = 38;

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> {
  bool _hovered = false;

  /// د سکرین‌شاټ لپاره یې په ویب کې هم ښکاره کولی شو:
  /// `flutter build web --dart-define=FORCE_TITLE_BAR=true`
  ///
  /// په هغه جوړونه کې تڼۍ بې‌اثره وي (ویب کړکۍ نه لري) — نو یوازې
  /// د ډیزاین د کتلو لپاره ده، نه د خپرولو لپاره.
  static const _force = bool.fromEnvironment('FORCE_TITLE_BAR');

  @override
  Widget build(BuildContext context) {
    if (!hasCustomTitleBar && !_force) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final s = context.watch<AppState>();

    // **`Material` اړین دی.**
    //
    // دا بار د `Navigator` تر پورته دی، نو د `Scaffold` هیڅ
    // `Material` یې پر سر نشته. بې له هغه، Flutter هر `Text` ته
    // یوه ژیړ کرښه ورکوي (د «Material نشته» نښه) — نو سرلیک زمونږ
    // د یوه ژیړ بلاک په بڼه رسمېده، نه د متن.
    return Material(
      color: cs.surfaceContainer,
      child: SizedBox(
      height: AppTitleBar.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
          ),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => windowStartDragging(),
          onDoubleTap: windowHandleDoubleTap,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Stack(
              children: [
                // ── سرلیک: تل په منځ کې، د تڼیو له ځایه خپلواک ──
                Center(
                  child: Text(
                    s.settings.archiveRoot == null
                        ? 'د آرشیف چټک مدیر'
                        : 'د آرشیف چټک مدیر — ${_short(s.settings.archiveRoot!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),

                // ── د ترافیک څراغونه — تل چپ لور ته ──
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 11),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Light(
                            color: const Color(0xFFFF5F57),
                            hoverColor: const Color(0xFFE0443E),
                            icon: Icons.close_rounded,
                            tooltip: 'تړل',
                            show: _hovered,
                            onTap: windowClose,
                          ),
                          const SizedBox(width: 8),
                          _Light(
                            color: const Color(0xFFFEBC2E),
                            hoverColor: const Color(0xFFDEA123),
                            icon: Icons.remove_rounded,
                            tooltip: 'ښکته کول',
                            show: _hovered,
                            onTap: windowMinimize,
                          ),
                          const SizedBox(width: 8),
                          _Light(
                            color: const Color(0xFF28C840),
                            hoverColor: const Color(0xFF1DAD2B),
                            icon: Icons.open_in_full_rounded,
                            tooltip: 'لوی / کوچنی',
                            show: _hovered,
                            onTap: windowToggleMaximize,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// `E:\Arvitch\1405` → `Arvitch`
  static String _short(String path) {
    final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }
}

/// یوه ګرده تڼۍ — د macOS د ترافیک څراغ په څېر.
class _Light extends StatefulWidget {
  const _Light({
    required this.color,
    required this.hoverColor,
    required this.icon,
    required this.tooltip,
    required this.show,
    required this.onTap,
  });

  final Color color;
  final Color hoverColor;
  final IconData icon;
  final String tooltip;

  /// آیا د ټولې کرښې پر سر ماوس دی؟ (macOS ایکنونه یوازې هغه وخت ښیي)
  final bool show;
  final VoidCallback onTap;

  @override
  State<_Light> createState() => _LightState();
}

class _LightState extends State<_Light> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    // **دلته `Tooltip` مه کاروئ.** ټایټل بار د `Navigator` تر
    // پورته دی، نو `Overlay` ورته نشته او Tooltip استثنا اچوي.
    // بل خوا، د macOS خپل ترافیک څراغونه هم tooltip نه لري —
    // ایکن پخپله کافي دی.
    return Semantics(
      label: widget.tooltip,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _over = true),
        onExit: (_) => setState(() => _over = false),
        child: GestureDetector(
          // د تڼۍ کلیک باید کړکۍ ونه ښوروي.
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppTokens.fast,
            curve: AppTokens.ease,
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _over ? widget.hoverColor : widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.10),
                width: 0.5,
              ),
            ),
            child: AnimatedOpacity(
              duration: AppTokens.fast,
              opacity: widget.show ? 1 : 0,
              child: Icon(
                widget.icon,
                size: 8.5,
                color: Colors.black.withValues(alpha: 0.62),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
