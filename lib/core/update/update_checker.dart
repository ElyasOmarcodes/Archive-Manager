import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// **د نوې نسخې کتونکی.**
///
/// کاروونکي وویل: «پروګرام کې ټول هغه شرایط لحاظ کړه چې راتلونکی
/// کې مونږ وکړی شو نوي اپډیټونه … په سالمه او آمن توګه نصب کړو».
///
/// ## څنګه؟
///
/// د GitHub د **وروستي ریلیز** پېژندنه لوستل کیږي (نه هره ورځ،
/// یوازې د پیل پر مهال او بیا هرې ۶ ساعتونو). که هلته نوې نسخه
/// وي، پروګرام یوازې **خبر** ورکوي — او د ډانلوډ پاڼه پرانیزي.
///
/// **ولې پخپله نه ډانلوډوي او نه یې چلوي؟** ځکه هغه د یوه
/// «چوپ چلوونکي» (silent updater) پوړ غواړي: که هغه لار له کوم
/// ځایه ناسم فایل راوړي، پروګرام به پخپله یو ویروس چلوي. اوس
/// کاروونکی پخپله د GitHub له رسمي پاڼې ډانلوډوي، او نصب کوونکی
/// (Inno Setup) یې پر ځای اپډیټوي — نو نه ډیټا ورکیږي، نه
/// تنظیمات.
class UpdateChecker extends ChangeNotifier {
  UpdateChecker({
    required this.currentVersion,
    http.Client? client,
    this.apiUrl = kLatestReleaseUrl,
    this.every = const Duration(hours: 6),
  }) : _client = client ?? http.Client();

  static const String kLatestReleaseUrl =
      'https://api.github.com/repos/ElyasOmarcodes/Archive-Manager/'
      'releases/latest';

  /// د دې پروګرام نسخه — لکه `1.0.0`.
  final String currentVersion;
  final String apiUrl;
  final Duration every;
  final http.Client _client;

  /// د موندل شوې نوې نسخې شمېره (که وي).
  String? latest;

  /// د ریلیز پاڼه — کاروونکی همدلته ډانلوډ کوي.
  String? releaseUrl;

  bool checking = false;
  DateTime? lastCheck;

  /// آیا نوې نسخه شته؟
  bool get hasUpdate => latest != null && isNewer(latest!, currentVersion);

  Timer? _timer;

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

  Future<void> check() async {
    if (checking) return;
    checking = true;
    notifyListeners();
    try {
      final r = await _client.get(Uri.parse(apiUrl), headers: const {
        'Accept': 'application/vnd.github+json',
        'Cache-Control': 'no-cache',
      }).timeout(const Duration(seconds: 12));

      lastCheck = DateTime.now();
      if (r.statusCode != 200) return;

      final j = jsonDecode(r.body);
      if (j is! Map) return;
      final tag = '${j['tag_name'] ?? ''}'.trim();
      if (tag.isEmpty) return;

      latest = tag.startsWith('v') ? tag.substring(1) : tag;
      releaseUrl = '${j['html_url'] ?? ''}';
    } catch (_) {
      // د اپډیټ کتنه یو اسانتیا ده — که ناکامه شي، هیڅ نه خرابیږي.
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  /// `1.10.0` تر `1.9.3` نوې ده — نو متن نه، عددونه پرتله کوو.
  @visibleForTesting
  static bool isNewer(String a, String b) {
    List<int> parts(String v) => [
          for (final p in v.split(RegExp(r'[.+-]')).take(3))
            int.tryParse(p) ?? 0,
        ];
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final l = i < x.length ? x[i] : 0;
      final r = i < y.length ? y[i] : 0;
      if (l != r) return l > r;
    }
    return false;
  }
}
