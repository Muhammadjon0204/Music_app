import 'package:flutter/cupertino.dart';
import 'package:music_app/presentation/design_system/tokens/aura_motion.dart';

/// iOS-style horizontal push with edge swipe-back on every platform.
/// Under Reduce Motion, the slide and the parallax of the previous screen
/// are replaced by a cross-fade, as iOS does.
class AuraPageTransitionsBuilder extends PageTransitionsBuilder {
  const AuraPageTransitionsBuilder();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _cupertino.transitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) {
        if (AuraMotion.isReduced(context)) return child;
        return CupertinoPageTransition.delegatedTransition(
          context,
          animation,
          secondaryAnimation,
          allowSnapshotting,
          child,
        );
      };

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AuraMotion.isReduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return _cupertino.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
