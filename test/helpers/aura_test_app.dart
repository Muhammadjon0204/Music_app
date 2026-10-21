import 'package:flutter/material.dart';
import 'package:music_app/presentation/design_system/design_system.dart';

/// Wraps [home] in the AURA theme with controllable accessibility settings.
Widget auraTestApp(
  Widget home, {
  bool reduceMotion = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AuraTheme.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: home,
  );
}

/// Centers [child] on a themed screen with loose constraints.
Widget auraTestScreen(
  Widget child, {
  bool reduceMotion = false,
  double textScale = 1,
}) => auraTestApp(
  Scaffold(body: Center(child: child)),
  reduceMotion: reduceMotion,
  textScale: textScale,
);
