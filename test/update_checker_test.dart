import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:archive_manager/core/update/update_checker.dart';

/// **د نوې نسخې کتنه.**
///
/// کاروونکي وویل: «ټول هغه شرایط لحاظ کړه چې راتلونکی کې نوي
/// اپډیټونه په سالمه او آمن توګه نصب کړو».
void main() {
  UpdateChecker make(String tag, {String current = '1.0.0', int status = 200}) =>
      UpdateChecker(
        currentVersion: current,
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'tag_name': tag,
              'html_url':
                  'https://github.com/ElyasOmarcodes/Archive-Manager/releases/tag/$tag',
            }),
            status)),
      );

  test('نوې نسخه پېژندل کیږي', () async {
    final u = make('v1.1.0');
    await u.check();
    expect(u.latest, '1.1.0');
    expect(u.hasUpdate, isTrue);
    expect(u.releaseUrl, contains('v1.1.0'));
  });

  test('هماغه نسخه = هیڅ خبرتیا', () async {
    final u = make('v1.0.0');
    await u.check();
    expect(u.hasUpdate, isFalse);
  });

  test('زړه نسخه پر سرور = هیڅ خبرتیا', () async {
    final u = make('v0.9.9');
    await u.check();
    expect(u.hasUpdate, isFalse);
  });

  test('عددي پرتله — نه د متن', () {
    expect(UpdateChecker.isNewer('1.10.0', '1.9.3'), isTrue,
        reason: '۱۰ تر ۹ لوی دی — که متن پرتله کړو، «۱۰» تر «۹» کوچنی وي');
    expect(UpdateChecker.isNewer('2.0.0', '1.99.99'), isTrue);
    expect(UpdateChecker.isNewer('1.0.1', '1.0.1'), isFalse);
    expect(UpdateChecker.isNewer('1.0.0', '1.0.1'), isFalse);
  });

  test('د شبکې ناکامي پروګرام نه ماتوي', () async {
    final u = UpdateChecker(
      currentVersion: '1.0.0',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await u.check();
    expect(u.hasUpdate, isFalse);
    expect(u.latest, isNull);
  });

  test('د سرور تېروتنه هم بې‌زیانه ده', () async {
    final u = make('v2.0.0', status: 500);
    await u.check();
    expect(u.hasUpdate, isFalse);
  });
}
