import 'dart:async';

import 'package:archive_manager/data/platform/backend.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/features/onboarding/boot_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'smoke_test.dart' show wrap;

/// یو بېک‌اېنډ چې **ایندکس یې ماتیږي** — د پیل د تېروتنې ازموینه.
class _BrokenBackend extends DemoBackend {
  @override
  Future<void> openIndex(String root) async =>
      throw StateError('index corrupt');
}

/// یو **ریښتینی‌ډوله** بېک‌اېنډ چې سکن یې **هیڅکله نه تمامیږي**.
///
/// که پیل د سکن انتظار وکړي، `boot()` به هیڅکله بشپړ نه شي —
/// همدا هغه هنګ و چې کاروونکي د سپلش پاڼې پر مهال ولید.
class _HangingScanBackend extends DemoBackend {
  bool scanStarted = false;

  @override
  bool get isReal => true;

  @override
  Stream<ScanProgress> rescan(String root) {
    scanStarted = true;
    return StreamController<ScanProgress>().stream; // هیڅکله نه تړل کیږي
  }
}

void main() {
  test('پیل د سکن انتظار نه کوي — سپلش هنګ نه کیږي', () async {
    final b = _HangingScanBackend();
    final s = AppState(b);

    // که دا `await` بند پاتې شي، ازموینه د وخت له مخې ناکامه کیږي.
    await s.boot().timeout(const Duration(seconds: 5));

    expect(s.booting, isFalse, reason: 'پیل باید تمام شي');
    expect(b.scanStarted, isTrue, reason: 'سکن باید په پس‌منظر کې پیل شي');
  });

  test('تېروتنه د سپلش پاڼه تلپاتې نه کوي', () async {
    final s = AppState(_BrokenBackend());

    await s.boot().timeout(const Duration(seconds: 5));

    expect(s.booting, isFalse, reason: 'تېروتنه هم باید پروګرام پرانیزي');
    expect(s.bootError, isNotNull);
    expect(s.bootError, contains('index corrupt'));
  });

  test('د پیل ګامونه کاروونکي ته ښکاري', () async {
    final s = AppState(DemoBackend());
    final steps = <String>[];
    s.addListener(() {
      if (steps.isEmpty || steps.last != s.bootStep) steps.add(s.bootStep);
    });

    expect(s.bootStep, isNotEmpty, reason: 'لومړی ګام باید له پیله وي');
    await s.boot().timeout(const Duration(seconds: 5));

    expect(steps.length, greaterThanOrEqualTo(2),
        reason: 'ګامونه باید مخ ته ولاړ شي، نه یو چوپ بار');
  });

  test('ورک مسیر د تېروتنې پر ځای د بیا هڅې پاڼې ته بیایي', () async {
    final s = AppState(_MissingRootBackend());

    await s.boot().timeout(const Duration(seconds: 5));

    expect(s.booting, isFalse);
    expect(s.rootMissing, isTrue);
    expect(s.bootError, isNull);
  });

  testWidgets('د پیل پاڼه ژوندۍ ده — ایکن، نوم او روان ګام ښیي',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 800));
    final b = _HangingScanBackend();
    final s = AppState(b);

    await t.pumpWidget(wrap(s));
    await t.pump();

    expect(find.byType(BootGate), findsOneWidget);
    // یو څرخېدونکی بار بس نه دی — ګام باید په نوم ښکاره شي.
    expect(find.text(s.bootStep), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // پیل روان کړه: پاڼه باید پرانیستل شي، نه چې بنده پاتې شي.
    await s.boot().timeout(const Duration(seconds: 5));
    await t.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(LinearProgressIndicator), findsNothing,
        reason: 'د پیل پاڼه باید لاړه شي');
    expect(t.takeException(), isNull);
    await t.binding.setSurfaceSize(null);
  });
}

class _MissingRootBackend extends DemoBackend {
  @override
  Future<bool> pathExists(String path) async => false;
}
