import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/design_system/design_system.dart';

import '../../helpers/aura_test_app.dart';

void main() {
  group('AuraButton', () {
    testWidgets('calls onPressed once per tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        auraTestScreen(AuraButton(label: 'Go', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Go'));

      expect(taps, 1);
    });

    testWidgets('disabled button is announced as a disabled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        auraTestScreen(const AuraButton(label: 'Go', onPressed: null)),
      );

      expect(
        tester.getSemantics(find.byType(AuraPressable)),
        isSemantics(
          label: 'Go',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('loading keeps the size, shows a spinner, ignores taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        auraTestScreen(AuraButton(label: 'Save', onPressed: () => taps++)),
      );
      final idleSize = tester.getSize(find.byType(AuraButton));

      await tester.pumpWidget(
        auraTestScreen(
          AuraButton(label: 'Save', isLoading: true, onPressed: () => taps++),
        ),
      );
      await tester.tap(find.byType(AuraButton));

      expect(tester.getSize(find.byType(AuraButton)), idleSize);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(taps, 0);
    });
  });

  group('AuraIconButton', () {
    testWidgets('has a 44pt hit area and announces label and toggle state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        auraTestScreen(
          AuraIconButton(
            icon: CupertinoIcons.heart,
            semanticLabel: 'Like',
            toggled: false,
            onPressed: () {},
          ),
        ),
      );

      final size = tester.getSize(find.byType(AuraIconButton));
      expect(size.width, greaterThanOrEqualTo(AuraSizes.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(AuraSizes.minTouchTarget));
      expect(
        tester.getSemantics(find.byType(AuraIconButton)),
        isSemantics(
          label: 'Like',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );
      handle.dispose();
    });
  });

  group('AuraSectionHeader', () {
    testWidgets('hides the action when there is nothing to do', (tester) async {
      await tester.pumpWidget(
        auraTestScreen(const AuraSectionHeader(title: 'Section')),
      );

      expect(find.byIcon(CupertinoIcons.chevron_right), findsNothing);
    });

    testWidgets('shows and triggers the action when provided', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        auraTestScreen(
          AuraSectionHeader(
            title: 'Section',
            actionLabel: 'All',
            onAction: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('All'));

      expect(taps, 1);
    });
  });

  group('AuraArtwork', () {
    testWidgets('shows the placeholder when there is no image', (tester) async {
      await tester.pumpWidget(auraTestScreen(const AuraArtwork(size: 48)));

      expect(find.byIcon(CupertinoIcons.music_note), findsOneWidget);
    });
  });

  group('AuraListTile', () {
    testWidgets('active row is announced as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        auraTestScreen(
          AuraListTile(title: 'Track', isActive: true, onPressed: () {}),
        ),
      );

      expect(
        tester.getSemantics(find.byType(AuraPressable)),
        isSemantics(label: 'Track', hasSelectedState: true, isSelected: true),
      );
      handle.dispose();
    });
  });

  group('AuraMotion', () {
    Future<(Duration, Duration)> resolve(
      WidgetTester tester, {
      required bool reduceMotion,
    }) async {
      late Duration spatial;
      late Duration fade;
      await tester.pumpWidget(
        auraTestScreen(
          Builder(
            builder: (context) {
              spatial = AuraMotion.spatial(context, AuraMotion.slow);
              fade = AuraMotion.fade(context, AuraMotion.slow);
              return const SizedBox();
            },
          ),
          reduceMotion: reduceMotion,
        ),
      );
      return (spatial, fade);
    }

    testWidgets('keeps durations when Reduce Motion is off', (tester) async {
      final (spatial, fade) = await resolve(tester, reduceMotion: false);
      expect(spatial, AuraMotion.slow);
      expect(fade, AuraMotion.slow);
    });

    testWidgets('drops spatial motion and shortens fades when on', (
      tester,
    ) async {
      final (spatial, fade) = await resolve(tester, reduceMotion: true);
      expect(spatial, Duration.zero);
      expect(fade, AuraMotion.fast);
    });
  });
}
