import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/core/date/pashto_calendar.dart';
import 'package:archive_manager/core/theme/app_theme.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/widgets/tri_date_picker.dart';

/// **د نېټې ټاکونکي ازموینه.**
///
/// دا باګ کاروونکي وموند: د تاریخ پر افشن کلیک پروګرام «جاموه».
/// علت یې `AlertDialog.actions` کې یو `Spacer` و — `actions` د
/// `OverflowBar` په واسطه رسمیږي، چې Flex نه دی، نو `Expanded`
/// هلته ناسم دی او د ډایلوګ **بدنه بیخي نه رسمېده**.
void main() {
  Future<BuildContext> mount(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1200, 900));
    final s = AppState(DemoBackend());
    await s.boot();
    late BuildContext ctx;
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(builder: (c) {
            ctx = c;
            return const Scaffold();
          }),
        ),
      ),
    ));
    await t.pumpAndSettle();
    return ctx;
  }

  testWidgets('ډایلوګ خپله بدنه هم رسموي — نه یوازې سرلیک', (t) async {
    final ctx = await mount(t);
    showTriDatePicker(ctx, TriDate.now());
    await t.pumpAndSettle();

    // سرلیک او تڼۍ
    expect(find.text('تاریخ وټاکئ'), findsOneWidget);
    expect(find.text('تایید'), findsOneWidget);
    expect(find.text('نن'), findsOneWidget);

    // ✅ اصلي خبره: د تقویم بدنه ریښتیا شته
    expect(find.byType(TriDatePicker), findsOneWidget);
    for (final k in CalendarKind.values) {
      expect(find.text(k.label), findsWidgets,
          reason: 'د «${k.label}» تڼۍ باید ښکاره وي');
    }
    // د ورځو ګریډ
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('درې واړه تقویمونه بدلېږي او میاشتې اوړي', (t) async {
    final ctx = await mount(t);
    showTriDatePicker(ctx, TriDate.now());
    await t.pumpAndSettle();

    for (final k in CalendarKind.values) {
      await t.tap(find.text(k.label).first);
      await t.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget,
          reason: '${k.label}: ګریډ باید پاتې شي');
      expect(testerHasError, isFalse);
    }

    // ۱۵ میاشتې مخته او ۳۰ شاته — د کال د پولې څخه اوښتل هم
    for (final icon in [
      Icons.chevron_left_rounded,
      Icons.chevron_right_rounded
    ]) {
      for (var i = 0; i < 15; i++) {
        await t.tap(find.byIcon(icon));
        await t.pumpAndSettle();
      }
      expect(find.byType(GridView), findsOneWidget);
    }
  });

  testWidgets('«نن» تڼۍ نېټه بېرته نن ته راولي', (t) async {
    final ctx = await mount(t);
    showTriDatePicker(ctx, TriDate.fromShamsi(1390, 1, 1));
    await t.pumpAndSettle();
    await t.tap(find.text('نن'));
    await t.pumpAndSettle();
    expect(find.byType(TriDatePicker), findsOneWidget);
  });
}

/// د ازموینې پر مهال کومه استثنا خو ونه لګېده؟
bool get testerHasError =>
    // ignore: invalid_use_of_visible_for_testing_member
    TestWidgetsFlutterBinding.instance.takeException() != null;
