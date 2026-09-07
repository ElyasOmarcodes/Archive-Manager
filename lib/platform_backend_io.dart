import 'dart:io';

import 'package:flutter/widgets.dart' show Size;

import 'package:window_manager/window_manager.dart';

import 'data/platform/backend.dart';
import 'data/platform/io_backend.dart';

/// ډیسکټاپ: ریښتینی فایل سیسټم + SQLite ایندکس.
ArchiveBackend createBackend() => IoBackend();

/// د کړکۍ لومړني تنظیمات.
///
/// **د سیسټم خپل ټایټل بار پټ دی.** پرځای یې پروګرام خپل بار
/// رسموي (`lib/features/shell/title_bar.dart`) — د macOS په څېر:
/// درې ګردې تڼۍ چپ لور ته، منځ کې سرلیک، او ټوله کرښه د کش کولو
/// وړ. نو پروګرام په وینډوز کې هم هماغه ساده، عصري بڼه لري.
Future<void> configureWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
  await windowManager.ensureInitialized();
  const opts = WindowOptions(
    size: Size(1440, 900),
    minimumSize: Size(960, 640),
    center: true,
    title: 'د آرشیف چټک مدیر',
    // د وینډوز اصلي بار او د هغې minimize/maximize/close تڼۍ
    // بشپړ لرې کوو.
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
