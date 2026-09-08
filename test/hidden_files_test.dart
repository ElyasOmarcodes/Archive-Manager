@TestOn('linux || mac-os || windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:archive_manager/data/platform/io_backend.dart';

/// **د ثبت فایلونه پټ دي.**
///
/// کاروونکي وویل: «د میټاډیټا د دواړو فایلونو نوعه هیډین کړه ترڅو
/// عادي کاروونکی یې … ونه شي لیدلی، ترڅو کاروونکو ته محیط صفا وي».
///
/// پر وینډوز دا د فایل د **پټ صفت** له لارې کیږي؛ پر هر سیسټم یې
/// داخلي اکسپلورر د نوم له مخې هم پېژني — نو د لینکس پر CI هم
/// ازمویل کیږي.
void main() {
  late Directory root;
  late Directory state;
  late IoBackend backend;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('arv_hide_');
    state = Directory.systemTemp.createTempSync('arv_state_');
    backend = IoBackend(stateDirOverride: state.path);
    await backend.openIndex(root.path);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    state.deleteSync(recursive: true);
  });

  test('د پیښې پوښۍ کې ثبت فایلونه پټ نښه شوي دي', () async {
    final dir = Directory(p.join(root.path, 'پیښه'))..createSync();
    File(p.join(dir.path, 'metadata.json')).writeAsStringSync(jsonEncode({
      'id': 'e1',
      'title': 'پیښه',
      'dateJdn': 2460000,
      'createdAt': DateTime(2026).toIso8601String(),
      'updatedAt': DateTime(2026).toIso8601String(),
    }));
    File(p.join(dir.path, 'content.json')).writeAsStringSync('{}');
    File(p.join(dir.path, 'index.html')).writeAsStringSync('<html></html>');
    File(p.join(dir.path, 'video.mp4')).writeAsStringSync('x');

    final list = await backend.listDirectory(dir.path);
    Map<String, bool> byName = {for (final e in list) e.name: e.isHidden};

    expect(byName['metadata.json'], isTrue, reason: 'ثبت فایل باید پټ وي');
    expect(byName['content.json'], isTrue, reason: 'ثبت فایل باید پټ وي');
    expect(byName['index.html'], isFalse, reason: 'پاڼه کاروونکي ته ده');
    expect(byName['video.mp4'], isFalse, reason: 'ضمیمې ښکاره وي');
  });

  test('پټ توکي لا هم راګرځي — اکسپلورر پخپله پرېکړه کوي', () async {
    final dir = Directory(p.join(root.path, 'پیښه'))..createSync();
    File(p.join(dir.path, 'metadata.json')).writeAsStringSync('{}');

    final list = await backend.listDirectory(dir.path);
    expect(list.map((e) => e.name), contains('metadata.json'),
        reason: 'بېک‌اېنډ یې غورځوي نه — یوازې نښه کوي، نو د '
            '«پټ فایلونه وښایه» افشن کار وکړي');
  });
}
