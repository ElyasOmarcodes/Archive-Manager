import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **د جوړونکي پاڼه** — «زمونږ په اړه».
///
/// کاروونکي د موبایل یو سکرین‌شاټ راولېږه او وویل: «زیات وضاحت مه
/// پکې کوه، فقط همداسې ښکلی UI د وينډوز سکرین سره مناسب طراحي
/// کړه». نو دلته:
///
/// * د موبایل **اوږد عمودي** جوړښت پر پراخه کړکۍ **څنګ‌په‌څنګ** شو —
///   انځور او نوم یوې خوا، اړیکې بلې خوا.
/// * هیڅ اوږد متن نشته: نوم، دنده، درې پلټفارمونه، درې اړیکې.
/// * هره اړیکه **کلیک وړ** ده (واټساپ/تلګرام/ایمیل پرانیزي) او د
///   کاپي تڼۍ هم لري — لکه په موبایل کې.
class DeveloperCard extends StatelessWidget {
  const DeveloperCard({super.key});

  /// **یوازې د ازموینې لپاره.** د انځور کړۍ تل څرخي — یعنې پرده
  /// هیڅکله «آرامه» نه کیږي، او `pumpAndSettle()` به تل ودریږي.
  /// دا بېرغ یې بندوي.
  @visibleForTesting
  static bool animate = true;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 720;
      const hero = _Hero();
      const rest = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Label('جوړوي یې لپاره', Icons.devices_rounded),
          SizedBox(height: AppTokens.s12),
          _Platforms(),
          SizedBox(height: AppTokens.s24),
          _Label('اړیکه', Icons.connect_without_contact_rounded),
          SizedBox(height: AppTokens.s12),
          _Contacts(),
        ],
      );

      if (!wide) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [hero, SizedBox(height: AppTokens.s24), rest],
        );
      }

      return const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 320, child: hero),
          SizedBox(width: AppTokens.s24),
          Expanded(child: rest),
        ],
      );
    });
  }
}

/// انځور + نوم + دنده.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.s20, AppTokens.s24, AppTokens.s20, AppTokens.s20),
      decoration: BoxDecoration(
        borderRadius: AppTokens.brLg,
        border: Border.all(color: cs.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.alphaBlend(AppTokens.brand.withValues(alpha: 0.08), cs.surface),
            Color.alphaBlend(AppTokens.rose.withValues(alpha: 0.06), cs.surface),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTokens.brand.withValues(alpha: 0.07),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Avatar(size: 132),
          const SizedBox(height: AppTokens.s16),
          Text(kDevNamePs,
              style: const TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w800, height: 1.4)),
          Text(kDevNameEn,
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.3,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: AppTokens.s12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppTokens.rPill),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(kDevRole,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5, height: 1.7, color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: AppTokens.s16),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.7)),
          const SizedBox(height: AppTokens.s12),
          // د پروګرام خپله پېژندنه — نو پاڼه یوازې د یوه کس نه،
          // بلکې د دې پروګرام د جوړونکي ده.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 22, shadow: false),
              const SizedBox(width: AppTokens.s8),
              // نوم اوږد دی او کارت نری — نو دې کرښې ته د تنګېدو
              // اجازه ورکوو، پرځای د دې چې بهر ولویږي.
              Flexible(
                child: Text('$kAppName · v$kAppVersion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// د جوړونکي انځور، په یوه **څرخېدونکې** رنګینه کړۍ کې.
///
/// کاروونکي وویل: «د تصویر شاوخوا اسټروک باید په ډېر نرم توګه،
/// کرار کرار تاویدونکی انیمیشن ولري». نو:
///
/// * یو دوران **۲۴ ثانیې** نیسي — دومره ورو چې سترګه یې «حرکت»
///   احساسوي، نه «څرخېدل»
/// * ګرادیانت **۱۳ رنګه** لري او هر یو یې د بل سره ګډ دی، نو د
///   رنګونو ترمنځ کومه تېره کرښه نه ښکاري
/// * `RepaintBoundary` یې ساتي چې یوازې همدا کړۍ بیا رسمیږي، نه
///   ټوله پاڼه
class _Avatar extends StatefulWidget {
  const _Avatar({required this.size});
  final double size;

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void initState() {
    super.initState();
    // په ازموینو کې تلپاتې انیمیشن `pumpAndSettle()` بندوي.
    final inTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('AutomatedTest');
    if (DeveloperCard.animate && !inTest) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // انځور ۴۰۰×۴۰۰ دی؛ دلته یې په خپله وروستۍ اندازه ډيکوډ کوو،
    // نو څنډې نرمې راځي (لکه د پروګرام نښه).
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final px = ((widget.size - 9) * dpr).round().clamp(32, 400);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── ۱ · څرخېدونکې کړۍ ──
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _spin,
              builder: (_, _) => Transform.rotate(
                angle: _spin.value * 6.283185307179586,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    // د رنګونو نرم تېرېدل — هر رنګ دوه ځله راځي،
                    // نو د دوو رنګونو ترمنځ بدلون پراخ او نرم وي.
                    gradient: SweepGradient(
                      colors: [
                        AppTokens.brand,
                        AppTokens.sky,
                        AppTokens.teal,
                        AppTokens.green,
                        AppTokens.amber,
                        AppTokens.orange,
                        AppTokens.rose,
                        AppTokens.violet,
                        AppTokens.brand,
                      ],
                      stops: [0, 0.13, 0.26, 0.39, 0.52, 0.63, 0.76, 0.89, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── ۲ · سپینه ککرۍ (چې کړۍ نرۍ ښکاره شي) ──
          Container(
            width: widget.size - 9,
            height: widget.size - 9,
            decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surface),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: Image.asset(
                'assets/dev/elyas-omar.jpg',
                fit: BoxFit.cover,
                cacheWidth: px,
                cacheHeight: px,
                isAntiAlias: true,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.icon);
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: AppTokens.s8),
        Text(text,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: cs.onSurfaceVariant)),
        const SizedBox(width: AppTokens.s12),
        Expanded(
          child: Divider(
              height: 1, color: cs.outlineVariant.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

/// وینډوز · iOS · اندروید
class _Platforms extends StatelessWidget {
  const _Platforms();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.desktop_windows_rounded, 'Windows', AppTokens.sky),
      (Icons.phone_iphone_rounded, 'iOS', AppTokens.brand),
      (Icons.android_rounded, 'Android', AppTokens.green),
    ];
    return Row(
      children: [
        for (final (icon, label, color) in items) ...[
          Expanded(child: _PlatformTile(icon: icon, label: label, color: color)),
          if (label != 'Android') const SizedBox(width: AppTokens.s12),
        ],
      ],
    );
  }
}

class _PlatformTile extends StatefulWidget {
  const _PlatformTile(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  State<_PlatformTile> createState() => _PlatformTileState();
}

class _PlatformTileState extends State<_PlatformTile> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _over = true),
      onExit: (_) => setState(() => _over = false),
      child: AnimatedContainer(
        duration: AppTokens.base,
        curve: AppTokens.ease,
        height: 96,
        transform: Matrix4.translationValues(0, _over ? -3 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.color.withValues(alpha: _over ? 0.18 : 0.10),
              widget.color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: AppTokens.brMd,
          border: Border.all(
              color: widget.color.withValues(alpha: _over ? 0.55 : 0.28)),
          boxShadow: _over
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 27, color: widget.color),
            const SizedBox(height: AppTokens.s8),
            Text(widget.label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}

/// واټساپ · تلګرام · ایمیل
class _Contacts extends StatelessWidget {
  const _Contacts();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ContactRow(
          icon: Icons.chat_rounded,
          color: AppTokens.green,
          title: 'واټساپ',
          value: kDevWhatsApp,
          url: kDevWhatsAppUrl,
        ),
        SizedBox(height: AppTokens.s8),
        _ContactRow(
          icon: Icons.send_rounded,
          color: AppTokens.sky,
          title: 'تلګرام',
          value: kDevTelegram,
          url: kDevTelegramUrl,
        ),
        SizedBox(height: AppTokens.s8),
        _ContactRow(
          icon: Icons.alternate_email_rounded,
          color: AppTokens.rose,
          title: 'ایمیل',
          value: kDevEmail,
          url: kDevEmailUrl,
        ),
      ],
    );
  }
}

class _ContactRow extends StatefulWidget {
  const _ContactRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.url,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String url;

  @override
  State<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends State<_ContactRow> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = context.read<AppState>();
    final c = widget.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _over = true),
      onExit: (_) => setState(() => _over = false),
      child: Material(
        color: c.withValues(alpha: _over ? 0.11 : 0.06),
        borderRadius: AppTokens.brMd,
        child: InkWell(
          borderRadius: AppTokens.brMd,
          onTap: () => s.backend.openExternally(widget.url),
          child: AnimatedContainer(
            duration: AppTokens.fast,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12),
            decoration: BoxDecoration(
              borderRadius: AppTokens.brMd,
              border: Border.all(
                  color: c.withValues(alpha: _over ? 0.5 : 0.26)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [c, Color.alphaBlend(
                          Colors.black.withValues(alpha: 0.18), c)],
                    ),
                    borderRadius: AppTokens.brSm,
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, size: 19, color: Colors.white),
                ),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.title,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      // پته تل له کیڼه ښي (LTR) لوستل کیږي — نو د
                      // `+937…` علامه یې پای ته ونه لویږي.
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(widget.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'کاپي',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      copyText(context, widget.value, label: widget.title),
                  icon: Icon(Icons.copy_rounded,
                      size: 17, color: cs.onSurfaceVariant),
                ),
                // د موبایل پاڼې په څېر یوه وړه نښه — «دا کرښه
                // پرانیستل کیږي».
                AnimatedOpacity(
                  duration: AppTokens.fast,
                  opacity: _over ? 1 : 0.35,
                  child: Icon(Icons.chevron_left_rounded,
                      size: 20, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
