import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:archive_manager/data/models/models.dart';
import 'package:archive_manager/data/platform/demo_backend.dart';
import 'package:archive_manager/data/repository/app_state.dart';
import 'package:archive_manager/features/editor/html_builder.dart';
import 'package:archive_manager/features/shell/title_bar.dart';
import 'package:archive_manager/main.dart';

Widget app(AppState s) =>
    ChangeNotifierProvider.value(value: s, child: const ArchiveApp());

Future<AppState> booted() async {
  final s = AppState(DemoBackend());
  await s.boot();
  return s;
}

void main() {
  testWidgets('typing in the top search jumps to events and filters',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = await booted();
    await t.pumpWidget(app(s));
    await t.pumpAndSettle();

    // پورتنی ټول‌ځایي لټون
    final search = find.byType(TextField).first;
    await t.enterText(search, 'کندهار');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    expect(s.page, AppPage.events, reason: 'باید پیښو پاڼې ته ولاړ شي');
    expect(s.query.text, 'کندهار');
    expect(s.events.length, 1);
    expect(s.events.single.title, contains('کندهار'));
    expect(t.takeException(), isNull);
  });

  testWidgets('rating filter chip narrows results and the count updates',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = await booted();
    await t.pumpWidget(app(s));
    s.go(AppPage.events);
    await t.pumpAndSettle();

    final before = s.facets.total;
    expect(before, greaterThan(0));

    // پنځه‌ستوري فلټر
    await s.setQuery(s.query.copyWith(ratings: {5}));
    await t.pumpAndSettle();

    expect(s.facets.total, lessThan(before));
    expect(s.events.every((e) => e.rating == 5), isTrue);
    // د فاسیټ شمېرې خپله ډله نه فلټروي — نو ۳ ستوري هم لا ښکاري
    expect(s.facets.ratings.keys.where((r) => r != 5), isNotEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('saving an event writes index.html and refreshes the index',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final backend = DemoBackend();
    final s = AppState(backend);
    await s.boot();
    await t.pumpWidget(app(s));
    await t.pumpAndSettle();

    final e = s.events.first;
    final edited = e.copyWith(title: '${e.title} (تازه شوی)', rating: 2);
    await s.saveEvent(edited, html: buildEventHtml(edited));
    await t.pumpAndSettle();

    // ایندکس تازه شو
    final found = await backend.eventById(e.id);
    expect(found!.title, contains('تازه شوی'));
    expect(found.rating, 2);

    // او HTML هم ولیکل شو
    final html = await backend.readHtml(edited.folderPath);
    expect(html, isNotNull);
    expect(html!, contains('تازه شوی'));
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(t.takeException(), isNull);
  });

  testWidgets('adding a keyword registers it in the vocabulary', (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = await booted();
    await t.pumpWidget(app(s));
    await t.pumpAndSettle();

    final before = (await s.vocab(VocabKind.keyword)).length;
    await s.addVocab(VocabKind.keyword, 'نوی-کیورډ');
    final after = await s.vocab(VocabKind.keyword);

    expect(after.length, before + 1);
    expect(after.any((k) => k.name == 'نوی-کیورډ'), isTrue);
  });

  testWidgets('renaming a keyword updates every event that uses it',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = await booted();
    await t.pumpWidget(app(s));
    await t.pumpAndSettle();

    // یو کیورډ ومومه چې په څو پیښو کې کارول کیږي
    final kws = await s.vocab(VocabKind.keyword);
    final used = kws.firstWhere((k) => k.usageCount > 0);

    final n = await s.renameVocab(VocabKind.keyword, used.name, 'بدل-شوی');
    expect(n, used.usageCount);

    // هیڅ پیښه لا زوړ نوم نه لري
    await s.setQuery(s.query.copyWith(keywords: {used.name}));
    expect(s.events, isEmpty);

    // او نوی نوم یې مومي
    await s.setQuery(s.query.copyWith(keywords: {'بدل-شوی'}));
    expect(s.events.length, used.usageCount);
  });

  testWidgets('د تیم تڼۍ (اوس په ټایټل بار کې) کړۍ وهي', (t) async {
    // پخوا دا تڼۍ د ډاشبورډ په پورتني بار کې وه. کاروونکي وویل چې
    // ټایټل بار ته دې ولاړه شي «ترڅو تل لاسرسي وړ وي» — نو اوس
    // هلته ده، او په هره پاڼه کې کار کوي.
    AppTitleBar.debugForceShow = true;
    addTearDown(() => AppTitleBar.debugForceShow = false);

    await t.binding.setSurfaceSize(const Size(1600, 1000));
    final s = await booted();
    await t.pumpWidget(app(s));
    await t.pumpAndSettle();

    // له «سیستم» پیل کیږي؛ هره وهنه یې مخکې بیایي:
    // سیستم → سپین → تیاره → سیستم
    expect(s.themeMode, ThemeMode.system);

    for (final expected in const [
      ThemeMode.light,
      ThemeMode.dark,
      ThemeMode.system,
    ]) {
      final btn = find.byKey(AppTitleBar.kTheme);
      expect(btn, findsOneWidget);
      await t.tap(btn);
      await t.pumpAndSettle();
      expect(s.themeMode, expected);
    }
    expect(t.takeException(), isNull);
  });
}
