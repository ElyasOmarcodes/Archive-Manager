import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **د تړل شوي پروګرام پاڼه.**
///
/// کله چې د کنټرول فایل `false` ووایي، پروګرام همدلته درېږي.
/// آرشیف نه ورکیږي — یوازې دروازه تړل کیږي.
///
/// پاڼه درې څیزه ښیي: **څه پېښ شوي**، **کله**، او **څه وکړي** —
/// یوه «بیا هڅه» تڼۍ چې سمدلاسه سرور بیا پوښتي، او د جوړونکي
/// اړیکه.
class ExpiredPage extends StatelessWidget {
  const ExpiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = context.watch<AppState>();
    final g = s.license;

    return Scaffold(
      body: Stack(
        children: [
          // نرم، ژور شالید — لکه د پیل پاڼه، خو سور رنګ ته ورته.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    cs.surface,
                    Color.alphaBlend(
                        AppTokens.rose.withValues(alpha: 0.07), cs.surface),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.s24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── نښه ──
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTokens.rose.withValues(alpha: 0.12),
                        border: Border.all(
                            color: AppTokens.rose.withValues(alpha: 0.35),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          size: 42, color: AppTokens.rose),
                    ),
                    const SizedBox(height: AppTokens.s24),
                    Text('پروګرام تړل شوی دی',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppTokens.s12),
                    Text(
                      'د دې نسخې د کارولو اجازه ودرول شوه. ستاسو آرشیف '
                      'خوندي دی — هیڅ فایل نه دی ورک شوی.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.9,
                          color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppTokens.s24),

                    // ── جزئیات ──
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: AppTokens.brLg,
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          _Row(
                            icon: Icons.event_busy_rounded,
                            label: 'د تړلو وخت',
                            value: _stamp(g.lockedAt),
                          ),
                          Divider(height: 1, color: cs.outlineVariant),
                          _Row(
                            icon: Icons.sync_rounded,
                            label: 'وروستۍ کتنه',
                            value: _stamp(g.lastCheck),
                          ),
                          Divider(height: 1, color: cs.outlineVariant),
                          _Row(
                            icon: Icons.info_outline_rounded,
                            label: 'نسخه',
                            value: 'v${PashtoDigits.to(kAppVersion)}',
                          ),
                          if (g.lastError != null) ...[
                            Divider(height: 1, color: cs.outlineVariant),
                            _Row(
                              icon: Icons.wifi_off_rounded,
                              label: 'شبکه',
                              value: 'اړیکه ونه شوه',
                              tone: AppTokens.amber,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTokens.s20),

                    // ── بیا هڅه ──
                    SizedBox(
                      height: AppTokens.controlHLg,
                      child: FilledButton.icon(
                        onPressed: g.checking
                            ? null
                            : () async {
                                final ok = await g.check();
                                if (context.mounted && !ok) {
                                  toast(context,
                                      'لا هم تړلی دی — بیا وروسته وګورئ',
                                      error: true);
                                }
                              },
                        icon: g.checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(g.checking ? 'کتنه روانه ده…' : 'بیا هڅه'),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s20),
                    Divider(color: cs.outlineVariant.withValues(alpha: 0.7)),
                    const SizedBox(height: AppTokens.s12),

                    // ── اړیکه ──
                    Text('د خلاصون لپاره له جوړونکي سره اړیکه ونیسئ',
                        style: TextStyle(
                            fontSize: 11.5, color: cs.onSurfaceVariant)),
                    const SizedBox(height: AppTokens.s12),
                    Wrap(
                      spacing: AppTokens.s8,
                      runSpacing: AppTokens.s8,
                      alignment: WrapAlignment.center,
                      children: [
                        _Contact(
                          icon: Icons.chat_rounded,
                          label: kDevWhatsApp,
                          url: kDevWhatsAppUrl,
                          color: AppTokens.green,
                        ),
                        _Contact(
                          icon: Icons.send_rounded,
                          label: kDevTelegram,
                          url: kDevTelegramUrl,
                          color: AppTokens.sky,
                        ),
                        _Contact(
                          icon: Icons.alternate_email_rounded,
                          label: kDevEmail,
                          url: kDevEmailUrl,
                          color: AppTokens.rose,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _stamp(DateTime? d) {
    if (d == null) return '—';
    final t = TriDate.fromDateTime(d);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${t.shamsiText}  ·  ${PashtoDigits.to('$hh:$mm')}';
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16, vertical: AppTokens.s12),
      child: Row(
        children: [
          Icon(icon, size: 17, color: tone ?? cs.onSurfaceVariant),
          const SizedBox(width: AppTokens.s12),
          Text(label,
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: tone ?? cs.onSurface)),
        ],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String url;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(AppTokens.rPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.rPill),
        onTap: () => s.backend.openExternally(url),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.rPill),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: AppTokens.s8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
