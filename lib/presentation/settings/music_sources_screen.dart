import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_providers.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_page.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

enum SourceStatus { connected, links, notYet, unavailable }

/// Where the music comes from, and honestly what each service allows:
/// the catalogs that really are connected (read from the registry), your
/// own files, SoundCloud by links, and why Spotify and YouTube Music are
/// not here. No sign-in button that would not work.
class MusicSourcesScreen extends ConsumerWidget {
  const MusicSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogs = ref.watch(providerRegistryProvider).all.toList();
    final soundCloud = ref.watch(soundCloudLinkStoreProvider) != null;

    return LibraryPage(
      title: AuraStrings.musicSources,
      subtitle: AuraStrings.musicSourcesHint,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.screenHorizontal,
          ),
          sliver: SliverList.list(
            children: [
              _SourceCard(
                icon: CupertinoIcons.music_note_2,
                title: AuraStrings.sourceLocal,
                status: SourceStatus.connected,
                description: AuraStrings.sourceLocalDescription,
                actionLabel: AuraStrings.tabLibrary,
                onAction: () => context.go(AppRoutes.library),
              ),
              for (final catalog in catalogs)
                _SourceCard(
                  icon: CupertinoIcons.dot_radiowaves_left_right,
                  title: catalog.displayName,
                  status: SourceStatus.connected,
                  description: catalog is AttributionRequiredProvider
                      ? AuraStrings.sourceCatalogCredited
                      : AuraStrings.sourceCatalogDescription,
                ),
              if (soundCloud)
                _SourceCard(
                  icon: CupertinoIcons.cloud,
                  title: 'SoundCloud',
                  status: SourceStatus.links,
                  description: AuraStrings.sourceSoundCloudDescription,
                  actionLabel: AuraStrings.savedLinks,
                  onAction: () => context.go(AppRoutes.librarySoundCloud),
                ),
              const _SourceCard(
                icon: CupertinoIcons.music_albums,
                title: 'Spotify',
                status: SourceStatus.notYet,
                description: AuraStrings.sourceSpotifyDescription,
              ),
              const _SourceCard(
                icon: CupertinoIcons.play_rectangle,
                title: 'YouTube Music',
                status: SourceStatus.unavailable,
                description: AuraStrings.sourceYouTubeMusicDescription,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final SourceStatus status;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    final (statusIcon, statusLabel, statusColor) = switch (status) {
      SourceStatus.connected => (
        CupertinoIcons.checkmark_circle_fill,
        AuraStrings.sourceConnected,
        colors.accentText,
      ),
      SourceStatus.links => (
        CupertinoIcons.link,
        AuraStrings.sourceByLinks,
        colors.accentText,
      ),
      SourceStatus.notYet => (
        CupertinoIcons.clock,
        AuraStrings.sourceNotYet,
        colors.textSecondary,
      ),
      SourceStatus.unavailable => (
        CupertinoIcons.nosign,
        AuraStrings.sourceUnavailable,
        colors.textSecondary,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AuraSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AuraRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
                children: [
                  AuraIconTile(icon: icon, size: 40),
                  const SizedBox(width: AuraSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(title, style: text.headline),
                        ),
                        const SizedBox(height: AuraSpacing.xxs),
                        Row(
                          children: [
                            Icon(
                              statusIcon,
                              size: AuraSizes.iconSm,
                              color: statusColor,
                            ),
                            const SizedBox(width: AuraSpacing.xs),
                            Flexible(
                              child: Text(
                                statusLabel,
                                style: text.footnote.copyWith(
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpacing.md),
            Text(description, style: text.subhead),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AuraSpacing.md),
              AuraButton(
                label: actionLabel,
                variant: AuraButtonVariant.secondary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
