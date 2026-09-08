import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/cupertino_ps.dart';
import 'core/theme/app_theme.dart';
import 'data/platform/backend.dart';
import 'data/platform/demo_backend.dart';
import 'data/repository/app_state.dart';
import 'features/onboarding/boot_gate.dart';
import 'features/shell/title_bar.dart';

// د ریښتیني بک‌اینډ شرطي واردول — په ویب کې `dart:io` نه شته،
// نو هلته یوازې د نندارې نسخه جوړیږي.
import 'platform_backend.dart'
    if (dart.library.io) 'platform_backend_io.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // د ریلیز په بڼه کې فلټر یو تش خړ چوکاټ ښیي چې هیڅ نه وایي.
  // پرځای یې یو لوستل کېدونکی کارت ښیو — نو که کوم ځای ماته شي،
  // کاروونکی (او مونږ) پوهیږو چې څه پېښ شول، او پاتې پروګرام کار کوي.
  ErrorWidget.builder = (details) {
    // په کنسول کې یې هم ولیکه — نو د ستونزې موندل اسانه وي.
    debugPrint('ARCHIVE-ERROR: ${details.exception}\n'
        'library=${details.library} context=${details.context}\n'
        '${details.stack}');
    return _ErrorCard(details: details);
  };

  await configureWindow();

  final ArchiveBackend backend = kIsWeb ? DemoBackend() : createBackend();
  final state = AppState(backend);
  unawaitedBoot(state);

  runApp(ChangeNotifierProvider.value(value: state, child: const ArchiveApp()));
}

void unawaitedBoot(AppState s) {
  // پیل په پس‌منظر کې — UI سمدلاسه ښکاري او د بارېدو حالت ښیي.
  s.boot();
}

/// د یوه ماتې شوي ویجټ پر ځای — نه یو تش خړ چوکاټ.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5484D)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'دې برخې کې ستونزه راغله',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A1420),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                '\${details.exception}',
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  height: 1.5,
                  color: Color(0xFF7A1420),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArchiveApp extends StatelessWidget {
  const ArchiveApp({super.key, this.homeOverride});

  /// یوازې د ازموینو لپاره — نو ازموینې د ریښتیني MaterialApp له لارې
  /// چلیږي (ژبه، ډېلیګیټونه، تیم) نه د یوه جوړ شوي بدیل له لارې.
  final Widget? homeOverride;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      // **ولې خپل `ScrollBehavior`؟**
      //
      // د Flutter ډیفالټ چلند یوازې پر ډیسکټاپ سکرول بار ورزیاتوي.
      // پر ویب او هغه ځایونو کې چې لمس هم شته، بار بیخي نه ښکاري —
      // نو د موس په واسطه کش کول ناشوني وي. دلته یې هر ځای فعالوو،
      // او لمس/سټایلس/ټریک‌پیډ ته هم د کش کولو اجازه ورکوو.
      scrollBehavior: const _AppScrollBehavior(),
      title: 'د آرشیف چټک مدیر',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: s.themeMode,
      // ټول پروګرام ښي‌څخه‌کیڼ (RTL) دی — پښتو ژبه.
      //
      // **دا ډېر مهم دي:** پرته له دې ډېلیګیټونو، فلټر د پښتو ژبې لپاره
      // `MaterialLocalizations` نه مومي او **هر متن ساحه (TextField)
      // ماتیږي**. پښتو (`ps`) په flutter_localizations کې بشپړ ملاتړ لري.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        // پښتو په Cupertino کې نشته — نو فارسي ورته بدیل کوو.
        // (باید تر GlobalCupertinoLocalizations دمخه راشي)
        PashtoCupertinoLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('ps'),
      supportedLocales: const [Locale('ps'), Locale('fa'), Locale('en')],
      // **ټایټل بار د ټول پروګرام پر سر.**
      //
      // دلته یې ږدو، نه د shell دننه — نو د پیل پاڼو، د مسیر
      // ټاکلو، او د ورکې لارې پاڼې پر سر هم وي. ډایلوګونه یې
      // پوښي، ځکه هغه د `Navigator` پورته پوړ کې راځي.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            const AppTitleBar(),
            Expanded(
              child: _UiScale(child: child ?? const SizedBox.shrink()),
            ),
          ],
        ),
      ),
      home: homeOverride ?? const BootGate(),
    );
  }
}

/// د سکرول چلند — هر ځای کش‌کېدونکی بار.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  /// **دلته بار نه جوړوو.**
  ///
  /// د Flutter ډیفالټ چلند هرې سکرول ساحې ته بار ورکوي او
  /// `PrimaryScrollController` ورسره تړي — خو هغه یو دی، ټولو ته
  /// ګډ. نو په یوه پاڼه کې دوه لیستونه استثنا اچوي.
  ///
  /// پر ځای یې هره اوږده ساحه په `ScrollArea` کې تړل شوې، چې خپل
  /// کنټرولر لري. دا ډېر روښانه دی: بار هلته وي چې پکار وي.
  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

/// **د پروګرام د اندازې پوښ.**
///
/// کاروونکي وغوښتل چې د پروګرام هر څه وړوکي کړي، نو په پرده کې
/// زیات شیان ځای ونیسي — «لکه چې پر لوی سکرین یې ګورې».
///
/// **څنګه؟** پروګرام ته یوه **لویه** منطقي پرده ورکوو (`size /
/// scale`)، بیا رسم شوې پایله بېرته وړوکې کوو. نو ټول جوړښت —
/// متن، ایکنونه، فاصلې، کارتونه — یو شان وړوکي کیږي او نسبتونه
/// یې نه ماتیږي.
///
/// یوازې د متن کچه (`textScaler`) بدلول کافي نه دي: هغه فاصلې او
/// ایکنونه نه بدلوي، نو جوړښت ګډوډیږي.
class _UiScale extends StatelessWidget {
  const _UiScale({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = context.select<AppState, double>((s) => s.settings.uiScale);
    if ((scale - 1.0).abs() < 0.001) return child;

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / scale;
      final h = c.maxHeight / scale;
      final mq = MediaQuery.of(context);

      // **د ترتیب دوه ټکي — دواړه یې ریښتیني باګونه وو:**
      //
      // ۱) `SizedBox` دلته نه کاریږي: هغه خپلې اندازې د راغلو
      //    قیدونو له مخې راتنګوي، نو لویه منطقي پرده بېرته وړه
      //    کیږي او تر `Transform` روسته یوه **توره خلا** پاتې
      //    کیږي. (کاروونکي پر ۹۰٪ کچه همدا ولیده.)
      //
      // ۲) `OverflowBox` باید **د `Transform` پر سر** وي، نه
      //    لاندې. که لاندې وي، د `Transform` خپله اندازه د کړکۍ
      //    هومره (۱۴۰۰×۹۰۰) پاتې کیږي، خو کلیک چې د معکوس تحویل
      //    روسته تر ۱۷۵۰ پورې رسیږي، له هغې اندازې بهر لوېږي او
      //    **بې‌ځوابه** پاتې کیږي — یعنې د پردې چپه او لاندې
      //    برخه ټوله مړه وي. کاروونکي همدا ولیده: پر کوچنۍ کچه
      //    د پریویو «ایډیټ» او «براوز» تڼۍ، او د ټوسټ «پرانیزه»
      //    — هیڅ یې نه کلیکېدل.
      //
      // اوس `OverflowBox` پخپله د کړکۍ په اندازه ده (نو د
      // `Column` لپاره سمه ده)، خو اولاد ته یې پراخ قیدونه
      // ورکوي — نو د `Transform` اندازه ۱۷۵۰×۱۱۲۵ وي او هر کلیک
      // خپل ځای مومي.
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topRight, // RTL — له ښي څنډې پیل
          minWidth: w,
          maxWidth: w,
          minHeight: h,
          maxHeight: h,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topRight,
            child: MediaQuery(
              // منطقي پرده هم باید نوې اندازه وپېژني، ګنې د
              // ریسپانسیف پرېکړې (لکه د سایډبار راټولېدل) ناسمې شي.
              data: mq.copyWith(size: Size(w, h)),
              child: child,
            ),
          ),
        ),
      );
    });
  }
}
