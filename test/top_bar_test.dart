import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/main.dart';
import 'package:archive_manager/widgets/common.dart';

/// **پورتنی بار یوازې د ډاشبورډ لپاره.**
///
/// کاروونکي وویل: «د ټایټل بار څخه لاندې د ټول آرشیف سرچ بار او د
/// تازه کولو او ټم ایکن فقط د ډاشبورډ پاڼه کې وښایه». نورې پاڼې
/// خپل ټولبار لري (د پیښو فلټر، د اکسپلورر مسیر…) — نو دوه بارونه
/// سر پر سر ځای خوري.
void main() {
  Future<AppState> boot(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();
    return s;
  }

  /// د ټول‌آرشیف لټون بار — د خپل هینټ له مخې یې پېژنو.
  Finder globalSearch() => find.byWidgetPredicate(
      (w) => w is SearchBox && w.hint.contains('په ټول آرشیف'));

  /// د تیم تڼۍ — یوازې په پورتني بار کې ده.
  Finder themeToggle() => find.byWidgetPredicate((w) =>
      w is IconButton && '${w.tooltip}'.startsWith('تیم:'));

  testWidgets('په ډاشبورډ کې پورتنی بار شته', (t) async {
    await boot(t);
    expect(globalSearch(), findsOneWidget);
    expect(themeToggle(), findsOneWidget);
  });

  testWidgets('په نورو پاڼو کې پورتنی بار نشته', (t) async {
    final s = await boot(t);
    for (final page in [
      AppPage.events,
      AppPage.explorer,
      AppPage.keywords,
      AppPage.persons,
      AppPage.categories,
      AppPage.settings,
    ]) {
      s.go(page);
      await t.pumpAndSettle();
      expect(globalSearch(), findsNothing,
          reason: '$page کې ټول‌آرشیف لټون بار نه پکار دی');
      // **پام:** دلته `Icons.refresh_rounded` نه ګورو — اکسپلورر
      // خپله د پوښۍ د تازه کولو تڼۍ لري، او هغه پر خپل ځای سمه
      // ده. دا ازموینه یوازې د **پورتني بار** په اړه ده.
      expect(themeToggle(), findsNothing,
          reason: '$page کې د تیم تڼۍ نه پکار ده');
    }
  });

  testWidgets('بېرته ډاشبورډ ته → بار بیا راځي', (t) async {
    final s = await boot(t);
    s.go(AppPage.events);
    await t.pumpAndSettle();
    expect(globalSearch(), findsNothing);

    s.go(AppPage.dashboard);
    await t.pumpAndSettle();
    expect(globalSearch(), findsOneWidget);
  });
}
