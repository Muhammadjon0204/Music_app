import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/design_system/design_system.dart';

import '../helpers/aura_test_app.dart';

const longText =
    'Очень длинный текст, который не помещается ни в одну разумную ширину';

/// An image that always fails to load.
class _BrokenImage extends ImageProvider<_BrokenImage> {
  const _BrokenImage();

  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _BrokenImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('broken image')),
  );
}

// 1×1 transparent PNG.
final _pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget narrow(Widget child, {double width = 200}) =>
    SizedBox(width: width, child: child);

void main() {
  group('No overflow with long text at the largest text size', () {
    for (final (name, widget) in [
      (
        'expanded button with icon',
        AuraButton(
          label: longText,
          icon: CupertinoIcons.play_fill,
          expand: true,
          onPressed: () {},
        ),
      ),
      ('compact button', AuraButton(label: longText, onPressed: () {})),
      (
        'list tile with trailing',
        AuraListTile(
          title: longText,
          subtitle: longText,
          leading: const AuraArtwork(size: 48),
          trailing: const Text('12:34'),
          onPressed: () {},
        ),
      ),
      (
        'media card',
        AuraMediaCard(title: longText, subtitle: longText, onPressed: () {}),
      ),
      (
        'section header with action',
        AuraSectionHeader(title: longText, actionLabel: 'Все', onAction: () {}),
      ),
      (
        'search field button',
        AuraSearchField.button(placeholder: longText, onPressed: () {}),
      ),
    ]) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(
          auraTestScreen(narrow(widget, width: 240), textScale: 3),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('empty state in a tiny box scrolls instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      auraTestScreen(
        SizedBox(
          height: 120,
          width: 300,
          child: AuraEmptyState(
            icon: CupertinoIcons.music_note,
            title: longText,
            message: longText,
            primaryAction: AuraStateAction(label: 'Действие', onPressed: () {}),
          ),
        ),
        textScale: 3,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsOneWidget);
  });

  testWidgets('error state inside a list takes its natural height', (
    tester,
  ) async {
    await tester.pumpWidget(
      auraTestApp(
        Scaffold(
          body: ListView(
            children: const [
              AuraErrorState(title: 'Ошибка', message: longText),
              Text('после ошибки'),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('после ошибки'), findsOneWidget);
  });

  group('AuraArtwork', () {
    testWidgets('broken image keeps the placeholder and reports nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        auraTestScreen(const AuraArtwork(size: 96, image: _BrokenImage())),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(CupertinoIcons.music_note), findsOneWidget);
    });

    testWidgets('valid image renders above the placeholder', (tester) async {
      await tester.pumpWidget(
        auraTestScreen(AuraArtwork(size: 96, image: MemoryImage(_pngBytes))),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.music_note), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AuraPressable', () {
    Finder opacityOf(Finder pressable) =>
        find.descendant(of: pressable, matching: find.byType(AnimatedOpacity));

    double opacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(opacityOf(find.byType(AuraPressable)).first)
        .opacity;

    Widget box({VoidCallback? onPressed}) => AuraPressable(
      onPressed: onPressed,
      feedback: AuraPressFeedback.opacity,
      child: const SizedBox(width: 120, height: 120),
    );

    testWidgets('dims while pressed; dragging away cancels the tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(auraTestScreen(box(onPressed: () => taps++)));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AuraPressable)),
      );
      await tester.pump();
      expect(opacity(tester), lessThan(1));

      await gesture.moveBy(const Offset(0, 300));
      await gesture.up();
      await tester.pump(AuraMotion.fast);

      expect(opacity(tester), 1);
      expect(taps, 0);
    });

    testWidgets('disabled does not react to presses', (tester) async {
      await tester.pumpWidget(auraTestScreen(box()));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AuraPressable)),
      );
      await tester.pump();
      expect(opacity(tester), 1);
      await gesture.up();
    });

    testWidgets('becoming disabled mid-press resets the pressed look', (
      tester,
    ) async {
      await tester.pumpWidget(auraTestScreen(box(onPressed: () {})));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AuraPressable)),
      );
      await tester.pump();

      await tester.pumpWidget(auraTestScreen(box()));
      await tester.pump(AuraMotion.fast);
      expect(opacity(tester), 1);

      await gesture.up();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('disabled icon button is announced as disabled, keeps 44pt', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      auraTestScreen(
        const AuraIconButton(
          icon: CupertinoIcons.ellipsis,
          semanticLabel: 'Ещё',
          iconSize: 12,
          onPressed: null,
        ),
      ),
    );

    final size = tester.getSize(find.byType(AuraIconButton));
    expect(size.width, greaterThanOrEqualTo(AuraSizes.minTouchTarget));
    expect(size.height, greaterThanOrEqualTo(AuraSizes.minTouchTarget));
    expect(
      tester.getSemantics(find.byType(AuraIconButton)),
      isSemantics(label: 'Ещё', isButton: true, isEnabled: false),
    );
    handle.dispose();
  });

  testWidgets('search button announces its placeholder once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      auraTestScreen(
        AuraSearchField.button(placeholder: 'Поиск', onPressed: () {}),
      ),
    );

    expect(
      tester.getSemantics(find.byType(AuraPressable)),
      isSemantics(label: 'Поиск', isButton: true),
    );
    handle.dispose();
  });

  testWidgets('tab bar reports taps and shows the selected icon', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      auraTestScreen(
        AuraTabBar(
          currentIndex: 1,
          onSelected: selected.add,
          items: const [
            AuraTabItem(
              icon: CupertinoIcons.house,
              selectedIcon: CupertinoIcons.house_fill,
              label: 'A',
            ),
            AuraTabItem(
              icon: CupertinoIcons.music_albums,
              selectedIcon: CupertinoIcons.music_albums_fill,
              label: 'B',
            ),
          ],
        ),
      ),
    );

    expect(find.byIcon(CupertinoIcons.music_albums_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.house), findsOneWidget);
    await tester.tap(find.text('A'));
    await tester.tap(find.text('B'));
    expect(selected, [0, 1]);
  });

  group('AuraStateSwitcher', () {
    Widget switcher(bool loaded, {bool reduceMotion = false}) => auraTestScreen(
      AuraStateSwitcher(
        child: loaded
            ? const Text('content', key: ValueKey('c'))
            : const Text('loading', key: ValueKey('l')),
      ),
      reduceMotion: reduceMotion,
    );

    testWidgets('cross-fades between states', (tester) async {
      await tester.pumpWidget(switcher(false));
      await tester.pumpWidget(switcher(true));
      await tester.pump(AuraMotion.fast);
      expect(find.text('loading'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('loading'), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('Reduce Motion shortens the change to a quick fade', (
      tester,
    ) async {
      await tester.pumpWidget(switcher(false, reduceMotion: true));
      await tester.pumpWidget(switcher(true, reduceMotion: true));
      await tester.pump(AuraMotion.fast + const Duration(milliseconds: 1));

      expect(find.text('loading'), findsNothing);
    });
  });

  group('Theme', () {
    testWidgets('missing AuraTheme fails with a clear message', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        () => captured.auraColors,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('AuraTheme'),
          ),
        ),
      );
    });

    test('color tokens interpolate between themes', () {
      final lighter = AuraColors.dark.copyWith(
        background: const Color(0xFFFFFFFF),
      );
      expect(
        AuraColors.dark.lerp(lighter, 0).background,
        AuraColors.dark.background,
      );
      expect(
        AuraColors.dark.lerp(lighter, 1).background,
        const Color(0xFFFFFFFF),
      );
      expect(AuraColors.dark.lerp(null, 0.5), same(AuraColors.dark));
    });
  });
}
