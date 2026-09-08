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
}
