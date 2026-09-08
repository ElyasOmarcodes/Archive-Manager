@TestOn('linux || mac-os || windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:archive_manager/data/models/query.dart';
import 'package:archive_manager/data/platform/io_backend.dart';

/// **پرګمنټ سکن.**
///
/// کاروونکي وویل: «ولې هر ځل چې پروګرام خلاصوو ټول ډیټابیس اسکن
/// کیږي؟ … یو ځل چې لومړي کې اسکن شي، بیا اسکن باید ضرورت نه وي،
/// ترڅو چټک وي».
///
/// نو دا ازموینه ګوري چې:
///
/// ۱. لومړی سکن هر څه مومي
/// ۲. دویم سکن هغه فایلونه چې **بدل شوي نه دي، بیخي نه لولي**
/// ۳. بدل شوی فایل بیا لوستل کیږي
/// ۴. ورک شوې پیښه له ایندکسه وځي
/// ۵. `lastScanAt` ثبتیږي — نو پیل پوهیږي چې سکن ته اړتیا نشته
void main() {
  late Directory root;
  late Directory state;
  late IoBackend backend;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('arv_inc_');
    state = Directory.systemTemp.createTempSync('arv_state_');
    backend = IoBackend(stateDirOverride: state.path);
    await backend.openIndex(root.path);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    state.deleteSync(recursive: true);
  });

  /// یوه پیښه پر ډیسک لیکي او د `metadata.json` مسیر راګرځوي.
  File write(String folder, String id, String title) {
    final dir = Directory(p.join(root.path, folder))..createSync(recursive: true);
    final f = File(p.join(dir.path, 'metadata.json'));
    f.writeAsStringSync(jsonEncode({
      'id': id,
      'title': title,
      'dateJdn': 2460000,
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
    }));
    return f;
  }

  Future<int> scan() async {
    await for (final _ in backend.rescan(root.path)) {}
    return (await backend.stats()).eventCount;
  }

  Future<String?> titleOf(String id) async =>
      (await backend.eventById(id))?.title;

  test('لومړی سکن ټولې پیښې مومي، او وخت یې ثبتوي', () async {
    write('a', 'e1', 'لومړۍ');
    write('b', 'e2', 'دویمه');

    expect(await scan(), 2);
    expect(await backend.lastScanAt(root.path), isNotNull);
    // بل مسیر ته دا مهر نه ورکوي
    expect(await backend.lastScanAt(p.join(root.path, 'x')), isNull);
  });

  test('دویم سکن هغه فایل چې مهر یې بدل نه وي، بیخي نه لولي', () async {
    final f = write('a', 'e1', 'لومړۍ');
    expect(await scan(), 1);

    final stamp = f.statSync().modified;

    // محتوا بدلوو، خو **مهر یې بېرته پخوانی کوو** — لکه چې فایل
    // نه وي بدل شوی. که سکن پرګمنټ وي، دا بدلون به ونه ویني.
    f.writeAsStringSync(jsonEncode({
      'id': 'e1',
      'title': 'پټ بدلون',
      'dateJdn': 2460000,
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
    }));
    f.setLastModifiedSync(stamp);

    expect(await scan(), 1);
    expect(await titleOf('e1'), 'لومړۍ',
        reason: 'بې‌بدلونه فایل باید بیا ونه لوستل شي');
  });

  test('ریښتینی بدلون بیا لوستل کیږي', () async {
    final f = write('a', 'e1', 'لومړۍ');
    expect(await scan(), 1);

    f.writeAsStringSync(jsonEncode({
      'id': 'e1',
      'title': 'تازه شوې',
      'dateJdn': 2460000,
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 1, 2).toIso8601String(),
    }));
    f.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));

    expect(await scan(), 1);
    expect(await titleOf('e1'), 'تازه شوې');
  });

  test('ورکه شوې پوښۍ له ایندکسه وځي', () async {
    write('a', 'e1', 'لومړۍ');
    write('b', 'e2', 'دویمه');
    expect(await scan(), 2);

    Directory(p.join(root.path, 'b')).deleteSync(recursive: true);

    expect(await scan(), 1);
    expect(await backend.eventById('e2'), isNull);
    expect(await titleOf('e1'), 'لومړۍ');
  });

  test('نوې پیښه پرته له بشپړ بیا جوړولو ورزیاتیږي', () async {
    write('a', 'e1', 'لومړۍ');
    expect(await scan(), 1);

    write('c', 'e3', 'درېیمه');
    expect(await scan(), 2);
    expect(await backend.search(const EventQuery()), hasLength(2));
  });
}
