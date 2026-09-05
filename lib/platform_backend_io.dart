import 'dart:io';

import 'package:flutter/widgets.dart' show Size;

import 'package:window_manager/window_manager.dart';

import 'data/platform/backend.dart';
import 'data/platform/io_backend.dart';

/// ډیسکټاپ: ریښتینی فایل سیسټم + SQLite ایندکس.
ArchiveBackend createBackend() => IoBackend();

/// د کړکۍ لومړني تنظیمات — یوه هوسا اندازه او لږ تر لږه بریدونه.
Future<void> configureWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
  await windowManager.ensureInitialized();
  const opts = WindowOptions(
    size: Size(1440, 900),
    minimumSize: Size(1080, 680),
    center: true,
    title: 'د آرشیف چټک مدیر',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
