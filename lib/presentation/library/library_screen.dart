import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_app/presentation/common/content_width.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// Library foundation. Stays empty until music import exists (Phase 7).
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpacing.screenHorizontal,
                  AuraSpacing.lg,
                  AuraSpacing.screenHorizontal,
                  0,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    AuraStrings.tabLibrary,
                    style: context.auraText.largeTitle,
                  ),
                ),
              ),
              const Expanded(
                child: AuraEmptyState(
                  icon: CupertinoIcons.music_albums,
                  title: AuraStrings.libraryEmptyTitle,
                  message: AuraStrings.libraryEmptyMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
