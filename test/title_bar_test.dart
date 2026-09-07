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
}
