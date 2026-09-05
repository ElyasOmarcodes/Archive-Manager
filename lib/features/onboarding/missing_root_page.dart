import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **کله چې مخکینی مسیر ونه موندل شو.**
///
/// درې لارې: بیا هڅه · نوی مسیر · وتل — دقیقاً لکه غوښتنه شوې وه.
class MissingRootPage extends StatefulWidget {
  const MissingRootPage({super.key});

  @override
  State<MissingRootPage> createState() => _MissingRootPageState();
}

class _MissingRootPageState extends State<MissingRootPage> {
  bool _busy = false;
  bool _failedRetry = false;

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _failedRetry = false;
    });
    final ok = await context.read<AppState>().retryMissingRoot();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failedRetry = !ok;
    });
    if (!ok && mounted) {
      toast(context, 'مسیر لا هم نه دی موندل شوی', error: true);
    }
  }

  Future<void> _newPath() async {
    final s = context.read<AppState>();
    final picked = await s.backend.pickDirectory();
    if (picked == null) return;
    setState(() => _busy = true);
    await s.setArchiveRoot(picked);
  }

  void _quit() {
    if (kIsWeb) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.s40),
            child: FadeSlideIn(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // د خبرتیا نښه — د زړه‌راښکون سره خو نه ډارونکې.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.75, end: 1),
                    duration: AppTokens.slower,
                    curve: AppTokens.spring,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppTokens.amber.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTokens.amber.withValues(alpha: 0.35),
                            width: 2),
                      ),
                      child: const Icon(Icons.link_off_rounded,
                          size: 44, color: AppTokens.amber),
                    ),
                  ),
                  const SizedBox(height: AppTokens.s32),
                  Text('ستاسو مخکینی آرشیف ونه موندل شو',
                      textAlign: TextAlign.center,
                      style: t.textTheme.headlineSmall),
                  const SizedBox(height: AppTokens.s12),
                  Text(
                    'کېدای شي بهرنی هارډ نه وي وصل، یا مسیر بدل شوی وي.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppTokens.s24),

                  // ورک شوی مسیر
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s16, vertical: AppTokens.s12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: AppTokens.brMd,
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder_off_rounded,
                            size: 17, color: cs.onSurfaceVariant),
                        const SizedBox(width: AppTokens.s12),
                        Expanded(
                          child: Text(
                            s.missingPath ?? '—',
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          tooltip: 'مسیر کاپي کړه',
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () =>
                              copyText(context, s.missingPath ?? '',
                                  label: 'مسیر'),
                          splashRadius: 16,
                        ),
                      ],
                    ),
                  ),

                  if (_failedRetry) ...[
                    const SizedBox(height: AppTokens.s16),
                    Container(
                      padding: const EdgeInsets.all(AppTokens.s12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.5),
                        borderRadius: AppTokens.brMd,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 16, color: cs.error),
                          const SizedBox(width: AppTokens.s8),
                          Expanded(
                            child: Text(
                              'لا هم نه دی موندل شوی. ډاډ ترلاسه کړئ چې '
                              'هارډ وصل دی، بیا بیا هڅه وکړئ.',
                              style: TextStyle(
                                  fontSize: 12.5, color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppTokens.s32),

                  // درې افشنونه
                  Row(
                    children: [
                      Expanded(
                        child: _Choice(
                          icon: Icons.refresh_rounded,
                          label: 'بیا هڅه',
                          hint: 'هارډ مې وصل کړ',
                          color: AppTokens.brand,
                          primary: true,
                          busy: _busy,
                          onTap: _busy ? null : _retry,
                        ),
                      ),
                      const SizedBox(width: AppTokens.s12),
                      Expanded(
                        child: _Choice(
                          icon: Icons.drive_folder_upload_rounded,
                          label: 'نوی مسیر',
                          hint: 'بل ځای وټاکه',
                          color: AppTokens.teal,
                          onTap: _busy ? null : _newPath,
                        ),
                      ),
                      const SizedBox(width: AppTokens.s12),
                      Expanded(
                        child: _Choice(
                          icon: Icons.logout_rounded,
                          label: 'وتل',
                          hint: 'پروګرام وتړه',
                          color: AppTokens.rose,
                          onTap: _busy ? null : _quit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    this.onTap,
    this.primary = false,
    this.busy = false,
  });

  final IconData icon;
  final String label, hint;
  final Color color;
  final VoidCallback? onTap;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return HoverLift(
      onTap: onTap,
      lift: 4,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppTokens.base,
        curve: AppTokens.ease,
        padding: const EdgeInsets.symmetric(
            vertical: AppTokens.s20, horizontal: AppTokens.s12),
        decoration: BoxDecoration(
          color: primary
              ? color.withValues(alpha: hovered ? 0.18 : 0.12)
              : hovered
                  ? color.withValues(alpha: 0.09)
                  : cs.surfaceContainerLowest,
          borderRadius: AppTokens.brLg,
          border: Border.all(
            color: primary || hovered
                ? color.withValues(alpha: 0.55)
                : cs.outlineVariant,
            width: primary ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 26,
              child: busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: color),
                    )
                  : Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: AppTokens.s12),
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
