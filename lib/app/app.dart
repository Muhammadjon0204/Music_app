import 'package:flutter/material.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/dev/design_system_gallery_screen.dart';

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA',
      debugShowCheckedModeBanner: false,
      // Dark only for now; a light theme can be added via AuraColors.
      theme: AuraTheme.dark(),
      // Temporary home until navigation is built in Phase 4.
      home: const DesignSystemGalleryScreen(),
    );
  }
}
