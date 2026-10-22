import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_app/presentation/common/content_width.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/detail_navigation.dart';

/// Scaffold for library pages: a pinned bar with back (never scrolls away),
/// a large title, and scrolling content.
class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.header,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// Replaces the default title block (e.g. album artwork header).
  final Widget? header;

  /// Extra action in the bar, e.g. a playlist menu.
  final Widget? trailing;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final text = context.auraText;
    final subtitle = this.subtitle;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
                child: Row(
                  children: [
                    AuraIconButton(
                      icon: CupertinoIcons.chevron_left,
                      semanticLabel: AuraStrings.back,
                      onPressed: () => goBack(context),
                    ),
                    const Spacer(),
                    ?trailing,
                  ],
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child:
                          header ??
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AuraSpacing.screenHorizontal,
                              0,
                              AuraSpacing.screenHorizontal,
                              AuraSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(title, style: text.largeTitle),
                                ),
                                if (subtitle != null)
                                  Text(subtitle, style: text.subhead),
                              ],
                            ),
                          ),
                    ),
                    ...slivers,
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            AuraSpacing.xxxl +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state that fills the rest of a [LibraryPage].
class LibraryEmptySliver extends StatelessWidget {
  const LibraryEmptySliver({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.primaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final AuraStateAction? primaryAction;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: AuraEmptyState(
        icon: icon,
        title: title,
        message: message,
        primaryAction: primaryAction,
      ),
    );
  }
}
