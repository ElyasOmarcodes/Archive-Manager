import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/main.dart';
import 'package:archive_manager/widgets/common.dart';

/// **د ټولې شوې ډلې حالت باید د سکرول پر مهال ونه ورکیږي.**
///
/// کاروونکي وموند: یوه فیلټر ډله ټوله کړه، سکرول یې وکړ، بیرته
/// راغی — بیا خپره وه. علت: `ListView.builder` هغه توکي غورځوي چې
/// له پردې بهر وځي، نو د ویجټ دننه ساتل شوی حالت له منځه ځي.
void main() {
  setUp(CollapsedRegistry.reset);

  test('یادښت حالت ساتي', () {
    expect(CollapsedRegistry.isOpen('x'), isTrue, reason: 'ډیفالټ خپور');
    CollapsedRegistry.set('x', false);
    expect(CollapsedRegistry.isOpen('x'), isFalse);
    CollapsedRegistry.set('x', true);
    expect(CollapsedRegistry.isOpen('x'), isTrue);
    // بېلې برخې یو بل ته نه ګوري
    expect(CollapsedRegistry.isOpen('y'), isTrue);
  });

  testWidgets('د فیلټر ډله ټوله شي، سکرول وشي — ټوله پاتې کیږي',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 900));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();
    s.go(AppPage.events);
    await t.pumpAndSettle();

    // «درجه (ستوري)» ډله ټوله کړه
    final header = find.text('درجه (ستوري)');
    expect(header, findsOneWidget);
    // د ډلې دننه د «۵» کرښه ښکاري
    expect(find.byType(CollapsibleSection), findsWidgets);

    await t.tap(header);
    await t.pumpAndSettle();
    expect(CollapsedRegistry.isOpen('filter.rating'), isFalse,
        reason: 'ټوله شوه');

    // د فیلټر پینل ښکته سکرول کړه — نو ډله له پردې بهر شي
    final panel = find.byType(Scrollable).first;
    await t.drag(panel, const Offset(0, -1200));
    await t.pumpAndSettle();
    // بیا بیرته پورته
    await t.drag(panel, const Offset(0, 1600));
    await t.pumpAndSettle();

    // ✅ لا هم ټوله ده
    expect(CollapsedRegistry.isOpen('filter.rating'), isFalse,
        reason: 'د سکرول روسته باید ټوله پاتې شي');
  });

  testWidgets('د میټاډیټا پنل ډلې هم حالت ساتي', (t) async {
    // پنل یو `ListView` دی — لنډه کړکۍ کې لاندې برخې نه جوړیږي.
    await t.binding.setSurfaceSize(const Size(1600, 1500));
    final s = AppState(DemoBackend());
    await s.boot();
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();
    s.go(AppPage.events);
    await t.pumpAndSettle();
    s.openEditor(s.events.first);
    await t.pumpAndSettle();

    await t.tap(find.text('کیورډونه'));
    await t.pumpAndSettle();
    expect(CollapsedRegistry.isOpen('meta.keywords'), isFalse);

    // پاڼه بدله کړه او بیرته راشه — حالت باید پاتې شي
    s.closeEditor();
    await t.pumpAndSettle();
    s.openEditor(s.events.first);
    await t.pumpAndSettle();
    expect(CollapsedRegistry.isOpen('meta.keywords'), isFalse,
        reason: 'د پاڼې د بدلون روسته هم');
  });
}
