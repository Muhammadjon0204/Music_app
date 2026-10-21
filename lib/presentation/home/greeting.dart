import 'package:music_app/presentation/l10n/aura_strings.dart';

/// Morning 05–11, day 12–16, evening 17–22, night 23–04.
String greetingFor(DateTime time) => switch (time.hour) {
  >= 5 && < 12 => AuraStrings.greetingMorning,
  >= 12 && < 17 => AuraStrings.greetingDay,
  >= 17 && < 23 => AuraStrings.greetingEvening,
  _ => AuraStrings.greetingNight,
};
