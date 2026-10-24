import 'package:music_app/domain/settings/app_settings.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

extension ThemeChoiceLook on ThemeChoice {
  AuraColors get colors => switch (this) {
    ThemeChoice.neon => AuraColors.dark,
    ThemeChoice.midnight => AuraColors.midnight,
    ThemeChoice.rose => AuraColors.rose,
    ThemeChoice.forest => AuraColors.forest,
  };

  String get label => switch (this) {
    ThemeChoice.neon => AuraStrings.themeNeon,
    ThemeChoice.midnight => AuraStrings.themeMidnight,
    ThemeChoice.rose => AuraStrings.themeRose,
    ThemeChoice.forest => AuraStrings.themeForest,
  };
}
