import 'package:flutter/cupertino.dart';
import 'package:music_app/presentation/design_system/components/aura_pressable.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

/// Search input in the native iOS style. [AuraSearchField.button] looks the
/// same but navigates to the search screen instead of accepting text.
class AuraSearchField extends StatelessWidget {
  const AuraSearchField({
    super.key,
    required this.placeholder,
    this.controller,
    this.focusNode,
    this.onChanged,
  }) : onPressed = null;

  const AuraSearchField.button({
    super.key,
    required this.placeholder,
    required VoidCallback this.onPressed,
  }) : controller = null,
       focusNode = null,
       onChanged = null;

  final String placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    final placeholderStyle = text.body.copyWith(color: colors.textTertiary);
    final onPressed = this.onPressed;

    if (onPressed != null) {
      return AuraPressable(
        onPressed: onPressed,
        feedback: AuraPressFeedback.opacity,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AuraSizes.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AuraRadii.md),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.search,
                size: AuraSizes.iconMd,
                color: colors.textTertiary,
              ),
              const SizedBox(width: AuraSpacing.sm),
              Expanded(
                child: Text(
                  placeholder,
                  style: placeholderStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CupertinoSearchTextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      placeholder: placeholder,
      style: text.body,
      placeholderStyle: placeholderStyle,
      backgroundColor: colors.surface,
      borderRadius: BorderRadius.circular(AuraRadii.md),
      itemColor: colors.textTertiary,
      cursorColor: colors.accent,
      padding: const EdgeInsetsDirectional.fromSTEB(6, 11, 6, 11),
    );
  }
}
