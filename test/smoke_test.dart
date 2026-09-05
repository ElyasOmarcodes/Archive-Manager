import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/main.dart';
import 'package:archive_manager/data/platform/backend.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/features/onboarding/boot_gate.dart';
import 'package:archive_manager/features/shell/app_shell.dart';

/// **ریښتینی** `ArchiveApp` کاروو — نه یو جوړ شوی MaterialApp.
///
/// پخوا دلته یو خپل MaterialApp و، نو د پروګرام د اصلي MaterialApp
/// تنظیمات (ژبه، ډېلیګیټونه) هیڅکله نه ازمویل کېدل — او یوه ماتوونکې
/// تېروتنه له ازموینو تېره شوه: پرته له `localizationsDelegates`،
/// د پښتو ژبې لپاره MaterialLocalizations نه موندل کیږي او **هر
/// TextField ماتیږي**. اوس د ریښتیني اپ له لارې ازمویل کیږي.
Widget wrap(AppState s, {Widget? home}) => ChangeNotifierProvider.value(
      value: s,
      child: home == null
          ? const ArchiveApp()
          : _HomeOverride(home: home),
    );

/// د ArchiveApp ورته تنظیمات، خو د یوې ټاکلې پاڼې سره.
class _HomeOverride extends StatelessWidget {
  const _HomeOverride({required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) => ArchiveApp(homeOverride: home);
}

Future<AppState> booted() async {
  final s = AppState(DemoBackend());
  await s.boot();
  return s;
}

/// هیڅ پاڼه باید د جوړېدو پر مهال استثنا ونه کړي.
void expectNoError(WidgetTester t, String where) {
  final e = t.takeException();
  expect(e, isNull, reason: '$where threw: $e');
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('every page builds cleanly in both themes', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = await booted();

    for (final theme in [ThemeChoice.light, ThemeChoice.dark]) {
      await s.setTheme(theme);
      await t.pumpWidget(wrap(s));
      await t.pumpAndSettle();
      expectNoError(t, 'boot (${theme.name})');

      for (final p in AppPage.values) {
        s.go(p);
        await t.pumpAndSettle();
        expect(find.byType(AppShell), findsOneWidget);
        expectNoError(t, '${p.name} (${theme.name})');
      }

      // د پښتو ژبې لپاره MaterialLocalizations باید شتون ولري —
      // که نه وي، هر TextField ماتیږي.
      final ctx = t.element(find.byType(AppShell));
      expect(MaterialLocalizations.of(ctx), isNotNull);
      expect(Localizations.localeOf(ctx).languageCode, 'ps');
    }
  });

  testWidgets('editor and preview build for a real event', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = await booted();
    await t.pumpWidget(wrap(s));
    await t.pumpAndSettle();

    final event = s.events.first;

    s.openEditor(event);
    await t.pumpAndSettle();
    expectNoError(t, 'editor');
    expect(find.text(event.title), findsWidgets);

    s.setPreview(true);
    await t.pumpAndSettle();
    expectNoError(t, 'preview');
    expect(find.text(event.title), findsWidgets);

    s.closeEditor();
    await t.pumpAndSettle();
    expectNoError(t, 'close editor');
  });

  testWidgets('new-event dialog opens and builds', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = await booted();
    await t.pumpWidget(wrap(s));
    await t.pumpAndSettle();

    await t.tap(find.text('نوې پیښه').first);
    await t.pumpAndSettle();
    expectNoError(t, 'new event dialog');
    expect(find.text('نوې پیښه ثبت کړئ'), findsOneWidget);
    expect(find.text('اتومات'), findsOneWidget);
    expect(find.text('لاسي'), findsOneWidget);
  });

  testWidgets('filters narrow the grid and clear again', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = await booted();
    await t.pumpWidget(wrap(s));
    s.go(AppPage.events);
    await t.pumpAndSettle();

    final all = s.events.length;
    expect(all, greaterThan(0));

    await s.setQuery(s.query.copyWith(ratings: {5}));
    await t.pumpAndSettle();
    expectNoError(t, 'filtered events');
    expect(s.events.length, lessThan(all));
    expect(s.events.every((e) => e.rating == 5), isTrue);

    await s.clearFilters();
    await t.pumpAndSettle();
    expect(s.events.length, all);
  });

  testWidgets('onboarding shows when not yet configured', (t) async {
    await t.binding.setSurfaceSize(const Size(1400, 900));
    final backend = DemoBackend();
    await backend.saveSettings(AppSettings(onboarded: false));
    final s = AppState(backend);
    await s.boot();

    await t.pumpWidget(wrap(s, home: const BootGate()));
    await t.pumpAndSettle();
    expectNoError(t, 'intro');
    expect(find.text('په څو ثانیو کې ومومئ'), findsOneWidget);
  });

  testWidgets('missing archive root shows the three recovery options',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1400, 900));
    final s = AppState(_MissingRootBackend());
    await s.boot();

    await t.pumpWidget(wrap(s, home: const BootGate()));
    await t.pumpAndSettle();
    expectNoError(t, 'missing root');

    expect(find.text('ستاسو مخکینی آرشیف ونه موندل شو'), findsOneWidget);
    expect(find.text('بیا هڅه'), findsOneWidget);
    expect(find.text('نوی مسیر'), findsOneWidget);
    expect(find.text('وتل'), findsOneWidget);
    expect(find.text(r'E:\GoneDrive'), findsOneWidget);
  });
}

/// یو بک‌اینډ چې مسیر یې تل ورک دی — د بیا هڅې پاڼې ازموینې لپاره.
class _MissingRootBackend extends DemoBackend {
  @override
  Future<AppSettings> loadSettings() async =>
      AppSettings(archiveRoot: r'E:\GoneDrive', onboarded: true);

  @override
  Future<bool> pathExists(String path) async => false;
}
