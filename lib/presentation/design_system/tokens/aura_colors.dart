import 'package:flutter/material.dart';

/// Color tokens. Feature widgets read them via `context.auraColors` and never
/// hard-code colors. Each theme the user can pick is one instance; every one
/// is checked for contrast in tests.
@immutable
final class AuraColors extends ThemeExtension<AuraColors> {
  const AuraColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.accentSecondary,
    required this.error,
    required this.brandGradient,
    required this.artworkGradients,
  });

  static const dark = AuraColors(
    background: Color(0xFF0B0B10),
    surface: Color(0xFF15151D),
    surfaceElevated: Color(0xFF1E1E28),
    border: Color(0xFF262631),
    borderStrong: Color(0xFF4A4A58),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA6A6B2),
    textTertiary: Color(0xFF868692),
    accent: Color(0xFFE0136F),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFFFF5C9F),
    accentSecondary: Color(0xFF8B5CF6),
    error: Color(0xFFFF453A),
    brandGradient: [Color(0xFFFF4D9A), Color(0xFF8B5CF6)],
    artworkGradients: [
      [Color(0xFFE0136F), Color(0xFF4A1D7A)],
      [Color(0xFF8B5CF6), Color(0xFF1F1747)],
      [Color(0xFFFF7A59), Color(0xFFA0177F)],
      [Color(0xFF3A6FF8), Color(0xFF4A1D7A)],
    ],
  );

  /// "Полночь": the navy palette, monochrome with a light accent.
  static const midnight = AuraColors(
    background: Color(0xFF06141B),
    surface: Color(0xFF11212D),
    surfaceElevated: Color(0xFF1A2C3A),
    border: Color(0xFF253745),
    borderStrong: Color(0xFF4A5C6A),
    textPrimary: Color(0xFFE4E8E7),
    textSecondary: Color(0xFF9BA8AB),
    textTertiary: Color(0xFF8A979B),
    accent: Color(0xFFCCD0CF),
    onAccent: Color(0xFF06141B),
    accentText: Color(0xFFCCD0CF),
    accentSecondary: Color(0xFF4A5C6A),
    error: Color(0xFFFF6B61),
    brandGradient: [Color(0xFF9BA8AB), Color(0xFF253745)],
    artworkGradients: [
      [Color(0xFF4A5C6A), Color(0xFF06141B)],
      [Color(0xFF253745), Color(0xFF0B1A24)],
      [Color(0xFF6E8290), Color(0xFF253745)],
      [Color(0xFF3E5A70), Color(0xFF11212D)],
    ],
  );

  /// "Лес": the green palette.
  static const forest = AuraColors(
    background: Color(0xFF051F20),
    surface: Color(0xFF0B2B26),
    surfaceElevated: Color(0xFF163832),
    border: Color(0xFF1D4239),
    borderStrong: Color(0xFF588471),
    textPrimary: Color(0xFFDAF1DE),
    textSecondary: Color(0xFF8EB69B),
    textTertiary: Color(0xFF7FA88C),
    accent: Color(0xFF8EB69B),
    onAccent: Color(0xFF051F20),
    accentText: Color(0xFF8EB69B),
    accentSecondary: Color(0xFF235347),
    error: Color(0xFFFF6B61),
    brandGradient: [Color(0xFF8EB69B), Color(0xFF235347)],
    artworkGradients: [
      [Color(0xFF235347), Color(0xFF051F20)],
      [Color(0xFF4E8C6E), Color(0xFF163832)],
      [Color(0xFF2F6B57), Color(0xFF0B2B26)],
      [Color(0xFF3B7A62), Color(0xFF051F20)],
    ],
  );

  /// "Пудра": the mauve palette, the only light theme.
  static const rose = AuraColors(
    background: Color(0xFFF7EFE7),
    surface: Color(0xFFEFE2D8),
    surfaceElevated: Color(0xFFE8D2C4),
    border: Color(0xFFE2CCBF),
    borderStrong: Color(0xFF9E8189),
    textPrimary: Color(0xFF3E3239),
    textSecondary: Color(0xFF6B5560),
    textTertiary: Color(0xFF66525C),
    accent: Color(0xFF6B5560),
    onAccent: Color(0xFFF7EFE7),
    accentText: Color(0xFF7E4F5E),
    accentSecondary: Color(0xFF9E8189),
    error: Color(0xFFA8231C),
    brandGradient: [Color(0xFFC7A9A3), Color(0xFF6B5560)],
    artworkGradients: [
      [Color(0xFFE8D2C4), Color(0xFFC7A9A3)],
      [Color(0xFFF2DDD3), Color(0xFFB8969B)],
      [Color(0xFFD9BDB4), Color(0xFFAC9097)],
      [Color(0xFFEBD8CF), Color(0xFFC7A9A3)],
    ],
  );

  final Color background;

  /// Cards, inputs, grouped rows.
  final Color surface;

  /// Pressed rows, sheets, the current queue item.
  final Color surfaceElevated;

  /// Hairline dividers and subtle outlines.
  final Color border;

  /// Outlines that must stay visible, e.g. secondary buttons.
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;

  /// Lowest-emphasis text that still meets 4.5:1, e.g. durations.
  final Color textTertiary;

  /// Filled accent surfaces: primary buttons, switches, progress.
  final Color accent;

  /// Text and icons placed on [accent].
  final Color onAccent;

  /// Accent used for text and icons on dark surfaces. Lighter than [accent]
  /// so small text keeps 4.5:1 contrast.
  final Color accentText;

  /// Violet partner of [accent], used in gradients.
  final Color accentSecondary;

  final Color error;

  /// Decorative gradient for illustrations and highlights. Never put body
  /// text on it without a scrim.
  final List<Color> brandGradient;

  /// Gradients for artwork placeholders when a cover is missing.
  final List<List<Color>> artworkGradients;

  /// Soft glow for the primary call to action. Use sparingly.
  List<BoxShadow> get accentGlow => [
    BoxShadow(
      color: accent.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Depth under large artwork on detail pages; the same in every theme.
  List<BoxShadow> get artworkShadow => const [
    BoxShadow(color: Color(0x4D000000), blurRadius: 32, offset: Offset(0, 16)),
  ];

  @override
  AuraColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? onAccent,
    Color? accentText,
    Color? accentSecondary,
    Color? error,
    List<Color>? brandGradient,
    List<List<Color>>? artworkGradients,
  }) {
    return AuraColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentText: accentText ?? this.accentText,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      error: error ?? this.error,
      brandGradient: brandGradient ?? this.brandGradient,
      artworkGradients: artworkGradients ?? this.artworkGradients,
    );
  }

  @override
  AuraColors lerp(covariant ThemeExtension<AuraColors>? other, double t) {
    if (other is! AuraColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AuraColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentText: mix(accentText, other.accentText),
      accentSecondary: mix(accentSecondary, other.accentSecondary),
      error: mix(error, other.error),
      brandGradient: t < 0.5 ? brandGradient : other.brandGradient,
      artworkGradients: t < 0.5 ? artworkGradients : other.artworkGradients,
    );
  }
}
