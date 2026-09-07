// ignore_for_file: avoid_print
@TestOn('linux || mac-os || windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/main.dart';

/// **د ریښتیني کچې پر سر د UI وخت.**
///
/// د ډیمو ۱۲ پیښې هیڅ نه ثابتوي. دلته د ریښتیني نمونې آرشیف ټول
/// `metadata.json` فایلونه لوستل کیږي او UI پرې چلیږي — نو معلومیږي
/// چې د پاڼې پرانیستل د پیښو له شمېر سره څنګه بدلیږي.
void main() {
  testWidgets('page open times at real scale', (t) async {
    const root = String.fromEnvironment('ARCHIVE',
        defaultValue: '/tmp/claude-0/Arvitch-Sample');
    if (!Directory(root).existsSync()) {
      print('  نمونه آرشیف نشته: $root');
      return;
    }

    // ── ټول `metadata.json` لوستل ──
    final sw = Stopwatch()..start();
    final events = <EventMetadata>[];
    for (final f in Directory(root).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('metadata.json')) continue;
      events.add(EventMetadata.fromJson(
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
          folderPath: f.parent.path));
    }
    final readMs = sw.elapsedMilliseconds;

    await t.binding.setSurfaceSize(const Size(1920, 1200));
    final s = AppState(DemoBackend(seeded: false));
    await s.boot();
    s.backend.saveEvent(events.first); // د ایندکس پرانیستل
    for (final e in events) {
      await s.backend.saveEvent(e);
    }
    await s.refresh();

    print('\n  ${events.length} پیښې له ډیسکه لوستل شوې: ${readMs}ms'
        '  (${(readMs * 1000 / events.length).round()}µs پر پیښه)');
    print('  د لټون پایله: ${s.events.length} پیښې\n');

    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    Future<void> measure(String label, void Function() act) async {
      final w = Stopwatch()..start();
      act();
      await t.pump();
      final first = w.elapsedMilliseconds;
      await t.pumpAndSettle();
      print('  ${label.padRight(20)}لومړی فریم ${first.toString().padLeft(4)}ms'
          '   بشپړ ${w.elapsedMilliseconds.toString().padLeft(4)}ms');
    }

    for (final p in AppPage.values) {
      await measure('→ ${p.name}', () => s.go(p));
    }
    print('');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
