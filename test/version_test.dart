@TestOn('linux || mac-os || windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:archive_manager/core/app_info.dart';

/// نسخه په یوه ځای کې ده — دا ازموینه یې له `pubspec.yaml` سره
/// پرتله کوي، نو بېرته درې ځایه نه شي.
void main() {
  test('kAppVersion د pubspec.yaml سره سم دی', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final pubspec = line.split(':')[1].trim().split('+').first;
    expect(kAppVersion, pubspec,
        reason: 'lib/core/app_info.dart او pubspec.yaml سره نه ښایي');
  });
}
