import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/features/shell/title_bar.dart';
import 'package:archive_manager/main.dart';

/// **د پروګرام خپل ټایټل بار.**
///
/// د وینډوز اصلي بار پټ دی، نو دا یې ځای نیسي. په ازموینو کې
/// (چې ډیسکټاپ نه دي) باید هیڅ ځای ونه نیسي او هیڅ ونه ماتوي.
void main() {
  testWidgets('ټایټل بار د پروګرام پر سر راځي او هیڅ نه ماتوي', (t) async {
    await t.binding.setSurfaceSize(const Size(1400, 900));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    // ویجټ شته — که څه هم په ویب/ازموینه کې تش دی
    expect(find.byType(AppTitleBar), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('په هرې پاڼې کې پاتې کیږي — یو ځل، نه ډېر ځله', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    for (final p in AppPage.values) {
      s.go(p);
      await t.pumpAndSettle();
      expect(find.byType(AppTitleBar), findsOneWidget,
          reason: '${p.name}: باید یو ټایټل بار وي');
      expect(t.takeException(), isNull, reason: p.name);
    }
  });

  testWidgets('د ډایلوګ پرانیستل یې نه ماتوي', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    await t.tap(find.text('نوې پیښه').first);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(AppTitleBar), findsOneWidget);
  });

  testWidgets('د کړکۍ تڼۍ ښي لور ته دي، او «تړل» تر ټولو څنډې ته',
      (t) async {
    // کاروونکي وویل: «د وینډوز د ټولو پروګرامونو دا افشن په ښي
    // طرف کې دی». پخوا یې د macOS په څېر چپ لور ته وو.
    AppTitleBar.debugForceShow = true;
    addTearDown(() => AppTitleBar.debugForceShow = false);

    const w = 1400.0;
    await t.binding.setSurfaceSize(const Size(w, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    // د ایکن له مخې یې لټوو، نه د لیبل — `Semantics` پخپله نوی
    // نوډ نه جوړوي، نو لیبل د ګاونډي متن سره یو ځای شي.
    double x(String name, IconData icon) {
      final f = find.descendant(
          of: find.byType(AppTitleBar), matching: find.byIcon(icon));
      expect(f, findsOneWidget, reason: '«$name» تڼۍ ونه موندل شوه');
      return t.getCenter(f).dx;
    }

    final close = x('تړل', Icons.close_rounded);
    final maximize = x('لوی / کوچنی', Icons.open_in_full_rounded);
    final minimize = x('ښکته کول', Icons.remove_rounded);

    // درې واړه د پردې په ښي نیمايي کې
    for (final (name, v) in [
      ('تړل', close),
      ('لوی / کوچنی', maximize),
      ('ښکته کول', minimize)
    ]) {
      expect(v, greaterThan(w / 2),
          reason: '«$name» باید ښي لور ته وي — اوس پر $v ده');
    }

    // د وینډوز ترتیب: ښکته < لوی < تړل (تړل تر ټولو ښي)
    expect(minimize, lessThan(maximize));
    expect(maximize, lessThan(close));
  });
}
