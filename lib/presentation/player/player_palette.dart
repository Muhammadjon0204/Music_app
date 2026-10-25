import 'package:flutter/painting.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';
import 'package:music_app/presentation/player/artwork_colors.dart';

/// Now Playing background derived from the artwork colors: tinted at the
/// top, fading into the app background. Any cover works, including real
/// ones: each stop is covered by the background just enough that the text
/// on it stays readable (the close button on the top, title and times from
/// the middle stop down).
List<Color> nowPlayingBackground(List<Color> artwork, AuraColors colors) => [
  readableTint(
    artwork.first,
    colors,
    minAlpha: 0.45,
    texts: [colors.textPrimary],
    minContrast: 3,
  ),
  readableTint(
    artwork.last,
    colors,
    minAlpha: 0.7,
    texts: [colors.textPrimary, colors.textSecondary, colors.textTertiary],
    minContrast: 4.5,
  ),
  colors.background,
];

const nowPlayingBackgroundStops = [0.0, 0.55, 1.0];

/// Opacity of the dark backdrop behind small labels placed on the tinted
/// top of Now Playing (e.g. the demo chip), so they stay readable on any
/// artwork color.
const nowPlayingLabelBackdropAlpha = 0.75;

/// Shared by the mini player and Now Playing so the artwork flies between
/// them.
const playerArtworkHeroTag = 'player-artwork';
