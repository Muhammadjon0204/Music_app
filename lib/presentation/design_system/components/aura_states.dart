import 'package:flutter/cupertino.dart';
import 'package:music_app/presentation/design_system/components/aura_button.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

class AuraStateAction {
  const AuraStateAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class AuraLoadingState extends StatelessWidget {
  const AuraLoadingState({
    super.key,
    required this.label,
    this.showLabel = false,
  });

  /// Always announced by VoiceOver; shown on screen when [showLabel].
  final String label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: label,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(
                color: context.auraColors.textSecondary,
                radius: 12,
              ),
              if (showLabel) ...[
                const SizedBox(height: AuraSpacing.md),
                Text(
                  label,
                  style: context.auraText.subhead,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Static placeholder block. Intentionally not animated: no shimmer loop.
class AuraSkeletonBox extends StatelessWidget {
  const AuraSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AuraRadii.xs,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.auraColors.surfaceElevated,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class AuraListTileSkeleton extends StatelessWidget {
  const AuraListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AuraSpacing.screenHorizontal,
        vertical: AuraSpacing.sm,
      ),
      child: Row(
        children: [
          AuraSkeletonBox(
            width: AuraSizes.artworkListTile,
            height: AuraSizes.artworkListTile,
            radius: AuraRadii.sm,
          ),
          SizedBox(width: AuraSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuraSkeletonBox(width: 160, height: 12),
              SizedBox(height: AuraSpacing.sm),
              AuraSkeletonBox(width: 96, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nothing to show yet, e.g. an empty library or no offline tracks.
class AuraEmptyState extends StatelessWidget {
  const AuraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.primaryAction,
    this.secondaryAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final AuraStateAction? primaryAction;
  final AuraStateAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final gradient = context.auraColors.brandGradient;
    return _MessageLayout(
      icon: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ).createShader(bounds),
        child: Icon(icon, size: AuraSizes.stateIcon),
      ),
      title: title,
      message: message,
      primaryAction: primaryAction,
      secondaryAction: secondaryAction,
    );
  }
}

/// Something went wrong. Shows user-facing text only, never technical
/// details or stack traces.
class AuraErrorState extends StatelessWidget {
  const AuraErrorState({
    super.key,
    required this.title,
    this.message,
    this.retryAction,
    this.icon = CupertinoIcons.exclamationmark_triangle,
  });

  final String title;
  final String? message;
  final AuraStateAction? retryAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _MessageLayout(
      icon: Icon(
        icon,
        size: AuraSizes.stateIcon,
        color: context.auraColors.error,
      ),
      title: title,
      message: message,
      primaryAction: retryAction,
    );
  }
}

class _MessageLayout extends StatelessWidget {
  const _MessageLayout({
    required this.icon,
    required this.title,
    this.message,
    this.primaryAction,
    this.secondaryAction,
  });

  final Widget icon;
  final String title;
  final String? message;
  final AuraStateAction? primaryAction;
  final AuraStateAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final text = context.auraText;
    final message = this.message;
    final primary = primaryAction;
    final secondary = secondaryAction;

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AuraLayout.messageMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: icon),
              const SizedBox(height: AuraSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: text.title2,
                  textAlign: TextAlign.center,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AuraSpacing.sm),
                Text(
                  message,
                  style: text.body.copyWith(
                    color: context.auraColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (primary != null) ...[
                const SizedBox(height: AuraSpacing.xxl),
                AuraButton(
                  label: primary.label,
                  onPressed: primary.onPressed,
                  size: AuraButtonSize.large,
                  expand: true,
                ),
              ],
              if (secondary != null) ...[
                const SizedBox(height: AuraSpacing.md),
                AuraButton(
                  label: secondary.label,
                  onPressed: secondary.onPressed,
                  variant: AuraButtonVariant.secondary,
                  size: AuraButtonSize.large,
                  expand: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Filling a bounded area (a whole screen): center vertically and scroll
    // if large Dynamic Type sizes need more room. Inside a list (unbounded
    // height): take the natural height so the outer list keeps scrolling.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxHeight.isFinite) return content;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}
