import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// **د پروګرام د فعالېدو دروازه.**
///
/// کاروونکي وویل:
///
/// > بک ګراند کې پروګرام باید همیشه په ساکت ډول د دې لینک محتوا
/// > وڅاري. که چیرته دا محتوا له `true` څخه `false` ته بدله شوه، نو
/// > سمدلاسه باید پروګرام د اکسپایر پاڼې ته لاړ شي. … ددې لپاره
/// > ممکن مونږ یوه ورځ وغواړو چې د پروګرام ټول ورژنونه بند کړو، نو
/// > فقط به `false` ولیکو هلته او بس!
///
/// ## څنګه کار کوي
///
/// * هرې **۱۰ ثانیې** یو ځل فایل لوستل کیږي — نو امر په څو ثانیو
///   کې رسیږي.
/// * د کیش مخنیوی: هر ځل یوه بېله پوښتنه (`?t=…`) او
///   `Cache-Control: no-cache` — ګنې د GitHub CDN به زوړ ځواب
///   راکاوه.
/// * محتوا **دقیقاً `true`** یعنې خلاص؛ **هر بل څه** (`false`،
///   تشه، بل متن) یعنې تړلی.
/// * **انټرنیټ نشتوالی هیڅکله نه تړي.** آرشیف ډېری وخت افلاین
///   کاریږي؛ نو د شبکې تېروتنه اوسنی حالت نه بدلوي.
/// * **لاک تلپاتې دی.** کله چې یو ځل تړل شو، په تنظیماتو کې ثبتیږي
///   — نو د پروګرام بیا پرانیستل یې نه خلاصوي. یوازې هغه وخت
///   خلاصیږي چې سرور بیا `true` ووایي (پخپله، یا د «بیا هڅه»
///   تڼۍ له لارې).
class LicenseGate extends ChangeNotifier {
  LicenseGate({
    required this.onChanged,
    http.Client? client,
    this.url = kControlUrl,
    this.every = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  /// هغه فایل چې د پروګرام برخلیک ټاکي.
  static const String kControlUrl =
      'https://raw.githubusercontent.com/ElyasOmarcodes/Ai-Model/'
      'Apps-Expire-Files/HK-Archive-App-Sys.TXT';

  final String url;
  final Duration every;
  final http.Client _client;

  /// کله چې حالت بدل شي، دا فعالیت یې خوندي کوي (تنظیماتو ته).
  final Future<void> Function(bool locked, DateTime? at) onChanged;

  bool _locked = false;
  bool get locked => _locked;

  /// کله تړل شو؟ (د اکسپایر پاڼه یې ښیي)
  DateTime? lockedAt;

  /// وروستی ځل کله وکتل شو؟
  DateTime? lastCheck;

  /// وروستۍ د شبکې تېروتنه — یوازې د ښودلو لپاره.
  String? lastError;

  /// آیا همدا اوس پوښتنه روانه ده؟ (د «بیا هڅه» تڼۍ لپاره)
  bool checking = false;

  Timer? _timer;

  /// **آیا دا یوه ازموینه ده؟**
  ///
  /// د ازموینې چاپېریال هر تلپاتې ټایمر «ناتمام کار» ګڼي او
  /// ازموینه ماتوي — نو هلته څارنه نه پیلیږي. (څارنه پخپله د
  /// `license_test.dart` په لاسي ډول ازمویل کیږي.)
  static bool get isTestEnvironment {
    try {
      return WidgetsBinding.instance.runtimeType
          .toString()
          .contains('AutomatedTest');
    } catch (_) {
      // بایندنګ لا جوړ شوی نه دی — یعنې دا یو ساده unit test دی.
      return true;
    }
  }

  /// د ساتل شوي حالت څخه پیل — پرته له شبکې.
  void restore({required bool locked, DateTime? at}) {
    _locked = locked;
    lockedAt = at;
  }

  /// څارنه پیلوي: سمدلاسه یو ځل، بیا هرې `every` یوه پوښتنه.
  void start() {
    _timer?.cancel();
    unawaited(check());
    _timer = Timer.periodic(every, (_) => unawaited(check()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }

  /// یو ځل ګوري. راګرځي: آیا پروګرام خلاص دی؟
  Future<bool> check() async {
    if (checking) return !_locked;
    checking = true;
    notifyListeners();

    try {
      final u = Uri.parse(
          '$url?t=${DateTime.now().millisecondsSinceEpoch}');
      final r = await _client.get(u, headers: const {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      }).timeout(const Duration(seconds: 12));

      lastCheck = DateTime.now();

      if (r.statusCode != 200) {
        // سرور ځواب ورکړ خو نه یې موند — دا د شبکې ستونزه ګڼو، نه
        // د تړلو امر. ګنې یوه ورکه پوښۍ به ټول پروګرامونه ودروي.
        lastError = 'HTTP ${r.statusCode}';
        return !_locked;
      }

      lastError = null;
      final allowed = r.body.trim().toLowerCase() == 'true';
      await _apply(locked: !allowed);
      return allowed;
    } catch (e) {
      // انټرنیټ نشته، یا وخت تېر شو — حالت نه بدلوو.
      lastError = '$e';
      return !_locked;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  Future<void> _apply({required bool locked}) async {
    if (locked == _locked) return;
    _locked = locked;
    lockedAt = locked ? DateTime.now() : null;
    await onChanged(locked, lockedAt);
    notifyListeners();
  }
}
