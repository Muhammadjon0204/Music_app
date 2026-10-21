import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_motion.dart';

enum AuraPressFeedback {
  /// Slight shrink and dim. Buttons and cards.
  scale,

  /// Dim only. Icons and text links.
  opacity,

  /// Background highlight. List rows.
  highlight,
}

/// Base for every tappable element: immediate press feedback, a button role
/// for VoiceOver, and a disabled state when [onPressed] is null.
class AuraPressable extends StatefulWidget {
  const AuraPressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.feedback = AuraPressFeedback.scale,
    this.semanticLabel,
    this.toggled,
    this.selected,
    this.haptic = false,
    this.borderRadius = BorderRadius.zero,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AuraPressFeedback feedback;

  /// Required when the child has no text, e.g. an icon.
  final String? semanticLabel;

  /// On/off state for toggles such as "favorite"; announced by VoiceOver.
  final bool? toggled;
  final bool? selected;

  /// Light haptic on tap. Reserve for primary playback actions.
  final bool haptic;

  /// Shape of the [AuraPressFeedback.highlight] background.
  final BorderRadius borderRadius;

  @override
  State<AuraPressable> createState() => _AuraPressableState();
}

class _AuraPressableState extends State<AuraPressable> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _handleTap() {
    if (widget.haptic) unawaited(HapticFeedback.selectionClick());
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _pressed && _enabled;
    final reduced = AuraMotion.isReduced(context);

    final Widget content = switch (widget.feedback) {
      AuraPressFeedback.scale => AnimatedScale(
        scale: pressed && !reduced ? 0.97 : 1,
        duration: AuraMotion.fast,
        curve: AuraMotion.standard,
        child: AnimatedOpacity(
          opacity: pressed ? 0.85 : 1,
          duration: AuraMotion.fast,
          child: widget.child,
        ),
      ),
      AuraPressFeedback.opacity => AnimatedOpacity(
        opacity: pressed ? 0.5 : 1,
        duration: AuraMotion.fast,
        child: widget.child,
      ),
      AuraPressFeedback.highlight => AnimatedContainer(
        duration: AuraMotion.fast,
        decoration: BoxDecoration(
          color: context.auraColors.surfaceElevated.withValues(
            alpha: pressed ? 1 : 0,
          ),
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    };

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.semanticLabel,
        toggled: widget.toggled,
        selected: widget.selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: _enabled ? _handleTap : null,
          child: content,
        ),
      ),
    );
  }
}
