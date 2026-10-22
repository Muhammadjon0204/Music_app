import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/design_system.dart';

/// Lets a full-screen sheet be dragged down to close. Not the only way to
/// close it: the screen must also offer a close button.
class SwipeDownToDismiss extends StatefulWidget {
  const SwipeDownToDismiss({
    super.key,
    required this.onDismiss,
    required this.child,
  });

  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<SwipeDownToDismiss> createState() => _SwipeDownToDismissState();
}

class _SwipeDownToDismissState extends State<SwipeDownToDismiss>
    with SingleTickerProviderStateMixin {
  static const _velocityToDismiss = 900.0;
  static const _distanceFractionToDismiss = 0.2;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: AuraMotion.normal,
  )..addListener(_onSettleTick);

  double _offset = 0;
  double _settleFrom = 0;

  void _onSettleTick() => setState(
    () => _offset =
        _settleFrom * (1 - AuraMotion.standard.transform(_settle.value)),
  );

  void _snapBack() {
    if (AuraMotion.isReduced(context) || _offset == 0) {
      setState(() => _offset = 0);
      return;
    }
    _settleFrom = _offset;
    _settle.forward(from: 0);
  }

  void _onDragEnd(DragEndDetails details) {
    final height = context.size?.height ?? 1;
    final fast = (details.primaryVelocity ?? 0) > _velocityToDismiss;
    if (fast || _offset > height * _distanceFractionToDismiss) {
      widget.onDismiss();
    } else {
      _snapBack();
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      excludeFromSemantics: true,
      onVerticalDragStart: (_) => _settle.stop(),
      onVerticalDragUpdate: (details) => setState(
        () => _offset = (_offset + details.delta.dy).clamp(0, double.infinity),
      ),
      onVerticalDragEnd: _onDragEnd,
      onVerticalDragCancel: _snapBack,
      child: Transform.translate(
        offset: Offset(0, _offset),
        child: widget.child,
      ),
    );
  }
}
