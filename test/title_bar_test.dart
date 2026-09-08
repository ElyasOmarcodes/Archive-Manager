import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/platform/backend.dart';
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

    double x(String name, Key key) {
      final f = find.byKey(key);
      expect(f, findsOneWidget, reason: '«$name» تڼۍ ونه موندل شوه');
      return t.getCenter(f).dx;
    }

    final close = x('تړل', AppTitleBar.kClose);
    final maximize = x('لوی / کوچنی', AppTitleBar.kMaximize);
    final minimize = x('ښکته کول', AppTitleBar.kMinimize);

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

  testWidgets('د کړکۍ تڼۍ **سمدلاسه** کار کوي — نه یوه ثانیه وروسته',
      (t) async {
    // کاروونکي وویل: «کله د فول اسکرین یا مینی مایز یا کنسل افشن
    // وهو، نږدې یوه ثانیه روسته عمل کوي».
    //
    // علت: د کش کولو `GestureDetector` یو `onDoubleTap` درلود، او
    // هغه د ټول بار لپاره د ایشارو ډګر ~۳۰۰ms نیوه. دلته یوازې
    // `pump()` کوو — **هیڅ وخت نه تېروو**. که ډګر بیا هم ونیول
    // شي، دا ازموینه ناکامه کیږي.
    AppTitleBar.debugForceShow = true;
    final fired = <String>[];
    AppTitleBar.debugOnWindowAction = fired.add;
    addTearDown(() {
      AppTitleBar.debugForceShow = false;
      AppTitleBar.debugOnWindowAction = null;
    });

    await t.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    for (final (name, key) in [
      ('minimize', AppTitleBar.kMinimize),
      ('maximize', AppTitleBar.kMaximize),
      ('close', AppTitleBar.kClose),
    ]) {
      fired.clear();
      await t.tap(find.byKey(key));
      await t.pump(); // بس یو فریم — هیڅ ځنډ نه
      expect(fired, [name], reason: '«$name» باید سمدلاسه عمل وکړي');
    }
  });

  testWidgets('سکن، تیم او «په اړه» تڼۍ په هره پاڼه کې دي', (t) async {
    // کاروونکي وویل: «د سکن او تیم افشن ټایټل بار ته راوړه ترڅو
    // تل لاسرسي وړ وي» — او «په اړه» تڼۍ هم ورسره.
    AppTitleBar.debugForceShow = true;
    addTearDown(() => AppTitleBar.debugForceShow = false);
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    for (final p in AppPage.values) {
      s.go(p);
      await t.pumpAndSettle();
      for (final k in [
        AppTitleBar.kScan,
        AppTitleBar.kTheme,
        AppTitleBar.kAbout,
        AppTitleBar.kNewEvent,
      ]) {
        expect(find.byKey(k), findsOneWidget, reason: '${p.name}: $k');
      }
    }
  });

  testWidgets('د تیم تڼۍ تیم بدلوي، او «په اړه» د جوړونکي ډلې ته ځي',
      (t) async {
    AppTitleBar.debugForceShow = true;
    addTearDown(() => AppTitleBar.debugForceShow = false);
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final s = AppState(DemoBackend());
    await s.boot();
    await s.setTheme(ThemeChoice.light);
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    await t.tap(find.byKey(AppTitleBar.kTheme));
    await t.pump();
    expect(s.settings.theme, ThemeChoice.dark);

    await t.tap(find.byKey(AppTitleBar.kAbout));
    await t.pumpAndSettle();
    expect(s.page, AppPage.settings);
    expect(s.settingsSection, 5);
    expect(find.text('الیاس عمر'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('د جمع تڼۍ د نوې پیښې ډایلوګ پرانیزي', (t) async {
    // کاروونکي وویل: «د ایکنونو ښي طرف ته یو عمودي فاصل خط، بیا
    // تر دې خط روسته د جمع ایکن».
    AppTitleBar.debugForceShow = true;
    addTearDown(() => AppTitleBar.debugForceShow = false);
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    // جمع تر «په اړه» ښي خوا ته ده (دا ډله په LTR کې ترتیب شوې)
    final plus = t.getCenter(find.byKey(AppTitleBar.kNewEvent)).dx;
    final about = t.getCenter(find.byKey(AppTitleBar.kAbout)).dx;
    expect(plus, greaterThan(about));

    await t.tap(find.byKey(AppTitleBar.kNewEvent));
    await t.pumpAndSettle();
    expect(find.text('نوې پیښه ثبت کړئ'), findsOneWidget,
        reason: 'ډایلوګ باید پرانیستل شي — بار د Navigator تر پورته دی');
    expect(t.takeException(), isNull);
  });
}
