import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/tokens/aura_motion.dart';

/// Cross-fades between states (loading → content → error). Children must
/// have distinct keys, otherwise no transition runs.
class AuraStateSwitcher extends StatelessWidget {
  const AuraStateSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = AuraMotion.isReduced(context);
    return AnimatedSwitcher(
      duration: AuraMotion.fade(context, AuraMotion.normal),
      switchInCurve: AuraMotion.standard,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final faded = FadeTransition(opacity: animation, child: child);
        if (reduced) return faded;
        return ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          child: faded,
        );
      },
      child: child,
    );
  }
}
