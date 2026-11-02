import 'package:flutter/widgets.dart';

/// Spacing and radius scale for the client.
///
/// Gaps are declared as constants rather than inline literals so that vertical
/// rhythm stays consistent between screens. The scale is a 4pt grid, which
/// divides evenly into both the compact phone layouts the pilot targets and
/// tablet widths.
abstract final class AppDimens {
  /// Extra extra small: 2pt. Hairline separation only.
  static const double xxs = 2;

  /// Extra small: 4pt. Between an icon and its label.
  static const double xs = 4;

  /// Small: 8pt. Default gap inside a component.
  static const double sm = 8;

  /// Medium: 12pt. Default gap between components.
  static const double md = 12;

  /// Large: 16pt. Default gap inside a card.
  static const double lg = 16;

  /// Large plus: 20pt. Gap between a card's title block and its body.
  static const double lgPlus = 20;

  /// Extra large: 24pt. Between groups of related content.
  static const double xl = 24;

  /// Extra extra large: 32pt. Between distinct sections.
  static const double xxl = 32;

  /// Extra extra extra large: 40pt. Above a screen's first section.
  static const double xxxl = 40;

  /// Corner radius for small components such as inline badges.
  static const double radiusSm = 4;

  /// Corner radius for cards and sheets. The default.
  static const double radiusMd = 12;

  /// Corner radius for dialogs and modal surfaces.
  static const double radiusLg = 20;

  /// Corner radius of a card or a composer surface. Campus Energy is soft.
  static const double radiusCard = 24;

  /// Corner radius of a button, an input, and a chip-shaped control.
  static const double radiusButton = 14;

  /// Corner radius of the top of a modal sheet.
  static const double radiusSheet = 28;

  /// Fully rounded, for a status pill.
  static const double radiusPill = 999;

  /// Height of the primary action on a screen.
  static const double buttonHeight = 52;

  /// Height of a secondary action, including the one beside a primary action.
  static const double buttonHeightSmall = 44;

  /// Minimum square of a tappable icon, per the accessibility floor.
  static const double tapTarget = 48;

  /// Height of the bottom navigation bar.
  static const double navBarHeight = 64;

  /// Width of a hairline divider.
  static const double hairline = 1;

  /// Standard horizontal padding applied to every screen.
  ///
  /// Wider than the previous 16pt. The extra 8pt is what lets a card's own
  /// 24pt radius read as a card instead of as the edge of the screen.
  static const double screenPadding = xl;

  /// Maximum width for a readable column on tablets and the web target.
  ///
  /// The pilot is mobile-first, so this only prevents line lengths becoming
  /// unreadable when the same widgets render wide.
  static const double maxContentWidth = 640;

  /// Maximum splash animation size on tablets and web.
  static const double splashAnimationMax = 320;

  /// Portion of the available splash viewport used by the animation.
  static const double splashAnimationFraction = 0.55;

  /// Maximum width of the sign-in animation.
  static const double signInAnimationMax = 175;

  /// Maximum bounds of the sign-up animation.
  static const double signUpAnimationMaxWidth = 195;
  static const double signUpAnimationMaxHeight = 155;

  /// The lift under a card.
  ///
  /// Deliberately soft and warm rather than grey: on a cream page a neutral
  /// shadow reads as dirt. Kept as one constant so every raised surface in the
  /// app casts the same shadow.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1214142B),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  /// The same lift, for a card that is being pressed.
  static const List<BoxShadow> cardShadowPressed = [
    BoxShadow(
      color: Color(0x0A14142B),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];
}
