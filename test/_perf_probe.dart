// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/main.dart';

/// څومره وخت نیسي چې یوه پاڼه بشپړه ودریږي (ټولې انیمیشنې پای ته ورسیږي)؟
void main() {
  testWidgets('page settle times', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    Future<void> measure(String label, void Function() act) async {
      final sw = Stopwatch()..start();
      act();
      // لومړی فریم — کله چې کاروونکی لومړی بدلون ویني
      await t.pump();
      final first = sw.elapsedMilliseconds;
      // بشپړ درېدل — کله چې ټولې انیمیشنې پای ته رسیږي
      await t.pumpAndSettle();
      print('  ${label.padRight(22)}لومړی فریم ${first.toString().padLeft(4)}ms   '
          'بشپړ ${sw.elapsedMilliseconds.toString().padLeft(4)}ms');
    }

    print('');
    for (final p in AppPage.values) {
      await measure('→ ${p.name}', () => s.go(p));
    }
    await measure('ایډیټر', () => s.openEditor(s.events.first));
    await measure('پریویو', () => s.setPreview(true));
    print('');
  });
}
