import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/library/import.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/presentation/common/content_width.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/track_list_sliver.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

/// Library root: import, categories and recently added tracks.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  static const _recentCount = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(librarySnapshotProvider);
    final storageFailure = ref.watch(libraryStorageFailureProvider);
    final importState = ref.watch(importControllerProvider);
    final importer = ref.read(importControllerProvider.notifier);
    final canImport = importer.isSupported;
    final hasDemo = ref.watch(demoTracksProvider).isNotEmpty;
    final value = library.value;

    Future<void> addDemo() async {
      final result = await importer.addDemoTracks();
      if (result case Err(:final failure) when context.mounted) {
        await showFailure(context, failure);
      }
    }

    final importAction = AuraStateAction(
      label: AuraStrings.importMusic,
      onPressed: () => unawaited(importer.importFromDevice()),
    );
    final demoAction = hasDemo
        ? AuraStateAction(
            label: AuraStrings.addDemoTracks,
            onPressed: () => unawaited(addDemo()),
          )
        : null;

    final List<Widget> body;
    if (value != null && value.isEmpty) {
      body = [
        SliverFillRemaining(
          child: AuraEmptyState(
            icon: CupertinoIcons.music_albums,
            title: AuraStrings.libraryEmptyTitle,
            message: canImport
                ? AuraStrings.libraryEmptyMessage
                : AuraStrings.libraryEmptyMessageNoImport,
            primaryAction: canImport ? importAction : demoAction,
            secondaryAction: canImport ? demoAction : null,
          ),
        ),
      ];
    } else if (value != null) {
      final recent = value.recentlyAdded(limit: _recentCount);
      body = [
        SliverList.list(children: _categories(context, value)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: AuraSpacing.sectionGap,
              bottom: AuraSpacing.sm,
            ),
            child: AuraSectionHeader(title: AuraStrings.recentlyAdded),
          ),
        ),
        TrackListSliver(tracks: recent),
      ];
    } else if (library.error case final error?) {
      final (title, message) = failureText(error);
      body = [
        SliverFillRemaining(
          child: AuraErrorState(title: title, message: message),
        ),
      ];
    } else {
      body = const [
        SliverFillRemaining(
          child: AuraLoadingState(label: AuraStrings.loading),
        ),
      ];
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  onImport: canImport && !(value?.isEmpty ?? true)
                      ? importAction.onPressed
                      : null,
                  importing: importState is ImportRunning,
                ),
              ),
              if (storageFailure != null)
                const SliverToBoxAdapter(
                  child: _Banner(
                    icon: CupertinoIcons.exclamationmark_triangle,
                    lines: [AuraStrings.libraryStorageWarning],
                  ),
                ),
              if (importState is! ImportIdle)
                SliverToBoxAdapter(
                  child: _ImportBanner(
                    state: importState,
                    onDismiss: importer.dismiss,
                  ),
                ),
              ...body,
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      AuraSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _categories(BuildContext context, LibrarySnapshot library) {
    void open(String route) => unawaited(context.push(route));
    return [
      _CategoryTile(
        icon: CupertinoIcons.heart_fill,
        title: AuraStrings.favorites,
        subtitle: AuraStrings.trackCount(library.favorites.length),
        onPressed: () => open(AppRoutes.libraryFavorites),
      ),
      _CategoryTile(
        icon: CupertinoIcons.music_note_list,
        title: AuraStrings.playlists,
        subtitle: AuraStrings.playlistsCount(library.playlists.length),
        onPressed: () => open(AppRoutes.libraryPlaylists),
      ),
      _CategoryTile(
        icon: CupertinoIcons.square_stack,
        title: AuraStrings.albums,
        subtitle: AuraStrings.albumsCount(library.albums.length),
        onPressed: () => open(AppRoutes.libraryAlbums),
      ),
      _CategoryTile(
        icon: CupertinoIcons.mic,
        title: AuraStrings.artists,
        subtitle: AuraStrings.artistsCount(library.artists.length),
        onPressed: () => open(AppRoutes.libraryArtists),
      ),
      _CategoryTile(
        icon: CupertinoIcons.music_note,
        title: AuraStrings.allTracks,
        subtitle: AuraStrings.trackCount(library.tracks.length),
        onPressed: () => open(AppRoutes.libraryTracks),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onImport, required this.importing});

  /// Null hides the button (import unsupported, or the empty state already
  /// offers it).
  final VoidCallback? onImport;
  final bool importing;

  @override
  Widget build(BuildContext context) {
    final onImport = this.onImport;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpacing.screenHorizontal,
        AuraSpacing.lg,
        AuraSpacing.sm,
        AuraSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                AuraStrings.tabLibrary,
                style: context.auraText.largeTitle,
              ),
            ),
          ),
          if (onImport != null)
            AuraIconButton(
              icon: CupertinoIcons.add,
              semanticLabel: AuraStrings.importMusic,
              color: context.auraColors.accentText,
              onPressed: importing ? null : onImport,
            ),
        ],
      ),
    );
  }
}

/// A category row: icon tile, name, count, chevron.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    return AuraListTile(
      title: title,
      subtitle: subtitle,
      leading: Container(
        width: AuraSizes.artworkListTile,
        height: AuraSizes.artworkListTile,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AuraRadii.sm),
        ),
        child: Icon(icon, color: colors.accentText, size: AuraSizes.iconLg),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        color: colors.textTertiary,
        size: AuraSizes.iconSm,
      ),
      onPressed: onPressed,
    );
  }
}

/// A notice above the library content.
class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.lines, this.trailing});

  final IconData icon;
  final List<String> lines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpacing.screenHorizontal,
        AuraSpacing.sm,
        AuraSpacing.screenHorizontal,
        AuraSpacing.sm,
      ),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.lg,
            AuraSpacing.md,
            AuraSpacing.sm,
            AuraSpacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AuraRadii.md),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, color: colors.accentText, size: 20),
              ),
              const SizedBox(width: AuraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      Text(
                        line,
                        style: text.footnote.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportBanner extends StatelessWidget {
  const _ImportBanner({required this.state, required this.onDismiss});

  final ImportState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ImportRunning(:final done, :final total) => _Banner(
        icon: CupertinoIcons.arrow_down_circle,
        lines: [AuraStrings.importProgress(done, total)],
        trailing: const Padding(
          padding: EdgeInsets.all(AuraSpacing.md),
          child: CupertinoActivityIndicator(),
        ),
      ),
      ImportFinished(:final report) => _Banner(
        icon: report.imported.isEmpty
            ? CupertinoIcons.info
            : CupertinoIcons.checkmark_circle,
        lines: _reportLines(report),
        trailing: AuraIconButton(
          icon: CupertinoIcons.xmark,
          semanticLabel: AuraStrings.dismiss,
          color: context.auraColors.textSecondary,
          iconSize: AuraSizes.iconMd,
          onPressed: onDismiss,
        ),
      ),
      ImportIdle() => const SizedBox.shrink(),
    };
  }

  static List<String> _reportLines(ImportReport report) {
    return [
      if (report.imported.isNotEmpty)
        AuraStrings.importAdded(report.imported.length)
      else
        AuraStrings.importNothingAdded,
      if (report.duplicates > 0)
        AuraStrings.importDuplicates(report.duplicates),
      if (report.failed > 0) ...[
        AuraStrings.importFailed(report.failed),
        AuraStrings.importUnsupportedHint,
      ],
    ];
  }
}
