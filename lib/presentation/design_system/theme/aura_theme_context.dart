import 'package:flutter/material.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';
import 'package:music_app/presentation/design_system/tokens/aura_typography.dart';

extension AuraThemeContext on BuildContext {
  AuraColors get auraColors => _extension<AuraColors>();

  AuraTypography get auraText => _extension<AuraTypography>();

  T _extension<T>() {
    final value = Theme.of(this).extension<T>();
    if (value == null) {
      throw StateError('$T is missing; wrap the app in AuraTheme.');
    }
    return value;
  }
}
