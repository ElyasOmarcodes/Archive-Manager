import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/platform/backend.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/main.dart';

/// **د سکرین د اندازو ازموینه.**
///
/// د پروګرام هره پاڼه باید په هره کچه کې سمه ځای شي — هیڅ برخه دې
/// له سکرین څخه بهر ونه لویږي. Flutter داسې حالت ته
/// «RenderFlex overflowed» استثنا ورکوي، نو دلته یې نیسو.
void main() {
  /// هغه کچې چې ریښتیني کاروونکي یې لري — له یوه کوچني لپټاپ څخه
  /// تر یوه لوی مانیټر پورې.
  const sizes = <(String, Size)>[
    ('لپټاپ ۱۰۲۴×۶۴۰', Size(1024, 640)),
    ('لپټاپ ۱۲۸۰×۸۰۰', Size(1280, 800)),
    ('HD ۱۳۶۶×۷۶۸', Size(1366, 768)),
    ('۱۶۰۰×۱۰۰۰', Size(1600, 1000)),
    ('FHD ۱۹۲۰×۱۰۸۰', Size(1920, 1080)),
    ('لږ تر لږه ۹۰۰×۶۰۰', Size(900, 600)),
    ('ډېر تنګ ۷۲۰×۵۶۰', Size(720, 560)),
  ];

  Future<AppState> booted() async {
    final s = AppState(DemoBackend());
    await s.boot();
    return s;
  }

  Widget app(AppState s) =>
      ChangeNotifierProvider.value(value: s, child: const ArchiveApp());

  for (final (label, size) in sizes) {
    testWidgets('هیڅ برخه بهر نه لویږي — $label', (t) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));

      final s = await booted();

      for (final theme in [ThemeChoice.light, ThemeChoice.dark]) {
        await s.setTheme(theme);
        await t.pumpWidget(app(s));
        await t.pumpAndSettle();

        for (final page in AppPage.values) {
          s.go(page);
          await t.pumpAndSettle();
          final e = t.takeException();
          expect(e, isNull,
              reason: '$label · ${theme.name} · ${page.name} → $e');

          // **د تنظیماتو هره ډله جلا ده.** پاڼه اوس رېل + محتوا
          // ده، نو یوازې د پاڼې لیدل کافي نه دي — هره ډله باید
          // پخپله وګورو، ګنې د یوې ډلې ماتوالی پټ پاتې کیږي.
          if (page == AppPage.settings) {
            for (final tab in ['بڼه', 'تقویم', 'آرشیف', 'لنډیز', 'په اړه']) {
              final f = find.text(tab);
              if (f.evaluate().isEmpty) continue;
              await t.tap(f.first);
              await t.pumpAndSettle();
              final e2 = t.takeException();
              expect(e2, isNull,
                  reason: '$label · ${theme.name} · تنظیمات/$tab → $e2');
            }
            // بېرته لومړۍ ډلې ته، نو راتلونکې کچه له سره پیل کړي
            final back = find.text('بڼه');
            if (back.evaluate().isNotEmpty) {
              await t.tap(back.first);
              await t.pumpAndSettle();
              t.takeException();
            }
          }
        }

        // ایډیټر او پریویو هم
        s.openEditor(s.events.first);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull,
            reason: '$label · ${theme.name} · editor');

        s.setPreview(true);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull,
            reason: '$label · ${theme.name} · preview');

        s.closeEditor();
        await t.pumpAndSettle();
        t.takeException();
      }
    });
  }

  testWidgets('سایډبار په تنګه کړکۍ کې پخپله راټولیږي', (t) async {
    final s = await booted();

    await t.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(app(s));
    await t.pumpAndSettle();
    // پراخه کړکۍ: د ډلې سرلیکونه ښکاري
    expect(find.text('آرشیف'), findsOneWidget);

    await t.binding.setSurfaceSize(const Size(900, 700));
    await t.pumpAndSettle();
    // تنګه کړکۍ: سایډبار راټول شوی، نو سرلیکونه پټ دي
    expect(find.text('آرشیف'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
