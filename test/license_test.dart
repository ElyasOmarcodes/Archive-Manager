
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/core/license/license_gate.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/features/onboarding/expired_page.dart';
import 'package:archive_manager/main.dart';

/// **د کنټرول فایل څارنه.**
///
/// کاروونکي وویل: «که چیرته دا محتوا له `true` څخه `false` ته بدله
/// شوه، نو سمدلاسه باید پروګرام د اکسپایر پاڼې ته لاړ شي … کله چې
/// پروګرام لاک شو نو بیا به انلاین هم بلاک وي ترڅو چې … د خلاصون
/// امر ترلاسه کړي».
void main() {
  /// یو جوړ شوی سرور — هر ځل هغه څه راګرځوي چې `body` کې وي.
  ({LicenseGate gate, List<bool> saved}) gate(
    String Function() body, {
    int status = 200,
    bool throwIt = false,
  }) {
    final saved = <bool>[];
    final client = MockClient((r) async {
      if (throwIt) throw http.ClientException('offline');
      return http.Response(body(), status);
    });
    return (
      gate: LicenseGate(
        client: client,
        onChanged: (locked, at) async => saved.add(locked),
      ),
      saved: saved,
    );
  }

  test('«true» یعنې خلاص', () async {
    final g = gate(() => 'true');
    expect(await g.gate.check(), isTrue);
    expect(g.gate.locked, isFalse);
  });

  test('«false» سمدلاسه تړي — او ثبتیږي', () async {
    final g = gate(() => 'false\n');
    expect(await g.gate.check(), isFalse);
    expect(g.gate.locked, isTrue);
    expect(g.gate.lockedAt, isNotNull);
    expect(g.saved, [true], reason: 'لاک باید وساتل شي');
  });

  test('هر بل متن هم تړي — نه یوازې «false»', () async {
    final g = gate(() => 'blocked');
    expect(await g.gate.check(), isFalse);
    expect(g.gate.locked, isTrue);
  });

  test('د انټرنیټ نشتوالی هیڅکله نه تړي', () async {
    final g = gate(() => '', throwIt: true);
    expect(await g.gate.check(), isTrue, reason: 'افلاین ≠ تړل شوی');
    expect(g.gate.locked, isFalse);
    expect(g.gate.lastError, isNotNull);
  });

  test('د سرور تېروتنه (۵۰۰) هم نه تړي', () async {
    final g = gate(() => 'false', status: 500);
    expect(await g.gate.check(), isTrue);
    expect(g.gate.locked, isFalse);
  });

  test('تړل شوی حالت یوازې د نوې اجازې سره خلاصیږي', () async {
    var body = 'false';
    final g = gate(() => body);

    await g.gate.check();
    expect(g.gate.locked, isTrue);

    // انټرنیټ ولاړ — لا هم تړلی
    final offline = LicenseGate(
      client: MockClient((_) async => throw http.ClientException('x')),
      onChanged: (_, _) async {},
    )..restore(locked: true, at: DateTime.now());
    await offline.check();
    expect(offline.locked, isTrue, reason: 'افلاین یې نه خلاصوي');

    // سرور بیا اجازه ورکړه
    body = 'true';
    await g.gate.check();
    expect(g.gate.locked, isFalse);
    expect(g.saved, [true, false]);
  });

  test('څارنه پخپله هر څو ثانیې پوښتنه کوي', () async {
    var hits = 0;
    final gate = LicenseGate(
      client: MockClient((_) async {
        hits++;
        return http.Response('true', 200);
      }),
      onChanged: (_, _) async {},
      every: const Duration(milliseconds: 40),
    )..start();

    await Future<void>.delayed(const Duration(milliseconds: 150));
    gate.dispose();
    expect(hits, greaterThanOrEqualTo(3),
        reason: 'امر باید په څو ثانیو کې ورسیږي');
  });

  testWidgets('تړل شوی پروګرام د اکسپایر پاڼه ښیي', (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final s = AppState(DemoBackend());
    await s.boot();
    s.license.restore(locked: true, at: DateTime.now());
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    expect(find.byType(ExpiredPage), findsOneWidget);
    expect(find.text('پروګرام تړل شوی دی'), findsOneWidget);
    expect(find.text('بیا هڅه'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('لومړی د API پوښتنه کیږي — نه خام (کیش لرونکی) لینک', () async {
    final urls = <String>[];
    final gate = LicenseGate(
      client: MockClient((r) async {
        urls.add(r.url.host);
        return http.Response('true', 200, headers: {'etag': 'W/"1"'});
      }),
      onChanged: (_, _) async {},
    );

    await gate.check();
    expect(urls, ['api.github.com'],
        reason: 'خام لینک ۵ دقیقې کیش کیږي — نو API لومړی دی');
  });

  test('«بدلون نشته» (۳۰۴) اوسنی متن ساتي', () async {
    var calls = 0;
    final gate = LicenseGate(
      client: MockClient((r) async {
        calls++;
        if (calls == 1) {
          return http.Response('true', 200, headers: {'etag': 'W/"abc"'});
        }
        // دویم ځل: شرطي پوښتنه باید نښه ولېږي
        expect(r.headers['If-None-Match'], 'W/"abc"');
        return http.Response('', 304);
      }),
      onChanged: (_, _) async {},
    );

    expect(await gate.check(), isTrue);
    expect(await gate.check(), isTrue, reason: '۳۰۴ = هماغه پخوانی ځواب');
    expect(calls, 2);
  });

  test('که API ونه چلیږي، خام لینک د کیش‌بسټر سره کاریږي', () async {
    final tried = <Uri>[];
    final gate = LicenseGate(
      client: MockClient((r) async {
        tried.add(r.url);
        if (r.url.host == 'api.github.com') {
          return http.Response('rate limited', 403);
        }
        return http.Response('false', 200);
      }),
      onChanged: (_, _) async {},
    );

    expect(await gate.check(), isFalse);
    expect(gate.locked, isTrue, reason: 'خام لینک هم امر رسوي');
    expect(tried.length, 2);
    expect(tried.last.host, 'raw.githubusercontent.com');
    expect(tried.last.queryParameters['t'], isNotNull,
        reason: 'د کیش مخنیوی — ګنې ۵ دقیقې زوړ ځواب راځي');
    expect(tried.last.host, isNot('api.github.com'));
  });
}
