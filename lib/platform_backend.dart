import 'data/platform/backend.dart';
import 'data/platform/demo_backend.dart';

/// ویب: هیڅ ریښتینی فایل سیسټم نشته — د نندارې نسخه.
ArchiveBackend createBackend() => DemoBackend();

/// ویب کې کړکۍ نه تنظیمیږي.
Future<void> configureWindow() async {}
