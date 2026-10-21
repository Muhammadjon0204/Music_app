import 'package:flutter/material.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';

/// Text styles. No font family is set: on iOS the platform typography
/// supplies San Francisco; other platforms use their system fonts.
/// Sizes scale with the system text size (Dynamic Type) automatically.
@immutable
final class AuraTypography extends ThemeExtension<AuraTypography> {
  const AuraTypography({
    required this.largeTitle,
    required this.title1,
    required this.title2,
    required this.title3,
    required this.headline,
    required this.body,
    required this.subhead,
    required this.footnote,
    required this.caption,
    required this.button,
    required this.numeric,
  });

  factory AuraTypography.fromColors(AuraColors colors) {
    TextStyle style(
      double size,
      double lineHeight,
      FontWeight weight,
      Color color, {
      double letterSpacing = 0,
    }) => TextStyle(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      leadingDistribution: TextLeadingDistribution.even,
    );

    final primary = colors.textPrimary;
    final secondary = colors.textSecondary;
    return AuraTypography(
      largeTitle: style(30, 36, FontWeight.w700, primary, letterSpacing: -0.5),
      title1: style(24, 30, FontWeight.w700, primary, letterSpacing: -0.3),
      title2: style(20, 26, FontWeight.w700, primary, letterSpacing: -0.2),
      title3: style(18, 23, FontWeight.w600, primary, letterSpacing: -0.1),
      headline: style(15, 20, FontWeight.w500, primary),
      body: style(15, 21, FontWeight.w400, primary),
      subhead: style(13, 18, FontWeight.w400, secondary),
      footnote: style(12, 16, FontWeight.w500, secondary),
      caption: style(11, 13, FontWeight.w500, secondary),
      button: style(15, 20, FontWeight.w600, primary),
      numeric: style(
        13,
        18,
        FontWeight.w400,
        colors.textTertiary,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }

  /// Screen titles: "Поиск", "Библиотека".
  final TextStyle largeTitle;

  /// Album, playlist and artist names on detail screens.
  final TextStyle title1;

  /// Track title on Now Playing; empty and error state titles.
  final TextStyle title2;

  /// Section headers.
  final TextStyle title3;

  /// Primary line of list rows.
  final TextStyle headline;
  final TextStyle body;

  /// Secondary line of list rows.
  final TextStyle subhead;
  final TextStyle footnote;

  /// Tab bar labels and the smallest metadata.
  final TextStyle caption;
  final TextStyle button;

  /// Durations and counters; tabular figures keep columns aligned.
  final TextStyle numeric;

  @override
  AuraTypography copyWith({
    TextStyle? largeTitle,
    TextStyle? title1,
    TextStyle? title2,
    TextStyle? title3,
    TextStyle? headline,
    TextStyle? body,
    TextStyle? subhead,
    TextStyle? footnote,
    TextStyle? caption,
    TextStyle? button,
    TextStyle? numeric,
  }) {
    return AuraTypography(
      largeTitle: largeTitle ?? this.largeTitle,
      title1: title1 ?? this.title1,
      title2: title2 ?? this.title2,
      title3: title3 ?? this.title3,
      headline: headline ?? this.headline,
      body: body ?? this.body,
      subhead: subhead ?? this.subhead,
      footnote: footnote ?? this.footnote,
      caption: caption ?? this.caption,
      button: button ?? this.button,
      numeric: numeric ?? this.numeric,
    );
  }

  @override
  AuraTypography lerp(
    covariant ThemeExtension<AuraTypography>? other,
    double t,
  ) {
    if (other is! AuraTypography) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AuraTypography(
      largeTitle: mix(largeTitle, other.largeTitle),
      title1: mix(title1, other.title1),
      title2: mix(title2, other.title2),
      title3: mix(title3, other.title3),
      headline: mix(headline, other.headline),
      body: mix(body, other.body),
      subhead: mix(subhead, other.subhead),
      footnote: mix(footnote, other.footnote),
      caption: mix(caption, other.caption),
      button: mix(button, other.button),
      numeric: mix(numeric, other.numeric),
    );
  }
}
