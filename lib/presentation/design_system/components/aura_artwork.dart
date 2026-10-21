import 'package:flutter/cupertino.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';
import 'package:music_app/presentation/design_system/tokens/aura_motion.dart';

enum AuraArtworkShape { rounded, circle }

/// Cover art with a gradient placeholder.
///
/// The placeholder stays underneath while the image loads and when it fails,
/// so there is no flash of empty space. Images are decoded at display size
/// to limit memory use.
class AuraArtwork extends StatelessWidget {
  const AuraArtwork({
    super.key,
    required this.size,
    this.image,
    this.shape = AuraArtworkShape.rounded,
    this.borderRadius = AuraRadii.sm,
    this.placeholderSeed = '',
    this.semanticLabel,
  });

  final double size;
  final ImageProvider<Object>? image;
  final AuraArtworkShape shape;
  final double borderRadius;

  /// Picks a stable placeholder gradient, e.g. the album title.
  final String placeholderSeed;

  /// Artwork is decorative unless a label is given.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final placeholder = _Placeholder(
      size: size,
      colors: placeholderGradient(placeholderSeed, colors),
      iconColor: colors.textPrimary.withValues(alpha: 0.7),
    );

    Widget content = placeholder;
    final image = this.image;
    if (image != null) {
      final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context))
          .round();
      content = Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          Image(
            // Sized for square covers; non-square images are cropped by cover.
            image: ResizeImage.resizeIfNeeded(cacheWidth, null, image),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: AuraMotion.fade(context, AuraMotion.normal),
                curve: AuraMotion.standard,
                child: child,
              );
            },
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      );
    }

    final clipped = SizedBox.square(
      dimension: size,
      child: shape == AuraArtworkShape.circle
          ? ClipOval(child: content)
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: content,
            ),
    );

    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: clipped);
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: clipped),
    );
  }

  /// The placeholder gradient for [seed]; stable across launches.
  static List<Color> placeholderGradient(String seed, AuraColors colors) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final gradients = colors.artworkGradients;
    return gradients[hash % gradients.length];
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.size,
    required this.colors,
    required this.iconColor,
  });

  final double size;
  final List<Color> colors;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.music_note,
          size: size * 0.36,
          color: iconColor,
        ),
      ),
    );
  }
}
