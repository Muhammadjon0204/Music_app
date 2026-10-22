import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/tokens/aura_motion.dart';

/// Full-screen sheet rising from the bottom (the player). Under Reduce
/// Motion it cross-fades instead.
Widget auraSheetTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (AuraMotion.isReduced(context)) {
    return FadeTransition(opacity: animation, child: child);
  }
  return SlideTransition(
    position: animation.drive(
      Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).chain(CurveTween(curve: AuraMotion.emphasized)),
    ),
    child: child,
  );
}
