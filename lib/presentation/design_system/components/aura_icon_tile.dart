import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

/// An icon on a softly accent-tinted rounded square: the leading element of
/// category and settings rows.
class AuraIconTile extends StatelessWidget {
  const AuraIconTile({
    super.key,
    required this.icon,
    this.size = AuraSizes.artworkListTile,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colors.accent.withValues(alpha: 0.14),
            colors.surface,
          ),
          borderRadius: BorderRadius.circular(AuraRadii.md),
        ),
        child: Icon(icon, color: colors.accentText, size: size * 0.46),
      ),
    );
  }
}
