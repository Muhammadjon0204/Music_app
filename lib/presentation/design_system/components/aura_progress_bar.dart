import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/common/duration_format.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

/// Seekable playback progress with elapsed and remaining time.
///
/// While dragging, the bar follows the finger and seeks once on release.
/// VoiceOver treats it as an adjustable slider (swipe up/down = ±[step]).
class AuraProgressBar extends StatefulWidget {
  const AuraProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.semanticLabel,
    required this.semanticValue,
    this.step = const Duration(seconds: 10),
  });

  final Duration position;

  /// Null or zero while unknown; the bar is then not seekable.
  final Duration? duration;
  final ValueChanged<Duration>? onSeek;
  final String semanticLabel;

  /// Spoken value for a position and total, e.g. "1:32 из 3:41".
  final String Function(Duration position, Duration total) semanticValue;
  final Duration step;

  @override
  State<AuraProgressBar> createState() => _AuraProgressBarState();
}

class _AuraProgressBarState extends State<AuraProgressBar> {
  double? _dragFraction;

  Duration get _total => widget.duration ?? Duration.zero;

  bool get _enabled => widget.onSeek != null && _total > Duration.zero;

  double get _fraction {
    final drag = _dragFraction;
    if (drag != null) return drag;
    if (_total == Duration.zero) return 0;
    return (widget.position.inMicroseconds / _total.inMicroseconds).clamp(
      0.0,
      1.0,
    );
  }

  Duration _at(double fraction) =>
      Duration(microseconds: (_total.inMicroseconds * fraction).round());

  Duration _clamp(Duration value) {
    if (value.isNegative) return Duration.zero;
    return value > _total ? _total : value;
  }

  void _seekBy(Duration delta) =>
      widget.onSeek?.call(_clamp(_at(_fraction) + delta));

  void _commitDrag() {
    final fraction = _dragFraction;
    setState(() => _dragFraction = null);
    if (fraction != null) widget.onSeek?.call(_at(fraction));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    final shown = _at(_fraction);
    final known = _total > Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          slider: true,
          label: widget.semanticLabel,
          value: known ? widget.semanticValue(shown, _total) : null,
          increasedValue: known
              ? widget.semanticValue(_clamp(shown + widget.step), _total)
              : null,
          decreasedValue: known
              ? widget.semanticValue(_clamp(shown - widget.step), _total)
              : null,
          onIncrease: _enabled ? () => _seekBy(widget.step) : null,
          onDecrease: _enabled ? () => _seekBy(-widget.step) : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              double fractionAt(double dx) =>
                  width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onHorizontalDragStart: _enabled
                    ? (d) => setState(
                        () => _dragFraction = fractionAt(d.localPosition.dx),
                      )
                    : null,
                onHorizontalDragUpdate: _enabled
                    ? (d) => setState(
                        () => _dragFraction = fractionAt(d.localPosition.dx),
                      )
                    : null,
                onHorizontalDragEnd: _enabled ? (_) => _commitDrag() : null,
                onHorizontalDragCancel: _enabled
                    ? () => setState(() => _dragFraction = null)
                    : null,
                onTapUp: _enabled
                    ? (d) => widget.onSeek?.call(
                        _at(fractionAt(d.localPosition.dx)),
                      )
                    : null,
                child: SizedBox(
                  height: AuraSizes.minTouchTarget,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _BarPainter(
                      fraction: _fraction,
                      dragging: _dragFraction != null,
                      enabled: _enabled,
                      colors: colors,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        ExcludeSemantics(
          // Each label gets up to half the width and scales down rather than
          // overflowing at the largest text sizes.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    known ? formatDuration(shown) : '--:--',
                    style: text.numeric,
                  ),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    known ? '-${formatDuration(_total - shown)}' : '--:--',
                    style: text.numeric,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.fraction,
    required this.dragging,
    required this.enabled,
    required this.colors,
  });

  final double fraction;
  final bool dragging;
  final bool enabled;
  final AuraColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = dragging ? 6.0 : 4.0;
    final y = size.height / 2;
    final radius = Radius.circular(trackHeight / 2);
    final track = RRect.fromLTRBR(
      0,
      y - trackHeight / 2,
      size.width,
      y + trackHeight / 2,
      radius,
    );
    canvas.drawRRect(track, Paint()..color = colors.borderStrong);

    final filledWidth = size.width * fraction;
    if (filledWidth > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          0,
          y - trackHeight / 2,
          filledWidth,
          y + trackHeight / 2,
          radius,
        ),
        Paint()..color = colors.accent,
      );
    }

    if (enabled) {
      canvas.drawCircle(
        Offset(filledWidth.clamp(0, size.width), y),
        dragging ? 9 : 6,
        Paint()..color = colors.textPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction ||
      old.dragging != dragging ||
      old.enabled != enabled ||
      old.colors != colors;
}
