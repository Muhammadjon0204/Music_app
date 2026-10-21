import 'package:flutter/widgets.dart';

/// Motion tokens and Reduce Motion handling.
///
/// Under the system Reduce Motion setting, spatial motion (slides, scale) is
/// removed, while fades stay as a short signal that state has changed.
abstract final class AuraMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration spatial(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;

  static Duration fade(BuildContext context, Duration duration) =>
      isReduced(context) && duration > fast ? fast : duration;
}
