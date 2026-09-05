import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/platform/backend.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// **د تنظیماتو پاڼه.**
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.s24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(
                icon: Icons.settings_rounded,
                title: 'تنظیمات',
                subtitle: 'د پروګرام بڼه او د آرشیف مسیر',
              ),
              const SizedBox(height: AppTokens.s24),

              // ── بڼه ──
              _Card(
                title: 'بڼه',
                icon: Icons.palette_rounded,
                children: [
                  _Setting(
                    label: 'تیم',
                    hint: 'سپین، تیاره، یا د وینډوز مطابق',
                    child: _Segmented<ThemeChoice>(
                      value: s.settings.theme,
                      options: [
                        for (final t in ThemeChoice.values)
                          (t, t.label, switch (t) {
                            ThemeChoice.light => Icons.light_mode_rounded,
                            ThemeChoice.dark => Icons.dark_mode_rounded,
                            ThemeChoice.system =>
                              Icons.brightness_auto_rounded,
                          }),
                      ],
                      onChanged: s.setTheme,
                    ),
                  ),
                  _Setting(
                    label: 'د ګریډ اندازه',
                    hint: 'د پیښو د کارتونو لویوالی',
                    child: _Segmented<int>(
                      value: s.settings.gridSize,
                      options: const [
                        (1, 'لوی', Icons.view_agenda_rounded),
                        (2, 'منځنی', Icons.grid_view_rounded),
                        (3, 'کوچنی', Icons.apps_rounded),
                      ],
                      onChanged: s.setGridSize,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTokens.s16),

              // ── تقویم ──
              _Card(
                title: 'تقویم',
                icon: Icons.event_rounded,
                children: [
                  _Setting(
                    label: 'ډیفالټ تقویم',
                    hint: 'کوم تاریخ چې د پروګرام هره برخه کې ښکاري.\n'
                        'درې واړه تقویمونه تل په metadata.json کې ساتل کیږي.',
                    child: _Segmented<CalendarKind>(
                      value: s.calendar,
                      options: [
                        for (final c in CalendarKind.values)
                          (c, c.label, Icons.calendar_month_rounded),
                      ],
                      onChanged: s.setCalendar,
                    ),
                  ),
                  _Setting(
                    label: 'د میاشتو نومونه',
                    hint: s.settings.pashtoMonthNames
                        ? 'افغاني پښتو: وری، غویی، غبرګولی…'
                        : 'دري: حمل، ثور، جوزا…',
                    child: Switch(
                      value: s.settings.pashtoMonthNames,
                      onChanged: s.setPashtoMonths,
                    ),
                  ),
                  _Preview(),
                ],
              ),

              const SizedBox(height: AppTokens.s16),

              // ── آرشیف ──
              _Card(
                title: 'آرشیف',
                icon: Icons.storage_rounded,
                children: [
                  _ArchivePathRow(),
                  _Setting(
                    label: 'ایندکس بیا جوړول',
                    hint: 'ټول آرشیف بیا سکن کوي. که مو له بهره فایلونه '
                        'اضافه کړي وي، دا یې ایندکس ته راولي.',
                    child: FilledButton.tonalIcon(
                      onPressed: s.scan != null ? null : s.rescanArchive,
                      icon: s.scan != null
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded, size: 17),
                      label: Text(s.scan == null
                          ? 'بیا سکن کړه'
                          : '${PashtoDigits.to(s.scan!.found)} موندل شوې'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTokens.s16),

              // ── لنډیز ──
              _StatsCard(),

              const SizedBox(height: AppTokens.s16),
              _AboutCard(),
              const SizedBox(height: AppTokens.s40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTokens.s20, AppTokens.s16,
                AppTokens.s20, AppTokens.s12),
            child: Row(
              children: [
                Icon(icon, size: 17, color: cs.primary),
                const SizedBox(width: AppTokens.s8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cs.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppTokens.s20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint!,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTokens.s20),
          child,
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String, IconData)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            InkWell(
              onTap: () => onChanged(o.$1),
              borderRadius: AppTokens.brSm,
              child: AnimatedContainer(
                duration: AppTokens.fast,
                curve: AppTokens.ease,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.s12, vertical: 7),
                decoration: BoxDecoration(
                  color: value == o.$1
                      ? cs.primary.withValues(alpha: 0.14)
                      : null,
                  borderRadius: AppTokens.brSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(o.$3,
                        size: 15,
                        color: value == o.$1
                            ? cs.primary
                            : cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      o.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: value == o.$1
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: value == o.$1 ? cs.primary : cs.onSurface,
                      ),
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

/// د نن ورځې تاریخ په دریو تقویمونو کې — د تنظیماتو ژوندۍ مخکتنه.
class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final now = TriDate.now();

    return Container(
      margin: const EdgeInsets.all(AppTokens.s20),
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppTokens.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_rounded, size: 13, color: cs.primary),
              const SizedBox(width: 5),
              Text('نن ورځ داسې ښکاري:',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Text(s.dateText(now),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            [
              if (s.calendar != CalendarKind.shamsi) now.shamsiText,
              if (s.calendar != CalendarKind.qamari) now.qamariText,
              if (s.calendar != CalendarKind.miladi) now.miladiText,
            ].join('   ·   '),
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ArchivePathRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('د آرشیف مسیر',
              style:
                  TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('هغه فولډر یا هارډ چې ټول آرشیف پکې پروت دی',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: AppTokens.s12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.s12, vertical: AppTokens.s12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: AppTokens.brMd,
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.storage_rounded,
                          size: 16, color: cs.primary),
                      const SizedBox(width: AppTokens.s8),
                      Expanded(
                        child: Text(
                          s.settings.archiveRoot ?? '—',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w500),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'کاپي',
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        onPressed: () => copyText(
                            context, s.settings.archiveRoot ?? '',
                            label: 'مسیر'),
                        splashRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.s12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await s.backend
                      .pickDirectory(initial: s.settings.archiveRoot);
                  if (picked != null) await s.setArchiveRoot(picked);
                },
                icon: const Icon(Icons.drive_folder_upload_rounded, size: 17),
                label: const Text('بدل کړه'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final st = s.stats;
    final cs = Theme.of(context).colorScheme;

    final rows = [
      ('پیښې', PashtoDigits.to(st.eventCount), Icons.auto_awesome_mosaic_rounded),
      ('فایلونه', PashtoDigits.to(st.attachmentCount), Icons.perm_media_rounded),
      ('ټوله اندازه', humanBytes(st.totalBytes), Icons.data_usage_rounded),
      ('کیورډونه', PashtoDigits.to(st.keywordCount), Icons.sell_rounded),
      ('شخصیتونه', PashtoDigits.to(st.personCount), Icons.groups_rounded),
      ('کټګورۍ', PashtoDigits.to(st.categoryCount), Icons.category_rounded),
    ];

    return _Card(
      title: 'د آرشیف لنډیز',
      icon: Icons.insights_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTokens.s20),
          child: Wrap(
            spacing: AppTokens.s12,
            runSpacing: AppTokens.s12,
            children: [
              for (final r in rows)
                Container(
                  width: 220,
                  padding: const EdgeInsets.all(AppTokens.s12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: AppTokens.brMd,
                  ),
                  child: Row(
                    children: [
                      Icon(r.$3, size: 16, color: cs.primary),
                      const SizedBox(width: AppTokens.s8),
                      Expanded(
                        child: Text(r.$1,
                            style: TextStyle(
                                fontSize: 11.5, color: cs.onSurfaceVariant)),
                      ),
                      Text(r.$2,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppTokens.brand, AppTokens.brandAlt],
              ),
              borderRadius: AppTokens.brMd,
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: Colors.white, size: 23),
          ),
          const SizedBox(width: AppTokens.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('د آرشیف چټک مدیر',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text('نسخه ۱٫۰٫۰  ·  د رسنیزو شواهدو د آرشیف مدیریت',
                    style: TextStyle(
                        fontSize: 11.5, color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(
                  'ستاسو ډیټا تل پر خپل هارډ پاتې کیږي — هیڅ څه '
                  'انټرنیټ ته نه لېږل کیږي.',
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
