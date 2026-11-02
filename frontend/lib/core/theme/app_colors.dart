import 'package:flutter/material.dart';

/// The Campus Energy palette.
///
/// Brand colours are shared between light and dark. Surface colours are not:
/// a cream background in a dark room is a flash of light, which is the exact
/// failure dark mode exists to avoid. Semantic tints live on `AppPalette` so a
/// widget never has to decide which theme it is in.
abstract final class AppColors {
  // Brand -----------------------------------------------------------------
  static const Color ink = Color(0xFF14142B);
  static const Color indigo = Color(0xFF2D2A8C);
  static const Color amber = Color(0xFFFFB020);
  static const Color coral = Color(0xFFE8503F);
  static const Color mint = Color(0xFF18A77E);

  // Light surfaces --------------------------------------------------------
  static const Color cream = Color(0xFFFFF9F2);
  static const Color white = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFF6B6B85);
  static const Color line = Color(0xFFECE6DE);
  static const Color soft = Color(0xFFF7F3ED);

  static const Color coralTint = Color(0xFFFFF0ED);
  static const Color coralInk = Color(0xFF8A2A1F);
  static const Color amberTint = Color(0xFFFFF6E3);
  static const Color amberInk = Color(0xFF8A5A00);
  static const Color mintTint = Color(0xFFE8F7F1);
  static const Color mintInk = Color(0xFF0B6B4F);
  static const Color indigoTint = Color(0xFFEEEDF9);

  // Dark surfaces ---------------------------------------------------------
  static const Color darkBackground = Color(0xFF0F0F1E);
  static const Color darkCard = Color(0xFF1C1C32);
  static const Color darkSoft = Color(0xFF27273F);
  static const Color darkInk = Color(0xFFF6F2EA);
  static const Color darkMuted = Color(0xFFA5A3BA);
  static const Color darkLine = Color(0xFF32324A);

  // Brand colours lifted for dark surfaces. The base indigo is too dark to
  // carry an action on a near-black background.
  static const Color indigoOnDark = Color(0xFF8B84FF);
  static const Color coralOnDark = Color(0xFFFF7A6B);
  static const Color mintOnDark = Color(0xFF3DD9A8);

  /// Gradients used by generated avatars. Indexed by a stable hash of a name,
  /// so the same person keeps the same colours between sessions.
  static const List<List<Color>> avatarGradients = [
    [indigo, Color(0xFF6C63D9)],
    [coral, Color(0xFFF29B6D)],
    [mint, Color(0xFF5ED3B0)],
    [amber, Color(0xFFF7D06B)],
    [Color(0xFF8B5CF6), Color(0xFFC4B5FD)],
  ];
}
