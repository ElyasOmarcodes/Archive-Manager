import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/date/pashto_calendar.dart';
import '../../core/theme/tokens.dart';
import '../../data/platform/backend.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';
import 'developer_card.dart';

/// **د تنظیماتو پاڼه.**
///
/// ## ولې له سره جوړه شوه؟
///
/// پخوانۍ بڼه ټول تنظیمات یو ځای، په «ماسنري» کارتونو کې ښودل: د
/// شته عرض مطابق دوه‑درې کالمې، او هر کارت بېل لوړوالی. پایله یې
/// یوه ناهمواره، ناسمه پاڼه وه — یوه کالمه اوږده، بله نیمه تشه، او
/// د یوه تنظیم لپاره سترګې باید ټوله پاڼه وګرځولې.
///
/// ## نوی جوړښت
///
/// **دوه پاڼې (رېل + محتوا)** — هماغه بڼه چې macOS او VS Code یې
/// کاروي:
///
/// ```
///  ┌── رېل ──┬────────── محتوا ──────────┐
///  │ ● بڼه    │  بڼه                      │
///  │   تقویم  │  ─────────────────────    │
///  │   آرشیف  │  تیم        [ ][ ][ ]     │
///  │   لنډیز  │  ─────────────────────    │
///  │   په اړه │  اندازه   [Aa][Aa][Aa]    │
///  └─────────┴───────────────────────────┘
/// ```
///
/// * هر وخت **یوه** ډله ښکاري — نو پاڼه لنډه، سمه او پاکه ده.
/// * محتوا ټول عرض نیسي، نو کنټرولونه نور نه ماتیږي (پخوا د
///   تقویم درې تڼۍ او د اندازې پنځه کارتونه ښکته راګرځېدل).
/// * په تنګه کړکۍ کې رېل پورته ته د ټبونو یوې کرښې ته اوړي.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = context.watch<AppState>();

    // کومه ډله پرانیستې ده — په `AppState` کې پرته ده، نو د پاڼې
    // تر بدلون روسته هم پاتې کیږي، او د ټایټل بار «په اړه» تڼۍ
    // کولی شي سیده د جوړونکي ډلې ته ورشي.
    final section = st.settingsSection.clamp(0, 5);

    final sections = <_Section>[
      const _Section('بڼه', Icons.palette_rounded,
          'تیم، د پروګرام اندازه، د کارتونو ګریډ'),
      const _Section('تقویم', Icons.event_rounded,
          'ډیفالټ تقویم او د میاشتو نومونه'),
      const _Section('آرشیف', Icons.storage_rounded,
          'د آرشیف مسیر او د ایندکس بیا جوړول'),
      const _Section('لنډیز', Icons.insights_rounded,
          'څومره پیښې، فایلونه او ځای'),
      const _Section('په اړه', Icons.info_rounded, 'نسخه او د پټتیا تګلاره'),
      const _Section('جوړونکی', Icons.badge_rounded, 'د پروګرام جوړونکی او اړیکه'),
    ];

    return LayoutBuilder(builder: (context, c) {
      // ~۸۶۰px هغه پوله ده چې تر هغې ښکته رېل او محتوا څنګ‌په‌څنګ
      // نه ځایږي — نو رېل پورته ټبونو ته اوړي.
      final wide = c.maxWidth >= 860;
      final rail = _Rail(
        sections: sections,
        selected: section,
        vertical: wide,
        onSelect: st.setSettingsSection,
      );

      final content = _SectionBody(
        section: sections[section],
        child: switch (section) {
          0 => const _AppearanceSection(),
          1 => const _CalendarSection(),
          2 => const _ArchiveSection(),
          3 => const _StatsSection(),
          4 => const _AboutSection(),
          _ => const DeveloperCard(),
        },
      );

      if (!wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            rail,
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(child: _scroll(content, const EdgeInsets.all(AppTokens.s16))),
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          rail,
          VerticalDivider(width: 1, color: cs.outlineVariant),
          Expanded(
            child: _scroll(
              // محتوا تر ۹۲۰px پراخه نه شي: اوږدې کرښې لوستل
              // ستړي کوي، او تنظیمات د لوستلو لپاره دي.
              Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: content,
                ),
              ),
              const EdgeInsets.fromLTRB(
                  AppTokens.s32, AppTokens.s24, AppTokens.s32, AppTokens.s40),
            ),
          ),
        ],
      );
    });
  }

  Widget _scroll(Widget child, EdgeInsets padding) => ScrollArea(
        builder: (context, sc) => SingleChildScrollView(
          controller: sc,
          padding: padding,
          child: child,
        ),
      );
}

class _Section {
  const _Section(this.title, this.icon, this.hint);
  final String title;
  final IconData icon;
  final String hint;
}

// ═══════════════════════════════════════════════════════════
//  رېل — عمودي (پراخه کړکۍ) یا افقي ټبونه (تنګه)
// ═══════════════════════════════════════════════════════════

class _Rail extends StatelessWidget {
  const _Rail({
    required this.sections,
    required this.selected,
    required this.vertical,
    required this.onSelect,
  });

  final List<_Section> sections;
  final int selected;
  final bool vertical;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!vertical) {
      // په تنګه کړکۍ کې: یوه افقي، کش‑کېدونکې کرښه.
      return SizedBox(
        height: 54,
        child: ScrollArea(
          scrollbar: false,
          builder: (context, sc) => ListView.separated(
            controller: sc,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s16, vertical: AppTokens.s8),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppTokens.s6),
            itemBuilder: (_, i) => _Tab(
              section: sections[i],
              on: i == selected,
              onTap: () => onSelect(i),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 232,
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(
          AppTokens.s12, AppTokens.s20, AppTokens.s12, AppTokens.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTokens.s8, 0, AppTokens.s8, AppTokens.s16),
            child: Row(
              children: [
                Icon(Icons.settings_rounded, size: 18, color: cs.primary),
                const SizedBox(width: AppTokens.s8),
                const Text('تنظیمات',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _RailItem(
                section: sections[i],
                on: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem(
      {required this.section, required this.on, required this.onTap});

  final _Section section;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.brMd,
      child: AnimatedContainer(
        duration: AppTokens.fast,
        curve: AppTokens.ease,
        padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s12, vertical: AppTokens.s12),
        decoration: BoxDecoration(
          color: on ? cs.surface : null,
          borderRadius: AppTokens.brMd,
          border: Border.all(
              color: on ? cs.outlineVariant : Colors.transparent),
          boxShadow: on
              ? [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(section.icon,
                size: 17, color: on ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: AppTokens.s12),
            Expanded(
              child: Text(
                section.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? cs.primary : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.section, required this.on, required this.onTap});

  final _Section section;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.brSm,
      child: AnimatedContainer(
        duration: AppTokens.fast,
        padding:
            const EdgeInsets.symmetric(horizontal: AppTokens.s12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainer,
          borderRadius: AppTokens.brSm,
          border: Border.all(
              color: on ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(section.icon,
                size: 15, color: on ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(section.title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? cs.primary : cs.onSurface,
                )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  د یوې ډلې بدنه
// ═══════════════════════════════════════════════════════════

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section, required this.child});

  final _Section section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      key: ValueKey(section.title),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(section.title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(section.hint,
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        const SizedBox(height: AppTokens.s20),
        child,
      ],
    );
  }
}

/// یوه ډله کرښې چې یو چوکاټ شریکوي — لکه د iOS/macOS تنظیمات.
class _Group extends StatelessWidget {
  const _Group({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, AppTokens.s8),
            child: Text(title!,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: cs.onSurfaceVariant)),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: AppTokens.brLg,
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      indent: AppTokens.s16,
                      endIndent: AppTokens.s16,
                      color: cs.outlineVariant),
                children[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s20),
      ],
    );
  }
}

/// یوه کرښه: لیبل + توضیح یوې خوا ته، کنټرول بلې خوا ته.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.child,
    this.hint,
    this.stacked = false,
  });

  final String label;
  final String? hint;
  final Widget child;

  /// که کنټرول پراخ وي (لکه د اندازې کارتونه)، لاندې یې ږدو.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(hint!,
              style: TextStyle(
                  fontSize: 11.5, height: 1.65, color: cs.onSurfaceVariant)),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: LayoutBuilder(builder: (context, c) {
        if (stacked || c.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              text,
              const SizedBox(height: AppTokens.s12),
              Align(alignment: AlignmentDirectional.centerStart, child: child),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: text),
            const SizedBox(width: AppTokens.s20),
            child,
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ۱ · بڼه
// ═══════════════════════════════════════════════════════════

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          title: 'رنګ او روښنایي',
          children: [
            _Row(
              label: 'تیم',
              hint: 'سپین، تیاره، یا د وینډوز مطابق',
              child: _Segmented<ThemeChoice>(
                value: s.settings.theme,
                options: [
                  for (final t in ThemeChoice.values)
                    (t, t.label, switch (t) {
                      ThemeChoice.light => Icons.light_mode_rounded,
                      ThemeChoice.dark => Icons.dark_mode_rounded,
                      ThemeChoice.system => Icons.brightness_auto_rounded,
                    }),
                ],
                onChanged: s.setTheme,
              ),
            ),
          ],
        ),
        _Group(
          title: 'اندازه',
          children: [
            _Row(
              label: 'د پروګرام اندازه',
              stacked: true,
              hint: 'کوچنی = هر څه وړوکي کیږي او په پرده کې زیات شیان '
                  'ځای نیسي، لکه چې پر لوی سکرین یې ګورئ. '
                  'لوی = د لوستلو لپاره اسانه.',
              child: _ScalePicker(
                  value: s.settings.uiScale, onChanged: s.setUiScale),
            ),
            _Row(
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
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ۲ · تقویم
// ═══════════════════════════════════════════════════════════

class _CalendarSection extends StatelessWidget {
  const _CalendarSection();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          children: [
            _Row(
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
            _Row(
              label: 'د میاشتو نومونه',
              hint: s.settings.pashtoMonthNames
                  ? 'افغاني پښتو: وری، غویی، غبرګولی…'
                  : 'دري: حمل، ثور، جوزا…',
              child: Switch(
                value: s.settings.pashtoMonthNames,
                onChanged: s.setPashtoMonths,
              ),
            ),
          ],
        ),
        const _Preview(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ۳ · آرشیف
// ═══════════════════════════════════════════════════════════

class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          children: [
            const _ArchivePathRow(),
            _Row(
              label: 'ایندکس بیا جوړول',
              hint: 'ټول آرشیف بیا سکن کوي. که مو له بهره فایلونه اضافه '
                  'کړي وي، دا یې ایندکس ته راولي.',
              child: FilledButton.tonalIcon(
                onPressed: s.scan != null ? null : s.rescanArchive,
                icon: s.scan != null
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 17),
                label: Text(s.scan == null
                    ? 'بیا سکن کړه'
                    : '${PashtoDigits.to(s.scan!.found)} موندل شوې'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArchivePathRow extends StatelessWidget {
  const _ArchivePathRow();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('د آرشیف مسیر',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text('هغه فولډر یا هارډ چې ټول آرشیف پکې پروت دی',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: AppTokens.s12),
          LayoutBuilder(builder: (context, c) {
            final path = Container(
              height: AppTokens.controlHLg,
              padding: const EdgeInsetsDirectional.only(
                  start: AppTokens.s12, end: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: AppTokens.brMd,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.storage_rounded, size: 16, color: cs.primary),
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
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => copyText(
                        context, s.settings.archiveRoot ?? '',
                        label: 'مسیر'),
                  ),
                ],
              ),
            );

            final change = OutlinedButton.icon(
              onPressed: () async {
                final picked = await s.backend
                    .pickDirectory(initial: s.settings.archiveRoot);
                if (picked != null) await s.setArchiveRoot(picked);
              },
              icon: const Icon(Icons.drive_folder_upload_rounded, size: 17),
              label: const Text('بدل کړه'),
            );

            // په تنګ ځای کې تڼۍ ښکته ځي — ګنې مسیر بیخي نه ښکاري.
            if (c.maxWidth < 460) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  path,
                  const SizedBox(height: AppTokens.s8),
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: change),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: path),
                const SizedBox(width: AppTokens.s12),
                change,
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ۴ · لنډیز
// ═══════════════════════════════════════════════════════════

class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final st = s.stats;
    final cs = Theme.of(context).colorScheme;

    final rows = <(String, String, IconData, Color)>[
      ('پیښې', PashtoDigits.to(st.eventCount),
          Icons.auto_awesome_mosaic_rounded, AppTokens.brand),
      ('فایلونه', PashtoDigits.to(st.attachmentCount),
          Icons.perm_media_rounded, AppTokens.green),
      ('ټوله اندازه', humanBytes(st.totalBytes), Icons.data_usage_rounded,
          AppTokens.amber),
      ('کیورډونه', PashtoDigits.to(st.keywordCount), Icons.sell_rounded,
          AppTokens.sky),
      ('شخصیتونه', PashtoDigits.to(st.personCount), Icons.groups_rounded,
          AppTokens.violet),
      ('کټګورۍ', PashtoDigits.to(st.categoryCount), Icons.category_rounded,
          AppTokens.rose),
    ];

    return LayoutBuilder(builder: (context, c) {
      // ~۲۱۰px هر کارت ته پکار دي؛ د شته عرض مطابق ۲ تر ۳ کالمې.
      final cols = (c.maxWidth / 210).floor().clamp(2, 3);
      const gap = AppTokens.s12;
      // **لوړوالی ثابت، نه د عرض نسبت.** د `childAspectRatio` سره
      // کارتونه د پاڼې د پراخېدو سره لوړیږي هم — او پایله یې دا وه
      // چې ایکن پورته او شمېره ښکته پاتې، منځ کې یوه لویه تشه.
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final r in rows)
            SizedBox(width: w, height: 104, child: _statCard(cs, r)),
        ],
      );
    });
  }

  Widget _statCard(ColorScheme cs, (String, String, IconData, Color) r) =>
      Container(
        padding: const EdgeInsets.all(AppTokens.s16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: AppTokens.brLg,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: r.$4.withValues(alpha: 0.13),
                borderRadius: AppTokens.brMd,
              ),
              child: Icon(r.$3, size: 18, color: r.$4),
            ),
            const SizedBox(width: AppTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w800)),
                  Text(r.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════
//  ۵ · په اړه
// ═══════════════════════════════════════════════════════════

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTokens.s20),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: AppTokens.brLg,
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              const AppLogo(size: 56),
              const SizedBox(width: AppTokens.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(kAppName,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      'نسخه ${PashtoDigits.to(kAppVersion)}  ·  $kAppTagline',
                      style: TextStyle(
                          fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s12),
        Container(
          padding: const EdgeInsets.all(AppTokens.s16),
          decoration: BoxDecoration(
            color: AppTokens.green.withValues(alpha: 0.09),
            borderRadius: AppTokens.brLg,
            border: Border.all(
                color: AppTokens.green.withValues(alpha: 0.28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_rounded,
                  size: 17, color: AppTokens.green),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ستاسو ډیټا ستاسو ده',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      'ټول آرشیف پر خپل هارډ پاتې کیږي — هیڅ څه انټرنیټ '
                      'ته نه لېږل کیږي، او پروګرام پرته له انټرنیټه هم '
                      'بشپړ کار کوي.',
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.7,
                          color: cs.onSurfaceVariant),
                    ),
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

// ═══════════════════════════════════════════════════════════
//  کنټرولونه
// ═══════════════════════════════════════════════════════════

/// **د پروګرام د اندازې ټاکونکی.**
///
/// د یوه ساده سلایډر پرځای څو مشخصې کچې ورکوو — نو کاروونکی
/// «۹۳٪» ونه ټاکي او بیا حیران نه شي چې ولې یو څه ناسم ښکاري.
class _ScalePicker extends StatelessWidget {
  const _ScalePicker({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppTokens.s8,
      runSpacing: AppTokens.s8,
      children: [
        for (final (v, label) in AppSettings.scaleOptions)
          () {
            final on = (value - v).abs() < 0.001;
            return InkWell(
              onTap: () => onChanged(v),
              borderRadius: AppTokens.brMd,
              child: AnimatedContainer(
                duration: AppTokens.fast,
                width: 92,
                padding: const EdgeInsets.symmetric(vertical: AppTokens.s12),
                decoration: BoxDecoration(
                  color: on
                      ? cs.primary.withValues(alpha: 0.12)
                      : cs.surfaceContainer,
                  borderRadius: AppTokens.brMd,
                  border: Border.all(
                      color: on ? cs.primary : cs.outlineVariant,
                      width: on ? 1.5 : 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // د هرې کچې خپله بېلګه — «Aa» په هماغه اندازه
                    SizedBox(
                      height: 26,
                      child: Center(
                        child: Text(
                          'Aa',
                          style: TextStyle(
                            fontSize: 15 * v,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                            color: on ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: on ? cs.primary : cs.onSurface,
                      ),
                    ),
                    Text(
                      '${PashtoDigits.to((v * 100).round())}٪',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }(),
      ],
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
      // **`Wrap` او نه `Row`.** که ځای تنګ شي، افشنونه ښکته
      // راګرځي — نه دا چې بهر ولوېږي.
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
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
                  color:
                      value == o.$1 ? cs.primary.withValues(alpha: 0.14) : null,
                  borderRadius: AppTokens.brSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(o.$3,
                        size: 15,
                        color:
                            value == o.$1 ? cs.primary : cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      o.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            value == o.$1 ? FontWeight.w700 : FontWeight.w400,
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
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final now = TriDate.now();

    return Container(
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: AppTokens.brLg,
        border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_rounded, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Text('نن ورځ داسې ښکاري:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Text(s.dateText(now),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
