import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// **د پښتو لپاره د Cupertino ژباړو بدیل.**
///
/// `flutter_localizations` پښتو (`ps`) لپاره د **Material** او **Widgets**
/// بشپړې ژباړې لري، خو د **Cupertino** ژباړې یې نه لري. پرته له دې،
/// فلټر خبرداری ورکوي او هغه لږ شمېر Cupertino ویجټونه (لکه د متن د
/// ټاکنې مینو په ځینو پلیټ‌فارمونو کې) ژباړې نه مومي.
///
/// نو د پښتو لپاره فارسي (`fa`) ژباړې کاروو — چې د پښتو سره ډېره نږدې
/// او ښي‌څخه‌کیڼ ده — نه دا چې کاروونکی انګلیسي یا تشه ووینې.
class PashtoCupertinoLocalizations {
  PashtoCupertinoLocalizations._();

  static const LocalizationsDelegate<CupertinoLocalizations> delegate =
      _Delegate();
}

class _Delegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _Delegate();

  /// یوازې هغه ژبې چې `GlobalCupertinoLocalizations` یې نه پېژني.
  static const _fallbackFor = {'ps'};

  @override
  bool isSupported(Locale locale) =>
      _fallbackFor.contains(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('fa'));

  @override
  bool shouldReload(_Delegate old) => false;
}
