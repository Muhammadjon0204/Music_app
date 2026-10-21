/// Spacing on a 4-point grid.
abstract final class AuraSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Horizontal inset of screen content from the display edge.
  static const double screenHorizontal = 20;

  /// Vertical gap between content sections.
  static const double sectionGap = 32;
}

abstract final class AuraRadii {
  static const double xs = 4;

  /// List-row artwork.
  static const double sm = 8;

  /// Cards, carousel artwork, inputs.
  static const double md = 12;

  /// Banners and large artwork.
  static const double lg = 16;

  /// Sheets.
  static const double xl = 24;

  /// Stadium shape for buttons and chips.
  static const double pill = 999;
}

abstract final class AuraSizes {
  /// Apple HIG minimum hit area.
  static const double minTouchTarget = 44;

  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 28;

  static const double buttonMedium = 44;
  static const double buttonLarge = 52;

  static const double artworkListTile = 48;
  static const double artworkCard = 128;

  static const double listTileMinHeight = 64;
  static const double listTileTrailingMaxWidth = 96;
  static const double stateIcon = 64;

  static const double playButtonLarge = 72;

  static const double miniPlayerHeight = 64;

  /// Tab bar content height, excluding the bottom safe area.
  static const double tabBarHeight = 56;
}

abstract final class AuraLayout {
  /// Content is centered and capped at this width on wide screens
  /// (landscape, iPad) so lines and rows stay readable.
  static const double maxContentWidth = 640;

  static const double messageMaxWidth = 400;
}
