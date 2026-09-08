import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **د جوړونکي پاڼه** — «زمونږ په اړه».
///
/// کاروونکي د موبایل یو سکرین‌شاټ راولېږه او وویل: «زیات وضاحت مه
/// پکې کوه، فقط همداسې ښکلی UI د وینډوز سکرین سره مناسب طراحي
/// کړه». نو دلته:
///
/// * د موبایل **اوږد عمودي** جوړښت پر پراخه کړکۍ **څنګ‌په‌څنګ** شو —
///   انځور او نوم یوې خوا، اړیکې بلې خوا.
/// * هیڅ اوږد متن نشته: نوم، دنده، درې پلټفارمونه، درې اړیکې.
/// * هره اړیکه **کلیک وړ** ده (واټساپ/تلګرام/ایمیل پرانیزي) او د
///   کاپي تڼۍ هم لري — لکه په موبایل کې.
class DeveloperCard extends StatelessWidget {
  const DeveloperCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 720;
      final hero = const _Hero();
      final rest = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: const [
          _Label('جوړوي یې لپاره'),
          SizedBox(height: AppTokens.s12),
          _Platforms(),
          SizedBox(height: AppTokens.s24),
          _Label('اړیکه'),
          SizedBox(height: AppTokens.s12),
          _Contacts(),
        ],
      );

      if (!wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [hero, const SizedBox(height: AppTokens.s24), rest],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 300, child: hero),
          const SizedBox(width: AppTokens.s24),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s20, vertical: AppTokens.s24),
      decoration: BoxDecoration(
        borderRadius: AppTokens.brLg,
        border: Border.all(color: cs.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.alphaBlend(AppTokens.brand.withValues(alpha: 0.07), cs.surface),
            Color.alphaBlend(AppTokens.rose.withValues(alpha: 0.05), cs.surface),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Avatar(size: 116),
          const SizedBox(height: AppTokens.s16),
          Text(kDevNamePs,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, height: 1.4)),
          Text(kDevNameEn,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: AppTokens.s12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppTokens.rPill),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(kDevRole,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5, height: 1.6, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// د جوړونکي انځور، په یوه رنګینه کړۍ کې — لکه د موبایل پاڼه.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // انځور ۳۲۰×۳۲۰ دی؛ دلته یې په خپله وروستۍ اندازه ډيکوډ کوو،
    // نو څنډې نرمې راځي (لکه د پروګرام نښه).
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final px = ((size - 8) * dpr).round().clamp(32, 320);

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            AppTokens.brand,
            AppTokens.teal,
            AppTokens.green,
            AppTokens.amber,
            AppTokens.rose,
            AppTokens.violet,
            AppTokens.brand,
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surface),
        padding: const EdgeInsets.all(2.5),
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
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(text,
        style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: cs.onSurfaceVariant));
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

class _PlatformTile extends StatelessWidget {
  const _PlatformTile(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppTokens.brMd,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: AppTokens.s8),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}

/// واټساپ · تلګرام · ایمیل
class _Contacts extends StatelessWidget {
  const _Contacts();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
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

class _ContactRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = context.read<AppState>();

    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: AppTokens.brMd,
      child: InkWell(
        borderRadius: AppTokens.brMd,
        onTap: () => s.backend.openExternally(url),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12),
          decoration: BoxDecoration(
            borderRadius: AppTokens.brMd,
            border: Border.all(color: color.withValues(alpha: 0.26)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppTokens.brSm,
                ),
                child: Icon(icon, size: 19, color: Colors.white),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    // پته تل له کیڼه ښي (LTR) لوستل کیږي — نو د
                    // `+937…` علامه یې پای ته ونه لویږي.
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'کاپي',
                visualDensity: VisualDensity.compact,
                onPressed: () => copyText(context, value, label: title),
                icon: Icon(Icons.copy_rounded, size: 17, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
