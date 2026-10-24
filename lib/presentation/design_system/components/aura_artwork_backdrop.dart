import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/components/aura_artwork.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';

/// Fills its box with artwork (cropped to cover) over its placeholder
/// gradient, optionally blurred into an ambient glow. Decorative: hidden
/// from VoiceOver.
class AuraArtworkBackdrop extends StatelessWidget {
  const AuraArtworkBackdrop({
    super.key,
    required this.placeholderSeed,
    this.image,
    this.blur = 0,
  });

  final ImageProvider<Object>? image;
  final String placeholderSeed;

  /// Gaussian blur radius; 0 shows the image sharp.
  final double blur;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AuraArtwork.placeholderGradient(
                placeholderSeed,
                context.auraColors,
              ),
            ),
          ),
        ),
        if (image != null)
          Image(
            image: image,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
    if (blur > 0) {
      content = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: content,
      );
    }
    return ExcludeSemantics(child: content);
  }
}
