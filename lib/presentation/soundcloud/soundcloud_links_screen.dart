import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_providers.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_page.dart';
import 'package:music_app/presentation/library/mixed_track_list.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

/// The SoundCloud links the user saved. Only the URLs are stored; titles
/// and covers come from SoundCloud each session.
class SoundCloudLinksScreen extends ConsumerWidget {
  const SoundCloudLinksScreen({super.key});

  /// SoundCloud's own Discover page. It is a page of their site, not a
  /// track or playlist, so it opens outside the app; links found there can
  /// be added here.
  static final discoverUrl = Uri.parse('https://m.soundcloud.com/discover');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(soundCloudLinksProvider).value;
    final add = AuraIconButton(
      icon: CupertinoIcons.add,
      semanticLabel: AuraStrings.addLink,
      color: context.auraColors.accentText,
      onPressed: () => unawaited(addSoundCloudLink(context, ref)),
    );

    return LibraryPage(
      title: AuraStrings.savedLinks,
      trailing: add,
      slivers: [
        SliverToBoxAdapter(
          child: AuraListTile(
            title: AuraStrings.discoverMusic,
            subtitle: AuraStrings.discoverMusicHint,
            leading: Icon(
              CupertinoIcons.compass,
              color: context.auraColors.accentText,
            ),
            trailing: Icon(
              CupertinoIcons.arrow_up_right,
              size: AuraSizes.iconSm,
              color: context.auraColors.textSecondary,
            ),
            onPressed: () => unawaited(_openDiscover(context, ref)),
          ),
        ),
        if (links == null)
          const SliverToBoxAdapter(child: LoadingRow())
        else if (links.isEmpty)
          LibraryEmptySliver(
            icon: CupertinoIcons.cloud,
            title: AuraStrings.soundCloudEmptyTitle,
            message: AuraStrings.soundCloudEmptyMessage,
            primaryAction: AuraStateAction(
              label: AuraStrings.addLink,
              onPressed: () => unawaited(addSoundCloudLink(context, ref)),
            ),
          )
        else
          SliverList.builder(
            itemCount: links.length,
            itemBuilder: (context, i) => _LinkTile(link: links[i]),
          ),
      ],
    );
  }
}

Future<void> _openDiscover(BuildContext context, WidgetRef ref) async {
  final opened =
      await ref
          .read(externalLinkOpenerProvider)
          ?.open(SoundCloudLinksScreen.discoverUrl) ??
      false;
  if (!opened && context.mounted) {
    await showMessage(
      context,
      title: AuraStrings.linkOpenFailed,
      message: AuraStrings.failureFeatureUnavailableMessage,
    );
  }
}

class _LinkTile extends ConsumerWidget {
  const _LinkTile({required this.link});

  final SoundCloudLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(soundCloudInfoProvider(link));
    final value = info.value;
    final path = link.url.path.substring(1);
    return AuraListTile(
      title: value?.title ?? path,
      subtitle: info.hasError
          ? AuraStrings.soundCloudUnavailable
          : value?.author ?? AuraStrings.unknownArtist,
      leading: AuraArtwork(
        size: AuraSizes.artworkListTile,
        image: artworkImage(ref, value?.artwork),
        placeholderSeed: path,
      ),
      trailing: AuraIconButton(
        icon: CupertinoIcons.ellipsis,
        semanticLabel: '${AuraStrings.more}: ${value?.title ?? path}',
        color: context.auraColors.textSecondary,
        onPressed: () => unawaited(_menu(context, ref)),
      ),
      onPressed: () =>
          unawaited(context.push(AppRoutes.soundCloudPlayer(link.url))),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final remove = await showActionSheet<bool>(
      context,
      actions: [
        const SheetAction(AuraStrings.openOriginal, false),
        const SheetAction(AuraStrings.removeLink, true, destructive: true),
      ],
    );
    if (remove == null || !context.mounted) return;
    if (!remove) {
      final opened =
          await ref.read(externalLinkOpenerProvider)?.open(link.url) ?? false;
      if (!opened && context.mounted) {
        await showMessage(
          context,
          title: AuraStrings.linkOpenFailed,
          message: AuraStrings.failureFeatureUnavailableMessage,
        );
      }
      return;
    }
    final result = await ref.read(soundCloudLinkStoreProvider)?.remove(link);
    if (result case Err(:final failure) when context.mounted) {
      await showFailure(context, failure);
    }
  }
}

/// Asks for a SoundCloud link, saves it and opens its player.
Future<void> addSoundCloudLink(BuildContext context, WidgetRef ref) async {
  final link = await showCupertinoDialog<SoundCloudLink>(
    context: context,
    builder: (_) => const _AddLinkDialog(),
  );
  if (link == null || !context.mounted) return;
  final store = ref.read(soundCloudLinkStoreProvider);
  if (store == null) return;
  final result = await store.add(link);
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      unawaited(context.push(AppRoutes.soundCloudPlayer(link.url)));
    case Err(:final failure):
      await showFailure(context, failure);
  }
}

class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _text = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final link = SoundCloudLink.parse(_text.text);
    if (link == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(link);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text(AuraStrings.addLink),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              controller: _text,
              autofocus: true,
              placeholder: AuraStrings.soundCloudLinkHint,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _submit(),
            ),
            if (_invalid) ...[
              const SizedBox(height: 8),
              const Text(AuraStrings.soundCloudLinkInvalid),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AuraStrings.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text(AuraStrings.add),
        ),
      ],
    );
  }
}
