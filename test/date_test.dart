import 'package:flutter_test/flutter_test.dart';
import 'package:archive_manager/core/date/pashto_calendar.dart';

void main() {
  test('tri-calendar conversion + jdn roundtrip', () {
    final d = TriDate.fromGregorian(2026, 9, 4);
    print('G 2026-09-04 => ${d.shamsiText} | ${d.qamariText} | ${d.miladiText}');
    print('shamsi numeric: ${d.shamsiNumeric}  jdn=${d.jdn}');
    expect(d.shamsi.year, 1405);
    expect(d.shamsi.month, 6);

    final back = TriDate.fromJdn(d.jdn);
    expect(back.gregorian, d.gregorian);

    final s = TriDate.fromShamsi(1405, 6, 13);
    print('S 1405/06/13 => ${s.miladiText} | ${s.qamariText}');
    expect(s.shamsi.day, 13);

    final q = TriDate.fromQamari(1447, 3, 21);
    print('Q 1447/03/21 => ${q.miladiText} | ${q.shamsiText}');
    expect(q.qamari.year, 1447);

    print('month lengths: shamsi 1405/06=${TriDate.monthLength(CalendarKind.shamsi,1405,6)} '
        'qamari 1447/03=${TriDate.monthLength(CalendarKind.qamari,1447,3)}');
    expect(PashtoDigits.to(1405), '۱۴۰۵');
    expect(PashtoDigits.from('۱۴۰۵'), '1405');
  });
}
