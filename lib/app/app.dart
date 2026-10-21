import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/app/router.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  static const _locale = Locale('ru');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AuraStrings.appName,
      debugShowCheckedModeBanner: false,
      // Dark only for now; a light theme can be added via AuraColors.
      theme: AuraTheme.dark(),
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
