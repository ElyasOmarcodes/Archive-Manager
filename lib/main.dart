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
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
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
