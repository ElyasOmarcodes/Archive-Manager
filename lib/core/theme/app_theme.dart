import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';

/// د پروګرام تیمونه — سپین او تیاره، دواړه د وزیر متن فونټ سره.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Vazirmatn';

  // ── سپین تیم ───────────────────────────────────────────
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppTokens.brand,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE4E9FF),
    onPrimaryContainer: Color(0xFF14235C),
    secondary: AppTokens.teal,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD3F5F0),
    onSecondaryContainer: Color(0xFF06403A),
    tertiary: AppTokens.violet,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFEDE2FF),
    onTertiaryContainer: Color(0xFF2E1065),
    error: Color(0xFFD92D3A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFE3E5),
    onErrorContainer: Color(0xFF5C0810),
    surface: Color(0xFFFBFCFE),
    onSurface: Color(0xFF15181F),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF7F9FC),
    surfaceContainer: Color(0xFFF1F4F9),
    surfaceContainerHigh: Color(0xFFEAEEF5),
    surfaceContainerHighest: Color(0xFFE3E8F0),
    onSurfaceVariant: Color(0xFF5A6270),
    outline: Color(0xFFC9D0DB),
    outlineVariant: Color(0xFFE3E8F0),
    shadow: Color(0x1A0B1220),
    scrim: Color(0x800B1220),
    inverseSurface: Color(0xFF1B1F27),
    onInverseSurface: Color(0xFFF1F4F9),
    inversePrimary: Color(0xFFA9BAFF),
  );

  // ── تیاره تیم ──────────────────────────────────────────
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8AA0FF),
    onPrimary: Color(0xFF0B1441),
    primaryContainer: Color(0xFF2A3878),
    onPrimaryContainer: Color(0xFFDDE3FF),
    secondary: Color(0xFF4ED8C6),
    onSecondary: Color(0xFF00201C),
    secondaryContainer: Color(0xFF0C574E),
    onSecondaryContainer: Color(0xFFCDF4EE),
    tertiary: Color(0xFFC2A0FF),
    onTertiary: Color(0xFF23104F),
    tertiaryContainer: Color(0xFF4A2C86),
    onTertiaryContainer: Color(0xFFEDE0FF),
    error: Color(0xFFFF8A8A),
    onError: Color(0xFF470008),
    errorContainer: Color(0xFF7A1420),
    onErrorContainer: Color(0xFFFFDADA),
    surface: Color(0xFF0E1116),
    onSurface: Color(0xFFE6EAF2),
    surfaceContainerLowest: Color(0xFF090B0F),
    surfaceContainerLow: Color(0xFF12161C),
    surfaceContainer: Color(0xFF171C24),
    surfaceContainerHigh: Color(0xFF1E242E),
    surfaceContainerHighest: Color(0xFF262D39),
    onSurfaceVariant: Color(0xFFA7B0C0),
    outline: Color(0xFF39414F),
    outlineVariant: Color(0xFF262D39),
    shadow: Color(0xFF000000),
    scrim: Color(0xCC000000),
    inverseSurface: Color(0xFFE6EAF2),
    onInverseSurface: Color(0xFF171C24),
    inversePrimary: AppTokens.brand,
  );

  static ThemeData light() => _build(_lightScheme);
  static ThemeData dark() => _build(_darkScheme);

  static ThemeData _build(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    final base = ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      canvasColor: cs.surface,
      dividerColor: cs.outlineVariant,
      textTheme: _textTheme(base.textTheme, cs),

      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.windows: _FadeThroughTransitions(),
        TargetPlatform.linux: _FadeThroughTransitions(),
        TargetPlatform.macOS: _FadeThroughTransitions(),
        TargetPlatform.android: _FadeThroughTransitions(),
      }),

      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.brLg,
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.brXl,
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainer,
        isDense: true,
        // عمودي پیډنګ داسې چې فیلډ دقیقاً `controlH` جګ شي.
        constraints: const BoxConstraints(minHeight: AppTokens.controlH),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s12, vertical: 9),
        hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: AppTokens.brMd,
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.brMd,
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.brMd,
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppTokens.brMd,
          borderSide: BorderSide(color: cs.error),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
          minimumSize: const Size(0, AppTokens.controlH),
          // له دې پرته Material د لمس لپاره ۴۸px ورزیاتوي، نو تڼۍ
          // تر خپلو ګاونډیو لوړې کیږي.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: AppTokens.brMd),
          textStyle: const TextStyle(
              fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
          minimumSize: const Size(0, AppTokens.controlH),
          // له دې پرته Material د لمس لپاره ۴۸px ورزیاتوي، نو تڼۍ
          // تر خپلو ګاونډیو لوړې کیږي.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: AppTokens.brMd),
          side: BorderSide(color: cs.outline),
          textStyle: const TextStyle(
              fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12),
          minimumSize: const Size(0, AppTokens.controlH),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: AppTokens.brSm),
          textStyle: const TextStyle(
              fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainer,
        selectedColor: cs.primaryContainer,
        side: BorderSide(color: cs.outlineVariant),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(999))),
        labelStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 12.5, color: cs.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: AppTokens.brSm,
        ),
        textStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 12, color: cs.onInverseSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),

      // **د سکرول بار.**
      //
      // کاروونکي راپور کړه چې موس یې پرې اثر نه لري. دوه علتونه وو:
      // ۱) `interactive` نه و ټاکل شوی، نو کش کول یې فعال نه و؛
      // ۲) بار پخپله ډېر نری (۷px) او یوازې د سکرول پر مهال ښکاره
      //    و — نو د نیولو لپاره هدف نه و.
      //
      // اوس تل ښکاري، پنډ دی، او د کش کولو وړ.
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        interactive: true,
        thumbColor: WidgetStateProperty.resolveWith((st) {
          if (st.contains(WidgetState.dragged)) return cs.primary;
          if (st.contains(WidgetState.hovered)) {
            return cs.outline.withValues(alpha: 0.95);
          }
          return cs.outline.withValues(alpha: 0.55);
        }),
        trackColor: WidgetStateProperty.resolveWith((st) =>
            st.contains(WidgetState.hovered)
                ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
                : Colors.transparent),
        trackVisibility: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.hovered)),
        radius: const Radius.circular(999),
        thickness: const WidgetStatePropertyAll(9),
        // د نیولو لپاره لږ‌تر‌لږه اوږدوالی — ګنې په اوږدو لیستونو کې
        // ټوپۍ دومره وړه شي چې ونه نیول شي.
        minThumbLength: 44,
        crossAxisMargin: 2,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.surfaceContainerHighest,
        thumbColor: cs.primary,
        trackHeight: 4,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 13, color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: AppTokens.brMd),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.brMd,
          side: BorderSide(color: cs.outlineVariant),
        ),
        textStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 13, color: cs.onSurface),
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        space: 1,
        thickness: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
        linearMinHeight: 6,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme t, ColorScheme cs) {
    TextStyle s(double size, FontWeight w, {double h = 1.5, Color? c}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          height: h,
          color: c ?? cs.onSurface,
        );
    return t.copyWith(
      displayLarge: s(40, FontWeight.w800, h: 1.25),
      displayMedium: s(34, FontWeight.w800, h: 1.28),
      displaySmall: s(28, FontWeight.w700, h: 1.3),
      headlineLarge: s(26, FontWeight.w700, h: 1.32),
      headlineMedium: s(22, FontWeight.w700, h: 1.35),
      headlineSmall: s(19, FontWeight.w700, h: 1.4),
      titleLarge: s(17, FontWeight.w700, h: 1.45),
      titleMedium: s(15, FontWeight.w600, h: 1.5),
      titleSmall: s(13.5, FontWeight.w600, h: 1.5),
      bodyLarge: s(15, FontWeight.w400, h: 1.7),
      bodyMedium: s(13.5, FontWeight.w400, h: 1.7),
      bodySmall: s(12, FontWeight.w400, h: 1.6, c: cs.onSurfaceVariant),
      labelLarge: s(13.5, FontWeight.w600, h: 1.4),
      labelMedium: s(12, FontWeight.w600, h: 1.4),
      labelSmall: s(11, FontWeight.w500, h: 1.4, c: cs.onSurfaceVariant),
    );
  }
}

/// نرم fade-through انتقال — د ټولو پاڼو ترمنځ یو شان حرکت.
class _FadeThroughTransitions extends PageTransitionsBuilder {
  const _FadeThroughTransitions();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondary, Widget child) {
    final fade = CurvedAnimation(parent: animation, curve: AppTokens.ease);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.018), end: Offset.zero)
            .animate(fade),
        child: child,
      ),
    );
  }
}
