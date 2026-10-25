import 'package:flutter/cupertino.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// A genre tile: what it is called and what it searches for.
typedef Genre = ({String label, String query, IconData icon});

const searchGenres = <Genre>[
  (label: 'Поп', query: 'pop', icon: CupertinoIcons.star_fill),
  (label: 'Хип-хоп', query: 'hip hop', icon: CupertinoIcons.mic_fill),
  (label: 'Электроника', query: 'electronic', icon: CupertinoIcons.bolt_fill),
  (label: 'Рок', query: 'rock', icon: CupertinoIcons.flame_fill),
  (label: 'Lo-fi', query: 'lofi', icon: CupertinoIcons.moon_stars_fill),
  (label: 'Джаз', query: 'jazz', icon: CupertinoIcons.music_note_2),
  (label: 'Эмбиент', query: 'ambient', icon: CupertinoIcons.cloud_fill),
  (label: 'Классика', query: 'classical', icon: CupertinoIcons.music_note_list),
];

class GenreTile extends StatelessWidget {
  const GenreTile({
    super.key,
    required this.genre,
    required this.index,
    required this.onPressed,
  });

  final Genre genre;
  final int index;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final gradient =
        colors.artworkGradients[index % colors.artworkGradients.length];
    return AuraPressable(
      onPressed: onPressed,
      semanticLabel: AuraStrings.searchGenre(genre.label),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuraRadii.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
          ),
          child: Stack(
            children: [
              // A large tilted icon bleeding off the corner.
              Positioned(
                right: -10,
                bottom: -12,
                child: Transform.rotate(
                  angle: 0.35,
                  child: Icon(
                    genre.icon,
                    size: 64,
                    color: colors.textPrimary.withValues(alpha: 0.22),
                  ),
                ),
              ),
              // Keeps the label readable on every gradient.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.background.withValues(alpha: 0.35),
                        colors.background.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AuraSpacing.md),
                child: ExcludeSemantics(
                  child: Text(
                    genre.label,
                    style: context.auraText.title3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
