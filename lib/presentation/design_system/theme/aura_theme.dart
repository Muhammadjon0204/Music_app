import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';
import 'package:music_app/presentation/design_system/tokens/aura_typography.dart';
import 'package:music_app/presentation/design_system/transitions/aura_page_transitions.dart';

abstract final class AuraTheme {
  static ThemeData dark() => _build(AuraColors.dark, Brightness.dark);

  static ThemeData _build(AuraColors colors, Brightness brightness) {
    final typography = AuraTypography.fromColors(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        secondary: colors.accentSecondary,
        onSecondary: colors.onAccent,
        error: colors.error,
        onError: colors.onAccent,
        surface: colors.background,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.borderStrong,
        outlineVariant: colors.border,
      ),
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      // Press feedback comes from AuraPressable, not Material ink ripples.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: TextTheme(bodyMedium: typography.body),
      iconTheme: IconThemeData(
        color: colors.textPrimary,
        size: AuraSizes.iconLg,
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 0.5,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(colors.onAccent),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.surfaceElevated,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.35),
        selectionHandleColor: colors.accent,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.accent,
        scaffoldBackgroundColor: colors.background,
        barBackgroundColor: colors.background,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const AuraPageTransitionsBuilder(),
        },
      ),
      extensions: [colors, typography],
    );
  }
}
