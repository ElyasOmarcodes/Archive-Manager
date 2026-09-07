import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/main.dart';

/// **د میټاډیټا پنل د ژوندي وړاندیز ازموینه.**
void main() {
  testWidgets('لیکل د موجودو کیورډونو وړاندیز راوړي', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1200));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    s.go(AppPage.events);
    await t.pumpAndSettle();
    s.openEditor(s.events.first);
    await t.pumpAndSettle();

    // د کیورډونو د لټون فیلډ
    final field = find.widgetWithText(TextField, 'کیورډ ولټوئ یا نوی ولیکئ…');
    expect(field, findsOneWidget, reason: 'د کیورډ فیلډ باید ښکاره وي');

    await t.enterText(field, 'کند');
    await t.pumpAndSettle();

    // ✅ اصلي خبره: د وړاندیز متن ریښتیا رسمیږي
    expect(find.textContaining('کندهار', findRichText: true), findsWidgets,
        reason: 'د «کندهار» وړاندیز باید ولیدل شي');
  });

  testWidgets('بې سمونه لیکل «نوی جوړ کړه» وړاندیز کوي', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1200));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();
    s.go(AppPage.events);
    await t.pumpAndSettle();
    s.openEditor(s.events.first);
    await t.pumpAndSettle();

    await t.enterText(
        find.widgetWithText(TextField, 'کیورډ ولټوئ یا نوی ولیکئ…'),
        'زلزلهxyz');
    await t.pumpAndSettle();
    expect(find.textContaining('نوی جوړ کړه'), findsOneWidget);
  });
}
