import 'package:flutter/material.dart';

/// The two-family type scale.
///
/// Sora carries headings and numbers; Inter carries everything a student reads
/// in a sentence. Both are bundled, so a first launch on a metered connection
/// does not wait for a font request.
///
/// The bundled files are variable fonts, one per family. Every style therefore
/// sets `fontVariations` alongside `fontWeight`: the weight is the intent, and
/// the variation is how the variable font is actually told to honour it. Without
/// the pair, a heading would match a "bold" font entry and still render at the
/// file's default instance.
abstract final class AppTypography {
  static const String bodyFamily = 'Inter';
  static const String displayFamily = 'Sora';

  static List<FontVariation> _wght(int weight) => [
    FontVariation('wght', weight.toDouble()),
  ];

  static TextStyle _display({
    required double size,
    required int weight,
    required double height,
    required double spacing,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      height: height,
      fontWeight: _fontWeight(weight),
      fontVariations: _wght(weight),
      letterSpacing: spacing,
    );
  }

  static TextStyle _body({
    required double size,
    required int weight,
    required double height,
    double spacing = 0,
  }) {
    return TextStyle(
      fontFamily: bodyFamily,
      fontSize: size,
      height: height,
      fontWeight: _fontWeight(weight),
      fontVariations: _wght(weight),
      letterSpacing: spacing,
    );
  }

  static FontWeight _fontWeight(int weight) {
    return switch (weight) {
      <= 100 => FontWeight.w100,
      <= 200 => FontWeight.w200,
      <= 300 => FontWeight.w300,
      <= 400 => FontWeight.w400,
      <= 500 => FontWeight.w500,
      <= 600 => FontWeight.w600,
      <= 700 => FontWeight.w700,
      <= 800 => FontWeight.w800,
      _ => FontWeight.w900,
    };
  }

  /// The screen-level headline. One per screen.
  static TextStyle get display => _display(
    size: 30,
    weight: 800,
    height: 1.2,
    spacing: -0.8,
  );

  /// The base text theme handed to [ThemeData].
  ///
  /// Sizes are deliberately a little larger than Material's defaults. The beta
  /// targets shared handsets in daylight, and 14pt body text is the floor at
  /// which the copy stays readable on a cheap panel.
  static TextTheme get textTheme => TextTheme(
    displayLarge: _display(size: 34, weight: 800, height: 1.15, spacing: -1),
    displayMedium: _display(size: 30, weight: 800, height: 1.2, spacing: -0.8),
    displaySmall: _display(size: 26, weight: 800, height: 1.2, spacing: -0.6),
    headlineLarge: _display(size: 24, weight: 800, height: 1.25, spacing: -0.5),
    headlineMedium: _display(size: 20, weight: 700, height: 1.3, spacing: -0.3),
    headlineSmall: _display(size: 17, weight: 700, height: 1.3, spacing: -0.2),
    titleLarge: _body(size: 17, weight: 700, height: 1.3),
    titleMedium: _body(size: 15, weight: 700, height: 1.35),
    titleSmall: _body(size: 13, weight: 600, height: 1.4),
    bodyLarge: _body(size: 15, weight: 400, height: 1.45),
    bodyMedium: _body(size: 14, weight: 400, height: 1.45),
    bodySmall: _body(size: 12, weight: 400, height: 1.4),
    labelLarge: _body(size: 13, weight: 700, height: 1.3, spacing: 0.1),
    labelMedium: _body(size: 11, weight: 700, height: 1.3, spacing: 0.2),
    labelSmall: _body(size: 10, weight: 600, height: 1.3, spacing: 0.2),
  );
}
