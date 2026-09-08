import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1),
              duration: AppTokens.slower,
              curve: AppTokens.spring,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: Opacity(
                      opacity: v.clamp(0.0, 1.0), child: child)),
              // د پیل پاڼه هم د پروګرام خپل ایکن ښیي — نه یو
              // عمومي Material ایکن.
              child: const AppLogo(size: 76),
            ),
            const SizedBox(height: AppTokens.s24),
            Text('د آرشیف چټک مدیر',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppTokens.s24),
            SizedBox(
              width: 130,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(999),
                backgroundColor: cs.surfaceContainerHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
