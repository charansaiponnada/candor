/// Candor App Theme — OLED Black with iOS-style Glassmorphism
///
/// A custom Material 3 theme built around true black (#000000) backgrounds,
/// white text, and frosted glass surfaces with blur effects.
library;

import 'package:flutter/material.dart';

/// The single source of truth for Candor's color palette.
class CandorColors {
  // True OLED black — saves battery on OLED, maximum contrast
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Glass surface tints — subtle white overlays for depth
  static const Color glassSurface1 = Color(0x0DFFFFFF); // 5%  — backgrounds
  static const Color glassSurface2 = Color(0x14FFFFFF); // 8%  — cards, sheets
  static const Color glassSurface3 = Color(0x1FFFFFFF); // 12% — elevated surfaces
  static const Color glassSurface4 = Color(0x2FFFFFFF); // 18% — pressed/focused

  // Glass borders — barely visible white lines
  static const Color glassBorder1 = Color(0x14FFFFFF); // 8%
  static const Color glassBorder2 = Color(0x1FFFFFFF); // 12%
  static const Color glassBorder3 = Color(0x33FFFFFF); // 20%

  // Text colors
  static const Color textPrimary = white;
  static const Color textSecondary = Color(0xB3FFFFFF); // 70%
  static const Color textTertiary = Color(0x80FFFFFF);  // 50%
  static const Color textDisabled = Color(0x4DFFFFFF);  // 30%

  // Accent — a refined cyan/teal that pops on black, feels modern & technical
  static const Color accent = Color(0xFF00E5A0);
  static const Color accentContainer = Color(0x1A00E5A0); // 10% accent tint
  static const Color onAccent = black;

  // Semantic colors (adjusted for black background)
  static const Color error = Color(0xFFFF6B6B);
  static const Color errorContainer = Color(0x33FF0000);
  static const Color onError = white;

  static const Color warning = Color(0xFFFFD93D);
  static const Color warningContainer = Color(0x33FFF500);
  static const Color onWarning = black;

  static const Color success = Color(0xFF00E5A0);
  static const Color successContainer = Color(0x1A00E5A0);
  static const Color onSuccess = black;

  // Tier colors (for model tier pills)
  static const Color tier1 = Color(0xFF00E5A0); // Green-cyan
  static const Color tier2 = Color(0xFF7C4DFF); // Deep purple
  static const Color tier1Constrained = Color(0xFFFF6B6B); // Red

  // Shadow for glass elevation
  static const Color glassShadow = Color(0x4D000000); // 30% black
  static const Color glassShadowStrong = Color(0x66000000); // 40% black
}

/// Border radius tokens for consistent rounding
class CandorRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double pill = 999;
}

/// Blur tokens for glassmorphism
class CandorBlur {
  static const double subtle = 10;
  static const double normal = 20;
  static const double strong = 30;
  static const double intense = 40;
}

/// Elevation shadows for glass layers
class CandorElevation {
  static List<BoxShadow> level1 = [
    BoxShadow(
      color: CandorColors.glassShadow,
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> level2 = [
    BoxShadow(
      color: CandorColors.glassShadow,
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: CandorColors.glassShadowStrong,
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  static List<BoxShadow> level3 = [
    BoxShadow(
      color: CandorColors.glassShadow,
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: CandorColors.glassShadowStrong,
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> level4 = [
    BoxShadow(
      color: CandorColors.glassShadow,
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: CandorColors.glassShadowStrong,
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Builds the complete Material 3 [ThemeData] for Candor.
///
/// Both light and dark mode resolve to the same OLED-black glassmorphism theme.
/// The [brightness] parameter is kept for API compatibility but ignored.
ThemeData buildCandorTheme({Brightness brightness = Brightness.dark}) {
  final colorScheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: CandorColors.accent,
    onPrimary: CandorColors.onAccent,
    primaryContainer: CandorColors.accentContainer,
    onPrimaryContainer: CandorColors.textPrimary,
    secondary: CandorColors.tier2,
    onSecondary: CandorColors.white,
    secondaryContainer: CandorColors.glassSurface2,
    onSecondaryContainer: CandorColors.textPrimary,
    tertiary: CandorColors.tier1,
    onTertiary: CandorColors.white,
    tertiaryContainer: CandorColors.glassSurface2,
    onTertiaryContainer: CandorColors.textPrimary,
    error: CandorColors.error,
    onError: CandorColors.onError,
    errorContainer: CandorColors.errorContainer,
    onErrorContainer: CandorColors.textPrimary,
    surface: CandorColors.black,
    onSurface: CandorColors.textPrimary,
    surfaceContainer: CandorColors.glassSurface1,
    surfaceContainerHigh: CandorColors.glassSurface2,
    surfaceContainerHighest: CandorColors.glassSurface3,
    onSurfaceVariant: CandorColors.textSecondary,
    outline: CandorColors.glassBorder2,
    outlineVariant: CandorColors.glassBorder1,
    shadow: CandorColors.glassShadow,
    scrim: CandorColors.glassShadowStrong,
    inverseSurface: CandorColors.white,
    onInverseSurface: CandorColors.black,
    inversePrimary: CandorColors.accent,
  );

  final textTheme = Typography.blackMountainView.apply(
    bodyColor: CandorColors.textPrimary,
    displayColor: CandorColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: CandorColors.black,

    // ── App Bar ──
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: CandorColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: CandorColors.textPrimary),
      actionsIconTheme: const IconThemeData(color: CandorColors.textPrimary),
    ),

    // ── Cards ──
    cardTheme: CardThemeData(
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CandorRadius.lg),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Buttons ──
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CandorColors.accent,
        foregroundColor: CandorColors.onAccent,
        disabledBackgroundColor: CandorColors.glassSurface2,
        disabledForegroundColor: CandorColors.textDisabled,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CandorRadius.pill),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        minimumSize: const Size(88, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CandorColors.textPrimary,
        disabledForegroundColor: CandorColors.textDisabled,
        side: BorderSide(color: CandorColors.glassBorder2, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CandorRadius.pill),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        minimumSize: const Size(88, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CandorColors.accent,
        disabledForegroundColor: CandorColors.textDisabled,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CandorRadius.pill),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: CandorColors.textPrimary,
        disabledForegroundColor: CandorColors.textDisabled,
        backgroundColor: Colors.transparent,
      ),
    ),

    // ── Input Fields ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CandorColors.glassSurface1,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CandorRadius.md),
        borderSide: BorderSide(color: CandorColors.glassBorder1, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CandorRadius.md),
        borderSide: BorderSide(color: CandorColors.glassBorder1, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CandorRadius.md),
        borderSide: BorderSide(color: CandorColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CandorRadius.md),
        borderSide: BorderSide(color: CandorColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CandorRadius.md),
        borderSide: BorderSide(color: CandorColors.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CandorRadius.md),
        borderSide: BorderSide(color: CandorColors.glassBorder1, width: 1),
      ),
      labelStyle: TextStyle(color: CandorColors.textTertiary),
      hintStyle: TextStyle(color: CandorColors.textDisabled),
      helperStyle: TextStyle(color: CandorColors.textTertiary),
      errorStyle: TextStyle(color: CandorColors.error),
      floatingLabelStyle: TextStyle(color: CandorColors.accent),
    ),

    // ── Dialogs & Bottom Sheets ──
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CandorRadius.xl),
      ),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: CandorColors.textPrimary,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: CandorColors.textSecondary,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(CandorRadius.xl)),
      ),
      modalBackgroundColor: Colors.transparent,
    ),

    // ── Navigation ──
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: CandorColors.glassSurface2,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return textTheme.labelSmall?.copyWith(
            color: CandorColors.accent,
            fontWeight: FontWeight.w600,
          );
        }
        return textTheme.labelSmall?.copyWith(color: CandorColors.textTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: CandorColors.accent, size: 24);
        }
        return IconThemeData(color: CandorColors.textTertiary, size: 24);
      }),
    ),

    // ── Chips ──
    chipTheme: ChipThemeData(
      backgroundColor: CandorColors.glassSurface1,
      disabledColor: CandorColors.glassSurface1.withValues(alpha: 0.5),
      selectedColor: CandorColors.accentContainer,
      secondarySelectedColor: CandorColors.accentContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelStyle: TextStyle(color: CandorColors.textPrimary),
      secondaryLabelStyle: TextStyle(color: CandorColors.onAccent),
      brightness: Brightness.dark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CandorRadius.pill),
        side: BorderSide(color: CandorColors.glassBorder1, width: 1),
      ),
      side: BorderSide(color: CandorColors.glassBorder1, width: 1),
    ),

    // ── Dividers ──
    dividerTheme: DividerThemeData(
      color: CandorColors.glassBorder1,
      thickness: 1,
      space: 1,
    ),

    // ── List Tiles ──
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor: Colors.transparent,
      selectedTileColor: CandorColors.glassSurface2,
      iconColor: CandorColors.textSecondary,
      textColor: CandorColors.textPrimary,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        color: CandorColors.textPrimary,
      ),
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: CandorColors.textSecondary,
      ),
      leadingAndTrailingTextStyle: textTheme.bodyMedium?.copyWith(
        color: CandorColors.textTertiary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CandorRadius.md),
      ),
    ),

    // ── Tooltips ──
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: CandorColors.glassSurface3,
        borderRadius: BorderRadius.circular(CandorRadius.sm),
        border: Border.all(color: CandorColors.glassBorder1, width: 1),
        boxShadow: CandorElevation.level2,
      ),
      textStyle: textTheme.labelSmall?.copyWith(color: CandorColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      preferBelow: true,
      verticalOffset: 8,
    ),

    // ── Snackbars ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CandorColors.glassSurface3,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: CandorColors.textPrimary),
      actionTextColor: CandorColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CandorRadius.md),
      ),
      elevation: 0,
    ),

    // ── Progress Indicators ──
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: CandorColors.accent,
      linearTrackColor: CandorColors.glassSurface2,
      circularTrackColor: CandorColors.glassSurface2,
    ),

    // ── Sliders ──
    sliderTheme: SliderThemeData(
      activeTrackColor: CandorColors.accent,
      inactiveTrackColor: CandorColors.glassSurface2,
      thumbColor: CandorColors.accent,
      overlayColor: CandorColors.accentContainer,
      valueIndicatorColor: CandorColors.accent,
      valueIndicatorTextStyle: textTheme.labelSmall?.copyWith(color: CandorColors.onAccent),
    ),

    // ── Switches ──
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return CandorColors.accent;
        return CandorColors.textDisabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return CandorColors.accentContainer;
        return CandorColors.glassSurface2;
      }),
      trackOutlineColor: WidgetStateProperty.all(CandorColors.glassBorder1),
    ),

    // ── Checkboxes & Radios ──
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return CandorColors.accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(CandorColors.onAccent),
      side: BorderSide(color: CandorColors.glassBorder2, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CandorRadius.sm)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return CandorColors.accent;
        return CandorColors.textTertiary;
      }),
    ),

    // ── Segmented Buttons ──
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return CandorColors.accentContainer;
          if (states.contains(WidgetState.hovered)) return CandorColors.glassSurface2;
          if (states.contains(WidgetState.pressed)) return CandorColors.glassSurface3;
          return CandorColors.glassSurface1;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return CandorColors.accent;
          return CandorColors.textPrimary;
        }),
        side: WidgetStateProperty.all(BorderSide(color: CandorColors.glassBorder1, width: 1)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(CandorRadius.pill)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        textStyle: WidgetStateProperty.all(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),

    // ── Tab Bar ──
    tabBarTheme: TabBarThemeData(
      labelColor: CandorColors.accent,
      unselectedLabelColor: CandorColors.textTertiary,
      indicator: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CandorColors.accent, width: 2.5),
        ),
      ),
      dividerColor: CandorColors.glassBorder1,
      labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
    ),

    // ── Page Transitions ──
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),

    // ── Visual Density ──
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

/// A Material 3 [ColorScheme] extension for easy access to Candor-specific colors.
extension CandorColorScheme on ColorScheme {
  Color get glassSurface1 => CandorColors.glassSurface1;
  Color get glassSurface2 => CandorColors.glassSurface2;
  Color get glassSurface3 => CandorColors.glassSurface3;
  Color get glassSurface4 => CandorColors.glassSurface4;
  Color get glassBorder1 => CandorColors.glassBorder1;
  Color get glassBorder2 => CandorColors.glassBorder2;
  Color get glassBorder3 => CandorColors.glassBorder3;
  Color get textPrimary => CandorColors.textPrimary;
  Color get textSecondary => CandorColors.textSecondary;
  Color get textTertiary => CandorColors.textTertiary;
  Color get textDisabled => CandorColors.textDisabled;
  Color get tier1 => CandorColors.tier1;
  Color get tier2 => CandorColors.tier2;
  Color get tier1Constrained => CandorColors.tier1Constrained;
  Color get accent => CandorColors.accent;
  Color get onAccent => CandorColors.onAccent;
  Color get accentContainer => CandorColors.accentContainer;
}