import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';
import 'intro_page.dart';
import 'missing_root_page.dart';

/// **د پیل دروازه** — پرېکړه کوي چې کاروونکی کومې پاڼې ته ولاړ شي.
///
/// ۱. لا تر اوسه پیل روان دی      → د بارېدو پاڼه
/// ۲. مخکینی مسیر ورک دی          → د بیا هڅې پاڼه
/// ۳. لومړی ځل دی                 → معرفي + د مسیر ټاکنه
/// ۴. هر څه سم دي                 → پنل
class BootGate extends StatelessWidget {
  const BootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return AnimatedSwitcher(
      duration: AppTokens.slow,
      switchInCurve: AppTokens.ease,
      switchOutCurve: AppTokens.ease,
      child: switch (true) {
        _ when s.booting => const _Splash(key: ValueKey('splash')),
        _ when s.rootMissing => const MissingRootPage(key: ValueKey('missing')),
        _ when !s.settings.onboarded || s.settings.archiveRoot == null =>
          const IntroPage(key: ValueKey('intro')),
        _ => const AppShell(key: ValueKey('shell')),
      },
    );
  }
}

/// **د پیل پاڼه.**
///
/// ## ولې له سره؟
///
/// کاروونکي راپور کړه چې نوې نسخه یې پرانیستله او پروګرام همدلته
/// **بند پاتې شو** — دوه ځله. علت یې د پیل په ترتیب کې و (وګورئ
/// `AppState.boot`)، خو دا پاڼه یې پټاوه: یو څرخېدونکی بار چې
/// هیڅ نه واياست، نو کاروونکی نه پوهیږي چې پروګرام کار کوي که
/// مړ دی.
///
/// اوس:
///
/// * **هر ګام په نوم ښیي** — «ایندکس پرانیستل کیږي…»
/// * که پیل ډېر وځنډیږي، **یو څرګندونکی پیغام** راځي (نه یو
///   چوپ بار)
/// * که تېروتنه پېښه شي، **هغه ښیي** — نه چې پټه یې کړي
class _Splash extends StatefulWidget {
  const _Splash({super.key});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  /// څومره وخت تېر شو — نو که اوږد شي، کاروونکي ته ووایو چې ولې.
  Duration _elapsed = Duration.zero;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = context.watch<AppState>();
    final slow = _elapsed.inSeconds >= 6;

    return Scaffold(
      body: Stack(
        children: [
          // نرم، ژور شالید — نه یوه تشه سپینه پرده
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    cs.surface,
                    Color.alphaBlend(
                        AppTokens.brand.withValues(alpha: 0.055), cs.surface),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.75, end: 1),
                    duration: AppTokens.slower,
                    curve: AppTokens.spring,
                    builder: (_, v, child) => Transform.scale(
                        scale: v,
                        child: Opacity(
                            opacity: v.clamp(0.0, 1.0), child: child)),
                    // د پروګرام خپل ایکن — نه یو عمومي Material ایکن.
                    child: const AppLogo(size: 84),
                  ),
                  const SizedBox(height: AppTokens.s20),
                  Text(kAppName,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'v$kAppVersion',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppTokens.s24),

                  // ── نری بار + د ګام نوم ──
                  SizedBox(
                    width: 190,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: cs.surfaceContainerHigh,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.s12),
                  AnimatedSwitcher(
                    duration: AppTokens.base,
                    child: Text(
                      s.bootStep,
                      key: ValueKey(s.bootStep),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),

                  // ── که وځنډېد: ووایه ولې ──
                  AnimatedSize(
                    duration: AppTokens.base,
                    child: slow
                        ? Padding(
                            padding:
                                const EdgeInsets.only(top: AppTokens.s16),
                            child: Text(
                              'لومړی ځل تر نورو اوږد نیسي — ایندکس '
                              'جوړیږي. پروګرام تړل شوی نه دی.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.7,
                                  color: cs.onSurfaceVariant),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
