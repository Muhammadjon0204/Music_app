import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_motion.dart';

/// Three bars that mark the playing track. They move with [phase] (e.g.
/// the playback position), so they stop by themselves when playback does,
/// and lie flat when [active] is false or Reduce Motion is on. Decorative.
class AuraEqualizer extends StatelessWidget {
  const AuraEqualizer({
    super.key,
    required this.active,
    required this.phase,
    this.size = 18,
  });

  final bool active;

  /// Any steadily growing value; each change gives new bar heights.
  final Duration phase;
  final double size;

  /// Bar height as a fraction of [size], for bar [index].
  static double heightOf(int index, Duration phase, {required bool active}) {
    if (!active) return 0.35;
    final t = phase.inMilliseconds / 1000;
    final wave = math.sin(t * (5 + index * 2.3) + index * 1.7);
    return 0.35 + 0.65 * (wave + 1) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final color = context.auraColors.accentText;
    final moving = active && !AuraMotion.isReduced(context);
    final barWidth = size / 5;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedContainer(
                duration: AuraMotion.fast,
                curve: AuraMotion.standard,
                width: barWidth,
                height: size * heightOf(i, phase, active: moving),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(barWidth / 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
