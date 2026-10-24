import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/app/router.dart';
import 'package:music_app/application/settings/settings_providers.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/settings/theme_choices.dart';

class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  static const _locale = Locale('ru');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeChoiceProvider).colors;
    final isLight = AuraTheme.brightnessOf(colors) == Brightness.light;
    return MaterialApp.router(
      title: AuraStrings.appName,
      debugShowCheckedModeBanner: false,
      // The theme the user picked; switching cross-fades the colors.
      theme: AuraTheme.fromColors(colors),
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      // Status bar icons that stay visible on the theme's background.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        child: child!,
      ),
    );
  }
}
