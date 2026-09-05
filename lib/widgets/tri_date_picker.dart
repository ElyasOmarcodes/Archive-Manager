import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date/pashto_calendar.dart';
import '../core/theme/tokens.dart';
import '../data/repository/app_state.dart';
import 'common.dart';

/// **درې‌ګونی تاریخ ټاکونکی.**
///
/// کاروونکی یوازې یو تاریخ ټاکي — خو د پردې ترشا درې واړه تقویمونه
/// (لمریز، قمري، میلادي) سمدلاسه محاسبه کیږي او ښکاره کیږي، نو
/// کاروونکی ډاډه وي چې کوم تاریخ یې ثبت کړ.
class TriDatePicker extends StatefulWidget {
  const TriDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TriDate value;
  final ValueChanged<TriDate> onChanged;

  @override
  State<TriDatePicker> createState() => _TriDatePickerState();
}

class _TriDatePickerState extends State<TriDatePicker> {
  late CalendarKind _kind;
  late int _year, _month;

  @override
  void initState() {
    super.initState();
    _kind = CalendarKind.shamsi;
    final d = widget.value.dateFor(_kind);
    _year = d.year;
    _month = d.month;
  }

  void _switchKind(CalendarKind k) {
    setState(() {
      _kind = k;
      final d = widget.value.dateFor(k);
      _year = d.year;
      _month = d.month;
    });
  }

  void _step(int months) {
    setState(() {
      var m = _month + months;
      var y = _year;
      while (m > 12) {
        m -= 12;
        y++;
      }
      while (m < 1) {
        m += 12;
        y--;
      }
      _month = m;
      _year = y;
    });
  }

  void _pick(int day) {
    final d = switch (_kind) {
      CalendarKind.shamsi => TriDate.fromShamsi(_year, _month, day),
      CalendarKind.qamari => TriDate.fromQamari(_year, _month, day),
      CalendarKind.miladi => TriDate.fromGregorian(_year, _month, day),
    };
    widget.onChanged(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final months = TriDate.monthsFor(_kind);
    final len = TriDate.monthLength(_kind, _year, _month);
    final selected = widget.value.dateFor(_kind);

    // د میاشتې د لومړۍ ورځې د اونۍ ځای (۰ = شنبه).
    final first = switch (_kind) {
      CalendarKind.shamsi => TriDate.fromShamsi(_year, _month, 1),
      CalendarKind.qamari => TriDate.fromQamari(_year, _month, 1),
      CalendarKind.miladi => TriDate.fromGregorian(_year, _month, 1),
    };
    final lead = first.shamsiWeekDay;
    final today = TriDate.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // د تقویم ټاکنه
        Row(
          children: [
            for (final k in CalendarKind.values) ...[
              if (k != CalendarKind.values.first) const SizedBox(width: 6),
              Expanded(
                child: SelectChip(
                  label: k.label,
                  selected: _kind == k,
                  onTap: () => _switchKind(k),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppTokens.s16),

        // د میاشتې ناوبري
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              onPressed: () => _step(-1),
              splashRadius: 18,
              tooltip: 'تېره میاشت',
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppTokens.fast,
                child: Text(
                  '${months[_month - 1]}  ${PashtoDigits.to(_year)}',
                  key: ValueKey('$_year-$_month-${_kind.name}'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              onPressed: () => _step(1),
              splashRadius: 18,
              tooltip: 'راتلونکې میاشت',
            ),
          ],
        ),
        const SizedBox(height: AppTokens.s8),

        // د اونۍ سرلیکونه
        Row(
          children: [
            for (final d in PashtoMonths.weekDaysShort)
              Expanded(
                child: Center(
                  child: Text(d,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant)),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.s6),

        // ورځې
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: 1.15,
          ),
          itemCount: lead + len,
          itemBuilder: (context, i) {
            if (i < lead) return const SizedBox.shrink();
            final day = i - lead + 1;
            final isSel = selected.year == _year &&
                selected.month == _month &&
                selected.day == day;
            final td = switch (_kind) {
              CalendarKind.shamsi => TriDate.fromShamsi(_year, _month, day),
              CalendarKind.qamari => TriDate.fromQamari(_year, _month, day),
              CalendarKind.miladi => TriDate.fromGregorian(_year, _month, day),
            };
            final isToday = td.jdn == today.jdn;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pick(day),
                borderRadius: AppTokens.brSm,
                child: AnimatedContainer(
                  duration: AppTokens.fast,
                  curve: AppTokens.ease,
                  decoration: BoxDecoration(
                    color: isSel ? cs.primary : null,
                    borderRadius: AppTokens.brSm,
                    border: isToday && !isSel
                        ? Border.all(color: cs.primary, width: 1.4)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      PashtoDigits.to(day),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSel || isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isSel ? cs.onPrimary : cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: AppTokens.s16),
        TriDateSummary(date: widget.value),
      ],
    );
  }
}

/// د ټاکل شوي تاریخ درې‌ګونی انځور — لمریز · قمري · میلادي.
class TriDateSummary extends StatelessWidget {
  const TriDateSummary({super.key, required this.date});

  final TriDate date;

  @override
  Widget build(BuildContext context) => _build(context, date);

  Widget _build(BuildContext context, TriDate d) {
    final cs = Theme.of(context).colorScheme;
    final current = context.read<AppState>().calendar;
    final rows = [
      (CalendarKind.shamsi, d.shamsiText),
      (CalendarKind.qamari, d.qamariText),
      (CalendarKind.miladi, d.miladiText),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.s12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    rows[i].$1.label,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: rows[i].$1 == current
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: rows[i].$1 == current
                          ? cs.primary
                          : cs.onSurface,
                    ),
                  ),
                ),
                if (rows[i].$1 == current)
                  Icon(Icons.check_circle_rounded, size: 13, color: cs.primary),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// یو ساحه چې وهل یې د تاریخ ټاکونکی پرانیزي.
class TriDateField extends StatelessWidget {
  const TriDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'د پیښې تاریخ',
  });

  final TriDate value;
  final ValueChanged<TriDate> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: AppTokens.s8),
        InkWell(
          onTap: () async {
            final picked = await showTriDatePicker(context, value);
            if (picked != null) onChanged(picked);
          },
          borderRadius: AppTokens.brMd,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s16, vertical: AppTokens.s12),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: AppTokens.brMd,
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.event_rounded, size: 18, color: cs.primary),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.dateText(value),
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      Text(
                        s.calendar == CalendarKind.shamsi
                            ? '${value.qamariText}  ·  ${value.miladiText}'
                            : '${value.shamsiText}  ·  ${value.miladiText}',
                        style: TextStyle(
                            fontSize: 10.5, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.expand_more_rounded,
                    size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// د تاریخ ټاکونکی ډیالوګ.
Future<TriDate?> showTriDatePicker(BuildContext context, TriDate initial) {
  var picked = initial;
  return showDialog<TriDate>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('تاریخ وټاکئ'),
          contentPadding: const EdgeInsets.fromLTRB(
              AppTokens.s20, AppTokens.s16, AppTokens.s20, 0),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: TriDatePicker(
                value: picked,
                onChanged: (d) => setLocal(() => picked = d),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  setLocal(() => picked = TriDate.now()),
              child: const Text('نن'),
            ),
            const Spacer(),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('لغوه')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, picked),
                child: const Text('تایید')),
          ],
        ),
      ),
    ),
  );
}
