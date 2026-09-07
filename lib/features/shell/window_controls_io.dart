/// **د کړکۍ کنټرول — ډیسکټاپ.**
///
/// د سیسټم خپل ټایټل بار پټ دی (`TitleBarStyle.hidden`)، نو دا
/// فعالیتونه هغه څه ورکوي چې هغه یې کاوه: ښکته کول، لوی/کوچنی
/// کول، تړل، او د بار په کش کولو سره ښورول.
library;

import 'dart:io';

import 'package:window_manager/window_manager.dart';

bool get hasCustomTitleBar =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> windowMinimize() => windowManager.minimize();

Future<void> windowToggleMaximize() async {
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

Future<void> windowClose() => windowManager.close();

Future<bool> windowIsMaximized() => windowManager.isMaximized();

Future<void> windowStartDragging() => windowManager.startDragging();

Future<void> windowHandleDoubleTap() => windowToggleMaximize();
