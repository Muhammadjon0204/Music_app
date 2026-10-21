import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

/// Fills the available space but caps the width on wide screens (landscape,
/// iPad), keeping content centered.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AuraLayout.maxContentWidth),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}
