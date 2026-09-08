import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/main.dart';

/// یو بېک‌اېنډ چې «ریښتینی» ښکاري — نو د اکسپورټ د ثبت ډایلوګ
/// لاره ازمویل کیږي، پرته له دې چې ریښتینی ډایلوګ پرانیستل شي.
class _FakeDesktop extends DemoBackend {
  _FakeDesktop({this.cancel = false});

  /// آیا کاروونکی ډایلوګ لغوه کوي؟
  final bool cancel;

  String? askedName;
  String? askedDir;
  int calls = 0;
  int blindWrites = 0;

  @override
  bool get isReal => true;

  @override
  Future<String?> saveFileAs({
    required String fileName,
    required List<int> bytes,
    String? initialDirectory,
    String mimeType = 'application/octet-stream',
  }) async {
    calls++;
    askedName = fileName;
    askedDir = initialDirectory;
    return cancel ? null : r'C:\Users\Elyas\Desktop\' + fileName;
  }

  @override
  Future<String?> writeBytes(String path, List<int> bytes) async {
    blindWrites++;
    return path;
  }
}

/// **د اکسپورټ لاره** — کاروونکي وویل چې د ثبت ځای باید هغه وټاکي.
void main() {
  Future<AppState> open(WidgetTester t, DemoBackend b) async {
    await t.binding.setSurfaceSize(const Size(1500, 950));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final s = AppState(b);
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    s.openEditor(s.events.first, preview: true);
    await t.pumpAndSettle();
    return s;
  }

  /// د اکسپورټ منو پرانیزي او «یوازې PDF» ټاکي.
  Future<void> exportPdf(WidgetTester t) async {
    await t.tap(find.byIcon(Icons.ios_share_rounded).first);
    await t.pumpAndSettle();
    await t.tap(find.text('یوازې PDF').last);
    await t.pumpAndSettle();
  }

  testWidgets('اکسپورټ د ثبت ډایلوګ راولي — نه چې چوپ‌چاپ ولیکي',
      (t) async {
    final b = _FakeDesktop();
    await open(t, b);
    await exportPdf(t);

    expect(b.calls, 1, reason: 'د وینډوز د ثبت ډایلوګ باید راشي');
    expect(b.askedName, endsWith('.pdf'));
    expect(b.blindWrites, 0, reason: 'پرته له پوښتنې هیڅ نه لیکل کیږي');
    expect(find.textContaining('ثبت شو'), findsOneWidget);
  });

  testWidgets('که کاروونکی لغوه کړي، هیڅ نه ثبتیږي', (t) async {
    final b = _FakeDesktop(cancel: true);
    await open(t, b);
    await exportPdf(t);

    expect(b.calls, 1);
    expect(b.blindWrites, 0);
    expect(find.textContaining('لغوه'), findsOneWidget);
  });

  testWidgets('ټوسټ پخپله ورکیږي — نه چې پر پردې پاتې شي', (t) async {
    final b = _FakeDesktop();
    await open(t, b);
    await exportPdf(t);
    expect(find.byType(SnackBar), findsOneWidget);

    // ۵ ثانیې + د ورکېدو انیمیشن
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing,
        reason: 'ټوسټ باید پخپله ولاړ شي');
  });
}
