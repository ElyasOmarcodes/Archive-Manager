import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../data/repository/app_state.dart';
import '../../widgets/common.dart';

/// د لومړي ځل معرفي + د آرشیف د مسیر ټاکنه.
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final _pager = PageController();
  int _index = 0;

  static const _slides = [
    (
      Icons.bolt_rounded,
      'په څو ثانیو کې ومومئ',
      'هغه څه چې پخوا یې موندلو ته ساعتونه — آن دوې ورځې — وخت نیوه، '
          'اوس یې په څو ثانیو کې پیدا کوئ. مونږ د لټون پر مهال ډرایو نه '
          'ګورو، بلکه یو کوچنی چټک ایندکس لټوو.',
      [AppTokens.brand, AppTokens.brandAlt],
    ),
    (
      Icons.sell_rounded,
      'د نړیوال معیار میټاډیټا',
      'کیورډونه، د ستورو درجه‌بندي، رنګ ټګونه، شخصیتونه او کټګورۍ — '
          'دقیقاً هغه څه چې آډوبي بریج او نور مسلکي سیستمونه یې کاروي، '
          'خو ستاسو د آرشیف لپاره جوړ شوي.',
      [AppTokens.teal, AppTokens.green],
    ),
    (
      Icons.event_rounded,
      'درې تقویمونه، یو ځل ثبت',
      'یو ځل تاریخ ولیکئ — مونږ یې په هجري لمریز، هجري قمري او میلادي '
          'دریو واړو کې ساتو. نو د هر تقویم له مخې پلټنه یو شان چټکه ده.',
      [AppTokens.amber, AppTokens.orange],
    ),
    (
      Icons.folder_special_rounded,
      'هر څه ستاسو پر هارډ پاتې کیږي',
      'هره پیښه خپل فولډر، خپل `index.html` او خپل `metadata.json` لري. '
          'که سافټویر هم ورک شي، ستاسو ډیټا بشپړه او لوستل کېدونکې پاتې ده.',
      [AppTokens.rose, AppTokens.violet],
    ),
  ];

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const _Backdrop(),
          Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pager,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final s in _slides)
                      _Slide(
                          icon: s.$1,
                          title: s.$2,
                          body: s.$3,
                          colors: s.$4),
                    const _PickRootSlide(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTokens.s40, 0, AppTokens.s40, AppTokens.s32),
                child: Row(
                  children: [
                    if (!_isLast)
                      TextButton(
                        onPressed: () => _pager.animateToPage(_slides.length,
                            duration: AppTokens.slow, curve: AppTokens.ease),
                        child: const Text('تېرول'),
                      ),
                    const Spacer(),
                    // نقطې
                    for (var i = 0; i <= _slides.length; i++)
                      AnimatedContainer(
                        duration: AppTokens.base,
                        curve: AppTokens.ease,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index ? cs.primary : cs.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    const Spacer(),
                    if (!_isLast)
                      FilledButton.icon(
                        onPressed: () => _pager.nextPage(
                            duration: AppTokens.base, curve: AppTokens.ease),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('بل'),
                      )
                    else
                      const SizedBox(width: 96),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// نرم رنګین پس‌منظر.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -140,
              right: -100,
              child: _blob(AppTokens.brand.withValues(alpha: dark ? .17 : .11), 420),
            ),
            Positioned(
              bottom: -180,
              left: -120,
              child: _blob(AppTokens.teal.withValues(alpha: dark ? .14 : .10), 460),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
        ),
      );
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeSlideIn(
                offset: const Offset(0, 0.08),
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: colors,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: colors.first.withValues(alpha: 0.38),
                        blurRadius: 34,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: AppTokens.s40),
              FadeSlideIn(
                delay: const Duration(milliseconds: 90),
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: t.textTheme.displaySmall),
              ),
              const SizedBox(height: AppTokens.s16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 170),
                child: Text(body,
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodyLarge
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// وروستۍ پاڼه — د آرشیف مسیر ټاکل.
class _PickRootSlide extends StatefulWidget {
  const _PickRootSlide();

  @override
  State<_PickRootSlide> createState() => _PickRootSlideState();
}

class _PickRootSlideState extends State<_PickRootSlide> {
  final _manual = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final s = context.read<AppState>();
    final picked = await s.backend.pickDirectory();
    if (picked != null) {
      _manual.text = picked;
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirm() async {
    final path = _manual.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'لومړی د آرشیف مسیر وټاکئ');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = context.read<AppState>();
    if (!await s.backend.pathExists(path)) {
      setState(() {
        _busy = false;
        _error = 'دا مسیر ونه موندل شو — بیا یې وګورئ';
      });
      return;
    }
    await s.setArchiveRoot(path);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.s40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeSlideIn(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppTokens.brand, AppTokens.brandAlt],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTokens.brand.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.drive_folder_upload_rounded,
                      size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: AppTokens.s32),
              Text('ستاسو آرشیف چیرته دی؟',
                  textAlign: TextAlign.center,
                  style: t.textTheme.headlineMedium),
              const SizedBox(height: AppTokens.s8),
              Text(
                'هغه فولډر، ډرایو یا بهرنی هارډ وټاکئ چې ستاسو ټول '
                'آرشیف پکې پروت دی. وروسته یې د تنظیماتو له لارې هم '
                'بدلولی شئ.',
                textAlign: TextAlign.center,
                style: t.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppTokens.s32),
              AppCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _manual,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        hintText: r'E:\Arvitch',
                        hintTextDirection: TextDirection.ltr,
                        prefixIcon:
                            const Icon(Icons.folder_rounded, size: 19),
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: AppTokens.s16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _browse,
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: const Text('فولډر وپلټه'),
                          ),
                        ),
                        const SizedBox(width: AppTokens.s12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _confirm,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(_busy ? 'سکن روان دی…' : 'پیل وکړه'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.s20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'ستاسو فایلونه نه لېږدول کیږي او نه بدلیږي — یوازې '
                      'لوستل کیږي.',
                      style: t.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
