/// **د کړکۍ کنټرول — د ویب لپاره تشه بڼه.**
///
/// ویب کړکۍ نه لري، نو دلته هر څه بې‌اثره دي. د ډیسکټاپ بڼه یې په
/// `window_controls_io.dart` کې ده. شرطي واردول (conditional
/// import) دواړه سره تړي، نو د ویب جوړونه `window_manager` ته
/// اړتیا نه لري.
library;

/// آیا پروګرام خپل ټایټل بار رسموي؟ (ویب کې نه)
bool get hasCustomTitleBar => false;

Future<void> windowMinimize() async {}
Future<void> windowToggleMaximize() async {}
Future<void> windowClose() async {}
Future<bool> windowIsMaximized() async => false;

/// د بار له کش کولو سره کړکۍ ښوروي.
Future<void> windowStartDragging() async {}

/// دوه‌ځلې کلیک — لوی/کوچنی کول.
Future<void> windowHandleDoubleTap() async {}
