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
    this.apiUrl = kControlApiUrl,
    this.every = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  /// هغه فایل چې د پروګرام برخلیک ټاکي (خام لینک).
  static const String kControlUrl =
      'https://raw.githubusercontent.com/ElyasOmarcodes/Ai-Model/'
      'Apps-Expire-Files/HK-Archive-App-Sys.TXT';

  /// **هماغه فایل، خو د GitHub د API له لارې.**
  ///
  /// ولې دواړه؟ وګورئ `_read()`.
  static const String kControlApiUrl =
      'https://api.github.com/repos/ElyasOmarcodes/Ai-Model/contents/'
      'HK-Archive-App-Sys.TXT?ref=Apps-Expire-Files';

  final String url;
  final String apiUrl;
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

  /// د API د ځواب نښه — نو راتلونکې پوښتنه شرطي (conditional) وي.
  String? _etag;

  /// وروستی پېژندل شوی متن — کله چې سرور «بدلون نشته» ووایي.
  String? _lastBody;

  /// یو ځل ګوري. راګرځي: آیا پروګرام خلاص دی؟
  Future<bool> check() async {
    if (checking) return !_locked;
    checking = true;
    notifyListeners();

    try {
      final body = await _read();
      lastCheck = DateTime.now();
      if (body == null) return !_locked; // شبکه/سرور — حالت نه بدلوو

      lastError = null;
      final allowed = body.trim().toLowerCase() == 'true';
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

  /// **د امر لوستل — دوه لارې، ترتیب سره.**
  ///
  /// کاروونکي وویل: «د بلاک کېدو … اجازه یې ناوخته ترلاسه کیږي.
  /// نږدې ۵ دقیقو کې ایله پروګرام امر ترلاسه کړ. غواړم په څو
  /// ثانیو کې لایف امر ترلاسه شي».
  ///
  /// **علت:** خام لینک (`raw.githubusercontent.com`) د
  /// `cache-control: max-age=300` سره راځي — یعنې د CDN او د هرې
  /// منځنۍ پروکسۍ لپاره **پنځه دقیقې** زوړ ځواب هم سم دی.
  ///
  /// **حل:** لومړی د GitHub **API** له لارې پوښتو:
  ///
  /// * هغه CDN نه دی — ځواب یې تل تازه وي
  /// * شرطي پوښتنه کوو (`If-None-Match`): که بدلون نه وي، سرور
  ///   `304` راګرځوي — **بایټ صفر، او د GitHub د حد په حساب کې
  ///   هم نه شمېرل کیږي**، نو هرې ۱۰ ثانیې پوښتل خوندي دي
  /// * که API ونه چلیږي (حد، بندښت، بله تېروتنه)، بیا خام لینک
  ///   کاروو — خو د یوې بېلې پوښتنې (`?t=…`) او `no-cache` سره
  ///
  /// راګرځي: نوی متن، یا `null` که پوښتنه ناکامه شوه.
  Future<String?> _read() async {
    // ── ۱ · API (تازه، شرطي) ──
    try {
      final r = await _client.get(Uri.parse(apiUrl), headers: {
        // «خام متن راکړه، نه JSON»
        'Accept': 'application/vnd.github.raw',
        'Cache-Control': 'no-cache',
        // که مو مخکینۍ نښه ولري، شرطي پوښتنه کوو — نو بې‌بدلونه
        // ځواب `304` وي: بایټ صفر، او د حد په حساب کې نه راځي.
        'If-None-Match': ?_etag,
      }).timeout(const Duration(seconds: 10));

      if (r.statusCode == 304 && _lastBody != null) return _lastBody;
      if (r.statusCode == 200) {
        _etag = r.headers['etag'];
        return _lastBody = r.body;
      }
      // ۴۰۳ = د حد پای، ۴۰۴ = ورک، ۵xx = سرور — لاندې لار وازمویو.
      lastError = 'API HTTP ${r.statusCode}';
    } catch (e) {
      lastError = '$e';
    }

    // ── ۲ · خام لینک (د کیش مخنیوی) ──
    try {
      final u = Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}');
      final r = await _client.get(u, headers: const {
        'Cache-Control': 'no-cache, no-store, max-age=0',
        'Pragma': 'no-cache',
      }).timeout(const Duration(seconds: 12));

      if (r.statusCode == 200) return _lastBody = r.body;
      lastError = 'HTTP ${r.statusCode}';
    } catch (e) {
      lastError = '$e';
    }
    return null;
  }

  Future<void> _apply({required bool locked}) async {
    if (locked == _locked) return;
    _locked = locked;
    lockedAt = locked ? DateTime.now() : null;
    await onChanged(locked, lockedAt);
    notifyListeners();
  }
}
