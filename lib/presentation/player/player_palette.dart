import 'package:flutter/painting.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';

/// Now Playing background derived from the artwork colors: tinted at the
/// top, fading into the app background. Text sits below the middle stop,
/// which is dark enough for it (checked in contrast tests).
List<Color> nowPlayingBackground(List<Color> artwork, AuraColors colors) => [
  Color.alphaBlend(colors.background.withValues(alpha: 0.45), artwork.first),
  Color.alphaBlend(colors.background.withValues(alpha: 0.7), artwork.last),
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
