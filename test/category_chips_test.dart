import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/features/shell/title_bar.dart';
import 'package:archive_manager/main.dart';

/// **د نوې پیښې ډایلوګ: کټګورۍ.**
///
/// کاروونکي وویل: «د کټګوریو برخه داسې کړه چې نږدې لس دانې هغه
/// وښودل شي چې زیات کارېدونکې وي، او تر هغه روسته د «ټول وښایه»
/// چیپ وي».
void main() {
  testWidgets('یوازې ۱۰ ډېرې کارېدونکې ښکاري، بیا «ټول وښایه»',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final b = DemoBackend();
    final s = AppState(b);
    await s.boot();

    // ۱۸ کټګورۍ جوړوو — نو د «ټول وښایه» چیپ راښکاره شي.
    for (var i = 0; i < 18; i++) {
      await s.addVocab(VocabKind.category, 'کټګوري-${i + 1}');
    }

    AppTitleBar.debugForceShow = true;
    addTearDown(() => AppTitleBar.debugForceShow = false);
    await t.pumpWidget(
        ChangeNotifierProvider.value(value: s, child: const ArchiveApp()));
    await t.pumpAndSettle();

    await t.tap(find.byKey(AppTitleBar.kNewEvent));
    await t.pumpAndSettle();

    final all = await s.vocab(VocabKind.category);
    expect(all.length, greaterThan(12), reason: 'د ازموینې لپاره ډېرې پکار دي');

    // د «ټول وښایه» چیپ شته
    final showAll = find.textContaining('ټول وښایه');
    expect(showAll, findsOneWidget);

    // تر پراخېدو دمخه، ټولې کټګورۍ نه ښکاري
    final before = find.byWidgetPredicate((w) =>
        w is Text && (w.data ?? '').startsWith('کټګوري-')).evaluate().length;
    expect(before, lessThanOrEqualTo(11),
        reason: 'یوازې ~۱۰ چپونه باید ښکاره شي');

    await t.tap(showAll);
    await t.pumpAndSettle();

    final after = find.byWidgetPredicate((w) =>
        w is Text && (w.data ?? '').startsWith('کټګوري-')).evaluate().length;
    expect(after, greaterThan(before), reason: 'پراخېدل باید نور راولي');
    expect(find.text('لږ وښایه'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
