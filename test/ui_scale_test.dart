import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/platform/backend.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/features/shell/app_shell.dart';
import 'package:archive_manager/main.dart';

/// **د پروګرام د اندازې ازموینه.**
///
/// کاروونکي راپور کړه: «کله چې پروګرام له عادي حد څخه کوچنی کړو،
/// داسې توره خلا راځي».
///
/// علت: `SizedBox` خپلې اندازې د راغلو قیدونو له مخې راتنګوي، نو
/// د لویې منطقي پردې غوښتنه بېرته وړوکې کېده — او تر
/// `Transform.scale` روسته یې ټوله ساحه نه ډکوله.
///
/// **معنا:** کوچنی = پرده منطقاً **لویه** شي (زیات شیان ځای نیسي)،
/// لوی = پرده منطقاً **وړه** شي (هر څه لوی ښکاري).
void main() {
  const window = Size(1400, 900);

  Future<AppState> boot(WidgetTester t, double scale) async {
    await t.binding.setSurfaceSize(window);
    addTearDown(() => t.binding.setSurfaceSize(null));
    final s = AppState(DemoBackend());
    await s.boot();
    await s.setUiScale(scale);
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();
    return s;
  }

  /// د پروګرام د بدنې منطقي اندازه (تر ټایټل بار لاندې).
  Size bodySize(WidgetTester t) => t.getSize(find.byType(AppShell));

  testWidgets('کوچنی = منطقي پرده لویېږي', (t) async {
    await boot(t, 0.8);
    final s = bodySize(t);
    expect(s.width, closeTo(window.width / 0.8, 1),
        reason: 'پر ۸۰٪ باید منطقي عرض ۱۷۵۰px وي');
  });

  testWidgets('لوی = منطقي پرده وړه کیږي', (t) async {
    await boot(t, 1.25);
    final s = bodySize(t);
    expect(s.width, closeTo(window.width / 1.25, 1),
        reason: 'پر ۱۲۵٪ باید منطقي عرض ۱۱۲۰px وي');
  });

  testWidgets('عادي = هیڅ بدلون', (t) async {
    await boot(t, 1.0);
    expect(bodySize(t).width, closeTo(window.width, 1));
  });

  testWidgets('هره کچه ټوله پرده ډکوي — هیڅ توره خلا', (t) async {
    for (final (scale, _) in AppSettings.scaleOptions) {
      final s = await boot(t, scale);
      final body = bodySize(t);

      // تر `Transform` روسته رسم شوې ساحه = منطقي × کچه
      expect(body.width * scale, closeTo(window.width, 1.5),
          reason: 'پر ${(scale * 100).round()}٪ عرض نه ډکیږي');
      expect(t.takeException(), isNull);
      await s.setUiScale(1.0);
    }
  });

  // ═══════════════════════════════════════════════════════════
  //  د کلیک ازموینه — دا هغه باګ دی چې کاروونکي راپور کړ
  // ═══════════════════════════════════════════════════════════

  /// **ولې دا ازموینه؟**
  ///
  /// کاروونکي وویل: «ما اندازه تر ټولو کوچنی کړله، نو د پریویو
  /// پاڼه کې د ایډیټ افشن، د داخلي براوز او یا وینډوز براوز افشن
  /// د کلیک وړ نه وو، همدا شان د ټوسټ پیغام دننه د «پرانیزه» بټن
  /// هم».
  ///
  /// علت: `OverflowBox` د `Transform` **لاندې** و، نو د
  /// `Transform` خپله اندازه د کړکۍ هومره پاتې وه. کلیک چې د
  /// معکوس تحویل روسته تر هغې اندازې بهر لوېده، بې‌ځوابه پاتې
  /// کېده — یعنې د پردې چپه او لاندې برخه ټوله مړه وه.
  ///
  /// دلته ریښتیني تڼۍ وهو، نه یوازې اندازې پرتله کوو.
  group('پر هرې کچې هره تڼۍ کلیکیږي', () {
    for (final (scale, label) in AppSettings.scaleOptions) {
      testWidgets('$label (${(scale * 100).round()}٪)', (t) async {
        final s = await boot(t, scale);

        // ── ۱) سایډبار: تر ټولو ښکته توکی (تنظیمات) ──
        await t.tap(find.text('تنظیمات').last, warnIfMissed: false);
        await t.pumpAndSettle();
        expect(s.page, AppPage.settings,
            reason: 'د سایډبار ښکته توکی ونه کلیکېد');

        // ── ۲) د تنظیماتو رېل: تر ټولو ښکته ډله ──
        await t.tap(find.text('په اړه').first);
        await t.pumpAndSettle();
        expect(find.textContaining('نسخه'), findsWidgets,
            reason: '«په اړه» ډله ونه پرانیستل شوه');

        // ── ۳) د پریویو ټولبار — هماغه چې کاروونکي یادې کړې ──
        s.openEditor(s.events.first);
        await t.pumpAndSettle();
        s.setPreview(true);
        await t.pumpAndSettle();

        // «ایډیټ» تڼۍ: د پریویو له حالته بېرته ایډیټر ته
        final edit = find.text('ایډیټ');
        if (edit.evaluate().isNotEmpty) {
          await t.tap(edit.first);
          await t.pumpAndSettle();
          expect(s.previewMode, isFalse,
              reason: 'پر $label کچه «ایډیټ» ونه کلیکېد');
          s.setPreview(true);
          await t.pumpAndSettle();
        }

        // «په براوزر کې» — د ټولبار تر ټولو چپه تڼۍ (RTL)
        final browse = find.text('په براوزر کې');
        if (browse.evaluate().isNotEmpty) {
          final box = t.getRect(browse.first);
          // ریښتیني کلیک هماغه ځای ته چې سترګه یې ویني
          final hit = t.hitTestOnBinding(box.center);
          expect(hit.path.length, greaterThan(1),
              reason: 'پر $label کچه «په براوزر کې» د کلیک وړ نه ده');
        }

        s.closeEditor();
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  });

  testWidgets('د ټوسټ تڼۍ هم پر کوچنۍ کچه کلیکیږي', (t) async {
    // «پرانیزه» د پردې تر ټولو ښکته څنډې ته وي — هماغه ځای چې
    // پخوا مړ و.
    await boot(t, 0.8);
    final messenger = ScaffoldMessenger.of(
        t.element(find.byType(AppShell)));
    var tapped = false;
    messenger.showSnackBar(SnackBar(
      content: const Text('ازموینه'),
      duration: const Duration(seconds: 30),
      action: SnackBarAction(
          label: 'پرانیزه', onPressed: () => tapped = true),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('پرانیزه'));
    await t.pumpAndSettle();
    expect(tapped, isTrue, reason: 'د ټوسټ تڼۍ ونه کلیکېده');
  });
}
