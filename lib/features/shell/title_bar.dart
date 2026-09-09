import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/platform/backend.dart';
import '../../data/repository/app_state.dart';
import '../../main.dart';
import '../editor/new_event_dialog.dart';

import 'window_controls.dart'
    if (dart.library.io) 'window_controls_io.dart';

/// **د پروګرام خپل ټایټل بار.**
///
/// ```
///   ⟳  ☀  ⓘ            د آرشیف چټک مدیر            ● ● ●
/// ```
///
/// * ښي لور ته **د کړکۍ درې تڼۍ** — ځکه په وینډوز کې هر پروګرام
///   یې هلته لري: ښکته کول · لوی/کوچنی · تړل.
/// * کیڼ لور ته **د پروګرام تڼۍ** — بیا سکن، تیم، او د جوړونکي
///   پاڼه. دا د ټولې پروګرام په هره پاڼه کې لاسرسي وړ دي.
/// * سرلیک په منځ کې، نری او خړ.
/// * ټوله کرښه د کش کولو وړ ده، دوه‌ځله کلیک یې لوی/کوچنی کوي.
///
/// ## دوه ټکي چې کاروونکي راپور کړل
///
/// **۱. تڼۍ نږدې یوه ثانیه وروسته کار کوي.** علت یې د کش کولو
/// `GestureDetector` و: هغه `onDoubleTap` درلود، او یو
/// `DoubleTapGestureRecognizer` د **ټول بار** لپاره د ~۳۰۰ms
/// لپاره د ایشارو ډګر (gesture arena) **نیسي** — نو د تڼۍ کلیک
/// تر هغه وخته نه پرېکیده. اوس د کش کولو پوړ د `Stack` **تر ټولو
/// لاندې** دی او تڼۍ یې **پورته** دي: `Stack` لومړی پورتنی اولاد
/// ازمویي او هلته درېږي — نو د تڼۍ کلیک هیڅ ډګر ته نه ننوځي او
/// **سمدلاسه** کار کوي.
///
/// **۲. د تڼیو ایکنونه نري او نالوستي وو.** هغه د Material
/// ایکنونه په ۸٫۵px کې وو — په دومره کوچني کچ کې د فونټ کرښې
/// خړې کیږي. اوس **پخپله رسمیږي** (`_GlyphPainter`): سیده کرښې،
/// ټاکلې پنډوالی، او تل ښکاري — نه یوازې د ماوس د تېرېدو پر مهال.
class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key});

  /// د بار لوړوالی.
  static const double height = 38;

  /// **یوازې د ازموینې لپاره.** په ازموینو کې پروګرام ډیسکټاپ نه
  /// دی، نو بار پخپله تش وي — او د تڼیو ځای نه شي ازمویل کېدلی.
  @visibleForTesting
  static bool debugForceShow = false;

  // ── د ازموینې کلیدونه ──
  //
  // د کړکۍ ایکنونه اوس `CustomPaint` دي (نه `Icon`)، نو ازموینه
  // یې د کلید له مخې مومي.
  @visibleForTesting
  static const kMinimize = ValueKey('titlebar-minimize');
  @visibleForTesting
  static const kMaximize = ValueKey('titlebar-maximize');
  @visibleForTesting
  static const kClose = ValueKey('titlebar-close');
  @visibleForTesting
  static const kScan = ValueKey('titlebar-scan');
  @visibleForTesting
  static const kTheme = ValueKey('titlebar-theme');
  @visibleForTesting
  static const kAbout = ValueKey('titlebar-about');
  @visibleForTesting
  static const kNewEvent = ValueKey('titlebar-new-event');

  /// **یوازې د ازموینې لپاره.** که ټاکل شوی وي، د کړکۍ ریښتینی
  /// عمل نه ترسره کیږي — یوازې نوم یې دې فعالیت ته ورکول کیږي.
  /// نو ازموینه ګوري چې کلیک **سمدلاسه** پرېکیږي (بې د ایشارو
  /// ډګر له ځنډه)، پرته له دې چې ریښتینې کړکۍ وتړي.
  @visibleForTesting
  static void Function(String action)? debugOnWindowAction;

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> {
  /// آیا ماوس د بار پر سر دی؟ (د macOS ترافیک څراغونه یوازې هغه
  /// وخت خپل ایکنونه ښیي — کاروونکي وغوښتل چې همدا چلند بیرته راشي)
  bool _hovered = false;

  /// د سکرین‌شاټ لپاره یې په ویب کې هم ښکاره کولی شو:
  /// `flutter build web --dart-define=FORCE_TITLE_BAR=true`
  static const _force = bool.fromEnvironment('FORCE_TITLE_BAR');

  @override
  Widget build(BuildContext context) {
    if (!hasCustomTitleBar && !_force && !AppTitleBar.debugForceShow) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final s = context.watch<AppState>();

    // **`Material` اړین دی.** دا بار د `Navigator` تر پورته دی، نو
    // د `Scaffold` هیڅ `Material` یې پر سر نشته — او بې له هغه
    // Flutter هر `Text` ته د «Material نشته» ژیړه کرښه ورکوي.
    return Material(
      color: cs.surfaceContainer,
      child: SizedBox(
        height: AppTitleBar.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            border: Border(
              bottom:
                  BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
            ),
          ),
          // **ولې دلته `MouseRegion`؟** د کړکۍ تڼۍ خپل ایکنونه
          // یوازې هغه وخت ښیي چې ماوس **د ټول بار** پر سر وي —
          // دقیقاً لکه macOS. دا ویجټ یوازې د ماوس تګ‌راتګ اوري،
          // د کلیک په ډګر کې برخه نه اخلي، نو د تڼیو چټکوالی یې
          // نه ورانوي.
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Stack(
            children: [
              // ── ۱ · د کش کولو پوړ (تر ټولو لاندې) ──
              //
              // دا باید **لومړی** اولاد وي: `Stack` د کلیک پر مهال
              // له پایه پیل کوي، نو تڼۍ تر دې دمخه ازمویل کیږي او
              // د دې `onDoubleTap` یې نه ځنډوي.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => windowStartDragging(),
                  onDoubleTap: windowHandleDoubleTap,
                ),
              ),

              // ── ۲ · سرلیک (کلیک نه نیسي) ──
              IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 150),
                    child: Text(
                      s.settings.archiveRoot == null
                          ? 'د آرشیف چټک مدیر'
                          : 'د آرشیف چټک مدیر — '
                              '${_short(s.settings.archiveRoot!)}',
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
                ),
              ),

              // ── ۳ · د پروګرام تڼۍ (فزیکي کیڼ لور) ──
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: _Actions(),
                  ),
                ),
              ),

              // ── ۴ · د کړکۍ تڼۍ (فزیکي ښي لور) ──
              //
              // **پام:** دلته `Directionality` په `ltr` کې تړل کیږي.
              // که د ژبې له لوري سره وګرځي، په پښتو کې به چپ ته
              // ولاړې شي او د وینډوز عادت به مات شي.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 11),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // د وینډوز ترتیب: ښکته · لوی · تړل
                        _Light(
                          key: AppTitleBar.kMinimize,
                          show: _hovered,
                          glyphColor: cs.surfaceContainer,
                          color: const Color(0xFFFEBC2E),
                          hoverColor: const Color(0xFFDEA123),
                          glyph: _Glyph.minimize,
                          tooltip: 'ښکته کول',
                          onTap: () => _fire('minimize', windowMinimize),
                        ),
                        const SizedBox(width: 8),
                        _Light(
                          key: AppTitleBar.kMaximize,
                          show: _hovered,
                          glyphColor: cs.surfaceContainer,
                          color: const Color(0xFF28C840),
                          hoverColor: const Color(0xFF1DAD2B),
                          glyph: _Glyph.maximize,
                          tooltip: 'لوی / کوچنی',
                          onTap: () =>
                              _fire('maximize', windowToggleMaximize),
                        ),
                        const SizedBox(width: 8),
                        // «تړل» تر ټولو څنډې ته — لکه وینډوز
                        _Light(
                          key: AppTitleBar.kClose,
                          show: _hovered,
                          glyphColor: cs.surfaceContainer,
                          color: const Color(0xFFFF5F57),
                          hoverColor: const Color(0xFFE0443E),
                          glyph: _Glyph.close,
                          tooltip: 'تړل',
                          onTap: () => _fire('close', windowClose),
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
    );
  }

  /// د کړکۍ عمل — یا ریښتینی، یا (په ازموینه کې) یوازې خبر.
  static void _fire(String action, VoidCallback real) {
    final hook = AppTitleBar.debugOnWindowAction;
    if (hook != null) {
      hook(action);
      return;
    }
    real();
  }

  /// `E:\Arvitch\1405` → `Arvitch`
  static String _short(String path) {
    final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }
}

// ═══════════════════════════════════════════════════════════
//  د پروګرام تڼۍ — سکن · تیم · جوړونکی
// ═══════════════════════════════════════════════════════════

/// کاروونکي وویل: «د سکن او تیم افشن ټایټل بار ته راوړه ترڅو تل
/// لاسرسي وړ وي». نو دا درې تڼۍ د هرې پاڼې پر سر پاتې کیږي.
///
/// **لیبل چیرې دی؟** ټایټل بار د `Navigator` تر پورته دی، نو
/// `Tooltip` ورته `Overlay` نه مومي او استثنا اچوي. پرځای یې، د
/// ماوس د تېرېدو پر مهال نوم **همدې بار کې** د ایکنونو ترڅنګ
/// ښکاري — نو هیڅ تڼۍ پټه معما نه پاتې کیږي.
class _Actions extends StatefulWidget {
  const _Actions();

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  String? _hint;

  void _setHint(String? h) {
    if (_hint == h) return;
    setState(() => _hint = h);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = context.watch<AppState>();

    // د پیل، د معرفي او د **تړل شوي** حالت پر مهال دا تڼۍ معنا نه
    // لري — یوازې د کړکۍ تڼۍ پاتې کیږي (نو کاروونکی کړکۍ وتړلی شي).
    final ready =
        !s.booting && !s.rootMissing && !s.locked && s.settings.onboarded;
    if (!ready) return const SizedBox.shrink();

    final scanning = s.scan != null;
    final theme = s.settings.theme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarButton(
          key: AppTitleBar.kScan,
          icon: Icons.sync_rounded,
          // پروګرام نور هر ځل نه سکن کوي (وګورئ `AppState.boot`)،
          // نو کاروونکي ته وایو چې وروستی سکن کله و.
          label: scanning
              ? 'سکن روان دی…'
              : 'آرشیف بیا سکن کړه${_since(s.lastScan)}',
          busy: scanning,
          onTap: scanning ? null : s.rescanArchive,
          onHint: _setHint,
        ),
        _BarButton(
          key: AppTitleBar.kTheme,
          icon: switch (theme) {
            ThemeChoice.light => Icons.light_mode_rounded,
            ThemeChoice.dark => Icons.dark_mode_rounded,
            ThemeChoice.system => Icons.brightness_auto_rounded,
          },
          label: 'تیم: ${theme.label}',
          onTap: () => s.setTheme(switch (theme) {
            ThemeChoice.light => ThemeChoice.dark,
            ThemeChoice.dark => ThemeChoice.system,
            ThemeChoice.system => ThemeChoice.light,
          }),
          onHint: _setHint,
        ),
        _BarButton(
          key: AppTitleBar.kAbout,
          icon: Icons.info_outline_rounded,
          label: 'زمونږ په اړه',
          // ۵ = د تنظیماتو «جوړونکی» ډله.
          onTap: () => s.openSettings(5),
          onHint: _setHint,
        ),

        // ── فاصل ──
        //
        // کیڼ خوا یې د **پروګرام** تڼۍ دي (سکن، تیم، په اړه)؛
        // ښي خوا یې د **کار** تڼۍ (نوې پیښه). یو نری خط دواړه
        // ډلې بېلوي، نو سترګه یې سمدلاسه پېژني.
        Container(
          width: 1,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          color: cs.outlineVariant,
        ),

        // **سټایل یې د نورو په څېر دی.** کاروونکي وویل: «د نوې
        // پیښې د ایکن سټایل ددې نورو سره یو شان وي باید».
        _BarButton(
          key: AppTitleBar.kNewEvent,
          // **دایروي.** کاروونکي وویل: «دا نور ایکنونه ټول دایروي
          // دي، یو د جمع ایکن دایره نلري» — نو جمع هم د یوې کړۍ
          // دننه راځي.
          icon: Icons.add_circle_outline_rounded,
          label: 'نوې پیښه',
          onTap: () {
            // **ولې د ناوبرۍ کیلي؟** دا بار د `Navigator` تر پورته
            // دی، نو د خپل `context` له لارې `showDialog()` هیڅ
            // Navigator نه مومي.
            final ctx = ArchiveApp.navigatorKey.currentContext;
            if (ctx != null) showNewEventDialog(ctx);
          },
          onHint: _setHint,
        ),
        // د ماوس لاندې تڼۍ نوم — یو سپک، ځای‌نه‌نیوونکی لیبل.
        AnimatedSize(
          duration: AppTokens.fast,
          curve: AppTokens.ease,
          child: _hint == null
              ? const SizedBox(height: 20)
              : Padding(
                  padding: const EdgeInsets.only(left: 4, right: 6),
                  child: Text(
                    _hint!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// «۵ دقیقې مخکې» — یا تشه، که هیڅکله سکن شوی نه وي.
String _since(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  final label = switch (d) {
    _ when d.inMinutes < 1 => 'همدا اوس',
    _ when d.inMinutes < 60 => '${PashtoDigits.to(d.inMinutes)} دقیقې مخکې',
    _ when d.inHours < 24 => '${PashtoDigits.to(d.inHours)} ساعته مخکې',
    _ => '${PashtoDigits.to(d.inDays)} ورځې مخکې',
  };
  return '  ·  وروستی سکن: $label';
}

class _BarButton extends StatefulWidget {
  const _BarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onHint,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final ValueChanged<String?> onHint;
  final bool busy;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton>
    with SingleTickerProviderStateMixin {
  bool _over = false;
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _BarButton old) {
    super.didUpdateWidget(old);
    _syncSpin();
  }

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  void _syncSpin() {
    if (widget.busy && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.busy && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: widget.label,
      button: true,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _over = true);
          widget.onHint(widget.label);
        },
        onExit: (_) {
          setState(() => _over = false);
          widget.onHint(null);
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppTokens.fast,
            width: 28,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _over
                  ? cs.onSurface.withValues(alpha: 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: RotationTransition(
              turns: _spin,
              child: Icon(
                widget.icon,
                size: 16,
                color: widget.onTap == null
                    ? cs.onSurfaceVariant.withValues(alpha: 0.55)
                    : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د کړکۍ تڼۍ
// ═══════════════════════════════════════════════════════════

enum _Glyph { minimize, maximize, close }

/// یوه ګرده تڼۍ — د macOS د ترافیک څراغ په څېر، په وینډوز ترتیب.
///
/// **د ایکن ښکاره کېدل.** کاروونکي وویل: «د دې بټنو مخکې ډیر
/// خوندور افکټ درلود، دقیقاً لکه د حقیقي mac — کله به چې موس د
/// بټنو سره ټچ شو نو د بټنو دننه ایکن به په ښکلي ډول وښودل شو».
/// نو ایکن اوس بیا هم د ماوس په راتګ سره راځي: نه یوازې شفافیت،
/// بلکې یو کوچنی **پړسوب** (۰٫۶ → ۱) هم لري، نو داسې ښکاري چې
/// له کړۍ دننه راوځي.
///
/// **د ایکن رنګ.** کاروونکي وغوښتل چې «د بک ګراند رنګ طابع کړي —
/// سپین حالت کې سپین او تور کې تور». نو ایکن د **بار د شالید**
/// په رنګ رسمیږي: داسې بریښي لکه څراغ چې سوری شوی وي او شالید
/// ترې ښکاري.
class _Light extends StatefulWidget {
  const _Light({
    super.key,
    required this.color,
    required this.hoverColor,
    required this.glyph,
    required this.glyphColor,
    required this.tooltip,
    required this.show,
    required this.onTap,
  });

  final Color color;
  final Color hoverColor;
  final _Glyph glyph;

  /// د ایکن رنګ — د ټایټل بار د شالید هومره.
  final Color glyphColor;
  final String tooltip;

  /// آیا ماوس د بار پر سر دی؟
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
    return Semantics(
      label: widget.tooltip,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _over = true),
        onExit: (_) => setState(() => _over = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppTokens.fast,
            curve: AppTokens.ease,
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _over ? widget.hoverColor : widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: AnimatedScale(
              duration: AppTokens.base,
              curve: AppTokens.spring,
              scale: widget.show ? 1 : 0.6,
              child: AnimatedOpacity(
                duration: AppTokens.fast,
                opacity: widget.show ? 1 : 0,
                child: CustomPaint(
                  painter: _GlyphPainter(widget.glyph, widget.glyphColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// **د تڼۍ ایکن — پخپله رسم شوی.**
///
/// د Material ایکنونه په ۸–۹px کې خړ او نري ښکاري: فونټ یې
/// د دومره کوچني کچ لپاره نه دی. دلته درې ساده شکلونه په خپله
/// کرښه رسمیږي — همغه پنډوالی، همغه اندازه، هره کچه کې روښانه.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);
  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final c = Offset(size.width / 2, size.height / 2);
    const r = 3.1; // د شکل نیمه پلنوالی

    switch (glyph) {
      case _Glyph.minimize:
        canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), p);
      case _Glyph.maximize:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: r * 2, height: r * 2),
            const Radius.circular(1),
          ),
          p,
        );
      case _Glyph.close:
        canvas.drawLine(
            Offset(c.dx - r, c.dy - r), Offset(c.dx + r, c.dy + r), p);
        canvas.drawLine(
            Offset(c.dx + r, c.dy - r), Offset(c.dx - r, c.dy + r), p);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
