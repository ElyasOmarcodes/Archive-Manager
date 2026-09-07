import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/main.dart';

/// **د پریویو ↔ ایډیټ ناوبري.**
///
/// کاروونکي راپور کړه: پیښه چې کلیک شي، پریویو راځي؛ خو «بېرته»
/// یې ایډیټ حالت ته وړي او دویم ځل «بېرته» پکار وي. سربېره پر
/// دې، په پریویو کې د ایډیټ لپاره هیڅ تڼۍ نه وه.
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

  testWidgets('له کارت پریویو ته → «بېرته» سمدستي لیست ته ځي', (t) async {
    final s = await boot(t);
    s.go(AppPage.events);
    await t.pumpAndSettle();

    s.openEditor(s.events.first, preview: true);
    await t.pumpAndSettle();
    expect(s.previewMode, isTrue);
    expect(s.previewEntry, isTrue);

    // د ایډیټ تڼۍ باید شتون ولري
    expect(find.text('ایډیټ'), findsOneWidget);

    // «بېرته» → مستقیم لیست ته، نه ایډیټ ته
    await t.tap(find.byIcon(Icons.arrow_forward_rounded).first);
    await t.pumpAndSettle();
    expect(s.editing, isNull, reason: 'باید بشپړ ووځي، نه ایډیټ ته ولوېږي');
  });

  testWidgets('له ایډیټ پریویو ته → «بېرته» ایډیټ ته راګرځي', (t) async {
    final s = await boot(t);
    s.go(AppPage.events);
    await t.pumpAndSettle();

    s.openEditor(s.events.first); // ایډیټ حالت
    await t.pumpAndSettle();
    expect(s.previewEntry, isFalse);

    s.setPreview(true);
    await t.pumpAndSettle();
    expect(s.previewMode, isTrue);

    await t.tap(find.byIcon(Icons.arrow_forward_rounded).first);
    await t.pumpAndSettle();
    expect(s.editing, isNotNull, reason: 'باید ایډیټ ته راستون شي');
    expect(s.previewMode, isFalse);
  });

  testWidgets('په پریویو کې د «ایډیټ» تڼۍ ایډیټ حالت پرانیزي', (t) async {
    final s = await boot(t);
    s.go(AppPage.events);
    await t.pumpAndSettle();
    s.openEditor(s.events.first, preview: true);
    await t.pumpAndSettle();

    await t.tap(find.text('ایډیټ'));
    await t.pumpAndSettle();
    expect(s.previewMode, isFalse);
    expect(s.editing, isNotNull);
  });
}
