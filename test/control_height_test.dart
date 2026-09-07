import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/core/theme/tokens.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/main.dart';
import 'package:archive_manager/widgets/common.dart';

/// **د کنټرولونو یو شان لوړوالی.**
///
/// کاروونکي راپور کړه چې د لټون بار تر خپلو ګاونډیو تڼیو لوړ دی او
/// «ډېر بد ښکاري». علت: هر ډول کنټرول خپل پیډنګ درلود، او Material
/// پخپله تڼیو ته د لمس لپاره ۴۸px لږ‌تر‌لږه لوړوالی ورکاوه.
void main() {
  Future<AppState> boot(WidgetTester t, [Size size = const Size(1800, 1100)]) async {
    await t.binding.setSurfaceSize(size);
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();
    return s;
  }

  /// د یوه ډول ټول ویجټونه او لوړوالی یې.
  List<double> heights(WidgetTester t, Finder f) =>
      f.evaluate().map((e) => t.getSize(find.byWidget(e.widget)).height).toList();

  testWidgets('د لټون بار دقیقاً `controlH` جګ دی', (t) async {
    await boot(t);
    for (final h in heights(t, find.byType(SearchBox))) {
      expect(h, AppTokens.controlH,
          reason: 'هر لټون بار باید ${AppTokens.controlH} وي');
    }
  });

  testWidgets('په اکسپلورر ټولبار کې تڼۍ او لټون بار یو شان دي',
      (t) async {
    final s = await boot(t);
    s.go(AppPage.explorer);
    await t.pumpAndSettle();

    final search = heights(t, find.byType(SearchBox));
    expect(search, isNotEmpty, reason: 'اکسپلورر لټون بار لري');

    // ټولې «ډکې» تڼۍ (لکه «نوی +»)
    final filled = heights(t, find.byType(FilledButton));
    for (final h in [...search, ...filled]) {
      expect(h, lessThanOrEqualTo(AppTokens.controlHLg),
          reason: 'هیڅ کنټرول باید تر ${AppTokens.controlHLg} لوړ نه وي');
    }
    // او لټون بار تر تڼیو لوړ نه دی
    if (filled.isNotEmpty) {
      expect(search.first, lessThanOrEqualTo(filled.reduce((a, b) => a > b ? a : b) + 0.5),
          reason: 'لټون بار تر تڼیو لوړ نه دی');
    }
  });

  testWidgets('تڼۍ د Material له ۴۸px لږ‌تر‌لږه څخه خلاصې دي', (t) async {
    await boot(t);
    // ډاشبورډ کې د «نوې پیښه» تڼۍ
    final filled = heights(t, find.byType(FilledButton));
    expect(filled, isNotEmpty);
    for (final h in filled) {
      expect(h, lessThan(48),
          reason: 'tapTargetSize.shrinkWrap باید فعال وي — ونه: $filled');
    }
  });
}
