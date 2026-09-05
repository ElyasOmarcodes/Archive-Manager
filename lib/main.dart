import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class ArchiveApp extends StatelessWidget {
  const ArchiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'د آرشیف چټک مدیر',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: s.themeMode,
      // ټول پروګرام ښي‌څخه‌کیڼ (RTL) دی — پښتو ژبه.
      locale: const Locale('ps', 'AF'),
      supportedLocales: const [Locale('ps', 'AF'), Locale('fa'), Locale('en')],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const BootGate(),
    );
  }
}
