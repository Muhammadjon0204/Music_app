import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/components/aura_artwork.dart';
import 'package:music_app/presentation/design_system/components/aura_pressable.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

/// Album, playlist or artist card for horizontal carousels.
class AuraMediaCard extends StatelessWidget {
  const AuraMediaCard({
    super.key,
    required this.title,
    this.subtitle,
    this.image,
    this.onPressed,
    this.width = AuraSizes.artworkCard,
    this.circularArtwork = false,
  });

  final String title;
  final String? subtitle;
  final ImageProvider<Object>? image;
  final VoidCallback? onPressed;
  final double width;

  /// Artists use circular artwork.
  final bool circularArtwork;

  @override
  Widget build(BuildContext context) {
    final text = context.auraText;
    final subtitle = this.subtitle;

    final card = SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: circularArtwork
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AuraArtwork(
            size: width,
            image: image,
            borderRadius: AuraRadii.md,
            placeholderSeed: title,
            shape: circularArtwork
                ? AuraArtworkShape.circle
                : AuraArtworkShape.rounded,
          ),
          const SizedBox(height: AuraSpacing.sm),
          Text(
            title,
            style: text.footnote.copyWith(
              color: context.auraColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: text.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );

    if (onPressed == null) return MergeSemantics(child: card);
    return AuraPressable(onPressed: onPressed, child: card);
  }
}
