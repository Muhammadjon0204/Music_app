import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_app/presentation/common/duration_format.dart';
import 'package:music_app/presentation/design_system/design_system.dart';

/// Development-only catalog of design system components. Not a product
/// screen: it holds no real music data and is replaced as the home screen in
/// Phase 4. All sample texts are placeholders.
class DesignSystemGalleryScreen extends StatefulWidget {
  const DesignSystemGalleryScreen({super.key});

  static const endMarker = 'Конец каталога';

  @override
  State<DesignSystemGalleryScreen> createState() =>
      _DesignSystemGalleryScreenState();
}

class _DesignSystemGalleryScreenState extends State<DesignSystemGalleryScreen> {
  String _lastAction = '—';
  bool _liked = false;
  bool _switchOn = true;
  bool _showContent = false;

  void _log(String action) => setState(() => _lastAction = action);

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    final reduced = AuraMotion.isReduced(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AuraLayout.maxContentWidth,
            ),
            child: ListView(
              padding: EdgeInsets.only(
                top: AuraSpacing.lg,
                bottom: AuraSpacing.huge + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _Padded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('Дизайн-система', style: text.largeTitle),
                      ),
                      const SizedBox(height: AuraSpacing.xs),
                      Text(
                        'Временный каталог компонентов (Phase 3). '
                        'Не экран приложения, данные — заглушки.',
                        style: text.subhead,
                      ),
                      const SizedBox(height: AuraSpacing.sm),
                      Text(
                        'Reduce Motion: ${reduced ? 'включено' : 'выключено'}'
                        ' · Последнее действие: $_lastAction',
                        style: text.footnote,
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Цвета',
                  child: _Padded(
                    child: Wrap(
                      spacing: AuraSpacing.md,
                      runSpacing: AuraSpacing.md,
                      children: [
                        _Swatch('background', colors.background),
                        _Swatch('surface', colors.surface),
                        _Swatch('elevated', colors.surfaceElevated),
                        _Swatch('border', colors.borderStrong),
                        _Swatch('text', colors.textPrimary),
                        _Swatch('text 2', colors.textSecondary),
                        _Swatch('text 3', colors.textTertiary),
                        _Swatch('accent', colors.accent),
                        _Swatch('accent text', colors.accentText),
                        _Swatch('violet', colors.accentSecondary),
                        _Swatch('error', colors.error),
                      ],
                    ),
                  ),
                ),
                _Section(
                  title: 'Типографика',
                  child: _Padded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Large Title 30', style: text.largeTitle),
                        Text('Title 1 — 24', style: text.title1),
                        Text('Title 2 — 20', style: text.title2),
                        Text('Title 3 — 18', style: text.title3),
                        Text('Headline — название трека', style: text.headline),
                        Text('Body — обычный текст описания', style: text.body),
                        Text('Subhead — исполнитель', style: text.subhead),
                        Text('Footnote — подписи', style: text.footnote),
                        Text('Caption — вкладки', style: text.caption),
                        Text('Numeric 3:46 · 12:05', style: text.numeric),
                      ],
                    ),
                  ),
                ),
                _Section(
                  title: 'Кнопки',
                  child: _Padded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AuraSpacing.md,
                          runSpacing: AuraSpacing.md,
                          children: [
                            AuraButton(
                              label: 'Primary',
                              icon: CupertinoIcons.play_fill,
                              onPressed: () => _log('Primary'),
                            ),
                            AuraButton(
                              label: 'Secondary',
                              variant: AuraButtonVariant.secondary,
                              onPressed: () => _log('Secondary'),
                            ),
                            const AuraButton(
                              label: 'Disabled',
                              onPressed: null,
                            ),
                            AuraButton(
                              label: 'Loading',
                              isLoading: true,
                              onPressed: () => _log('Loading'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AuraSpacing.lg),
                        AuraButton(
                          label: 'Large, full width',
                          icon: CupertinoIcons.arrow_down_to_line,
                          size: AuraButtonSize.large,
                          expand: true,
                          onPressed: () => _log('Large'),
                        ),
                        const SizedBox(height: AuraSpacing.lg),
                        Row(
                          children: [
                            AuraIconButton(
                              icon: _liked
                                  ? CupertinoIcons.heart_fill
                                  : CupertinoIcons.heart,
                              color: _liked ? colors.accentText : null,
                              semanticLabel: 'Нравится',
                              toggled: _liked,
                              onPressed: () => setState(() => _liked = !_liked),
                            ),
                            AuraIconButton(
                              icon: CupertinoIcons.arrow_down_to_line,
                              semanticLabel: 'Пример иконки',
                              onPressed: () => _log('Icon'),
                            ),
                            const AuraIconButton(
                              icon: CupertinoIcons.ellipsis,
                              semanticLabel: 'Недоступно',
                              onPressed: null,
                            ),
                            const SizedBox(width: AuraSpacing.sm),
                            AuraIconButton.filled(
                              icon: CupertinoIcons.play_fill,
                              semanticLabel: 'Пример круглой кнопки',
                              diameter: AuraSizes.playButtonLarge,
                              iconSize: AuraSizes.iconXl,
                              onPressed: () => _log('Round'),
                            ),
                            const Spacer(),
                            Switch.adaptive(
                              value: _switchOn,
                              onChanged: (v) => setState(() => _switchOn = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _Section(
                  title: 'Обложки',
                  child: _Padded(
                    child: Wrap(
                      spacing: AuraSpacing.lg,
                      runSpacing: AuraSpacing.lg,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: const [
                        AuraArtwork(
                          size: AuraSizes.artworkListTile,
                          placeholderSeed: 'a',
                        ),
                        AuraArtwork(
                          size: 72,
                          placeholderSeed: 'bb',
                          shape: AuraArtworkShape.circle,
                        ),
                        AuraArtwork(
                          size: 96,
                          placeholderSeed: 'c',
                          borderRadius: AuraRadii.md,
                        ),
                        AuraArtwork(
                          size: 128,
                          placeholderSeed: 'dd',
                          borderRadius: AuraRadii.lg,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AuraSpacing.sectionGap),
                AuraSectionHeader(
                  title: 'Карточки',
                  actionLabel: 'Все',
                  onAction: () => _log('Все'),
                ),
                const SizedBox(height: AuraSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpacing.screenHorizontal,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 1; i <= 4; i++) ...[
                        AuraMediaCard(
                          title: 'Альбом $i',
                          subtitle: 'Исполнитель',
                          onPressed: () => _log('Альбом $i'),
                        ),
                        const SizedBox(width: AuraSpacing.md),
                      ],
                      AuraMediaCard(
                        title: 'Исполнитель',
                        circularArtwork: true,
                        onPressed: () => _log('Исполнитель'),
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Строки списка',
                  child: Column(
                    children: [
                      for (final (i, seconds) in const [226, 239, 3725].indexed)
                        AuraListTile(
                          title: 'Трек ${i + 1}',
                          subtitle: 'Исполнитель',
                          isActive: i == 1,
                          leading: AuraArtwork(
                            size: AuraSizes.artworkListTile,
                            placeholderSeed: 'track$i',
                          ),
                          trailing: i == 1
                              ? Icon(
                                  CupertinoIcons.speaker_2_fill,
                                  size: AuraSizes.iconMd,
                                  color: colors.accentText,
                                )
                              : Text(
                                  formatDuration(Duration(seconds: seconds)),
                                  style: text.numeric,
                                ),
                          onPressed: () => _log('Трек ${i + 1}'),
                        ),
                      AuraListTile(
                        title: 'Строка с переходом',
                        trailing: Icon(
                          CupertinoIcons.chevron_right,
                          size: AuraSizes.iconSm,
                          color: colors.textTertiary,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _TransitionDemoScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Загрузка',
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 96,
                        child: AuraLoadingState(
                          label: 'Загрузка…',
                          showLabel: true,
                        ),
                      ),
                      const AuraListTileSkeleton(),
                      const AuraListTileSkeleton(),
                      const SizedBox(height: AuraSpacing.lg),
                      _Padded(
                        child: AuraButton(
                          label: 'Переключить состояние',
                          variant: AuraButtonVariant.secondary,
                          onPressed: () =>
                              setState(() => _showContent = !_showContent),
                        ),
                      ),
                      SizedBox(
                        height: 80,
                        child: AuraStateSwitcher(
                          child: _showContent
                              ? AuraListTile(
                                  key: const ValueKey('content'),
                                  title: 'Контент загружен',
                                  subtitle: 'Плавная смена состояния',
                                  leading: const AuraArtwork(
                                    size: AuraSizes.artworkListTile,
                                    placeholderSeed: 'loaded',
                                  ),
                                )
                              : const AuraLoadingState(
                                  key: ValueKey('loading'),
                                  label: 'Загрузка…',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Пустое состояние',
                  child: _Framed(
                    child: AuraEmptyState(
                      icon: CupertinoIcons.cloud_download,
                      title: 'Заголовок пустого состояния',
                      message:
                          'Короткое объяснение и что можно сделать дальше.',
                      primaryAction: AuraStateAction(
                        label: 'Основное действие',
                        onPressed: () => _log('Empty: primary'),
                      ),
                      secondaryAction: AuraStateAction(
                        label: 'Вторичное',
                        onPressed: () => _log('Empty: secondary'),
                      ),
                    ),
                  ),
                ),
                _Section(
                  title: 'Ошибка',
                  child: _Framed(
                    child: AuraErrorState(
                      title: 'Не удалось загрузить',
                      message: 'Проверьте подключение и попробуйте снова.',
                      retryAction: AuraStateAction(
                        label: 'Повторить',
                        onPressed: () => _log('Повторить'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AuraSpacing.sectionGap),
                Center(
                  child: Text(
                    DesignSystemGalleryScreen.endMarker,
                    style: text.footnote,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuraSectionHeader(title: title),
          const SizedBox(height: AuraSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.screenHorizontal,
      ),
      child: child,
    );
  }
}

class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Padded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.auraColors.border),
          borderRadius: BorderRadius.circular(AuraRadii.lg),
        ),
        child: child,
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AuraRadii.md),
              border: Border.all(color: context.auraColors.border),
            ),
          ),
          const SizedBox(height: AuraSpacing.xs),
          Text(
            name,
            style: context.auraText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TransitionDemoScreen extends StatelessWidget {
  const _TransitionDemoScreen();

  @override
  Widget build(BuildContext context) {
    final text = context.auraText;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuraIconButton(
              icon: CupertinoIcons.chevron_left,
              semanticLabel: 'Назад',
              onPressed: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.all(AuraSpacing.screenHorizontal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Переход экрана', style: text.largeTitle),
                  const SizedBox(height: AuraSpacing.sm),
                  Text(
                    'iOS-переход со свайпом назад от левого края. '
                    'С Reduce Motion — плавное затухание.',
                    style: text.subhead,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
