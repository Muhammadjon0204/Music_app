import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/components/aura_pressable.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

/// Row for tracks, albums, settings and queue items.
class AuraListTile extends StatelessWidget {
  const AuraListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onPressed,
    this.isActive = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AuraSpacing.screenHorizontal,
      vertical: AuraSpacing.sm,
    ),
  });

  final String title;
  final String? subtitle;

  /// Usually an [AuraArtwork] of [AuraSizes.artworkListTile].
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onPressed;

  /// Marks the current item, e.g. the playing track in a queue. Shown by
  /// accent color and heavier weight, and announced as selected.
  final bool isActive;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = context.auraText;
    final leading = this.leading;
    final trailing = this.trailing;
    final subtitle = this.subtitle;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AuraSizes.listTileMinHeight),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: AuraSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: isActive
                        ? text.headline.copyWith(
                            color: context.auraColors.accentText,
                            fontWeight: FontWeight.w600,
                          )
                        : text.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AuraSpacing.xxs),
                    Text(
                      subtitle,
                      style: text.subhead,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AuraSpacing.md),
              // Capped and scaled down at large text sizes so the title
              // always keeps room.
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AuraSizes.listTileTrailingMaxWidth,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onPressed == null) {
      return MergeSemantics(
        child: Semantics(selected: isActive, child: row),
      );
    }
    return AuraPressable(
      onPressed: onPressed,
      selected: isActive,
      feedback: AuraPressFeedback.highlight,
      child: row,
    );
  }
}
