import 'package:flutter/material.dart';
import 'package:peerpass/core/theme/app_colors.dart';

/// The semantic colours a component is allowed to ask for.
///
/// A widget reads `AppPalette.of(context)` instead of branching on
/// `Theme.of(context).brightness`. That keeps a dark-mode tint in one place
/// rather than in every card that needs a coral background.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.card,
    required this.soft,
    required this.ink,
    required this.muted,
    required this.line,
    required this.primary,
    required this.onPrimary,
    required this.coral,
    required this.coralTint,
    required this.onCoralTint,
    required this.amber,
    required this.amberTint,
    required this.onAmberTint,
    required this.mint,
    required this.mintTint,
    required this.onMintTint,
    required this.indigoTint,
    required this.onIndigoTint,
    required this.shadow,
  });

  final Color background;
  final Color card;
  final Color soft;
  final Color ink;
  final Color muted;
  final Color line;
  final Color primary;
  final Color onPrimary;
  final Color coral;
  final Color coralTint;
  final Color onCoralTint;
  final Color amber;
  final Color amberTint;
  final Color onAmberTint;
  final Color mint;
  final Color mintTint;
  final Color onMintTint;
  final Color indigoTint;
  final Color onIndigoTint;
  final Color shadow;

  static const AppPalette light = AppPalette(
    background: AppColors.cream,
    card: AppColors.white,
    soft: AppColors.soft,
    ink: AppColors.ink,
    muted: AppColors.muted,
    line: AppColors.line,
    primary: AppColors.indigo,
    onPrimary: AppColors.white,
    coral: AppColors.coral,
    coralTint: AppColors.coralTint,
    onCoralTint: AppColors.coralInk,
    amber: AppColors.amber,
    amberTint: AppColors.amberTint,
    onAmberTint: AppColors.amberInk,
    mint: AppColors.mint,
    mintTint: AppColors.mintTint,
    onMintTint: AppColors.mintInk,
    indigoTint: AppColors.indigoTint,
    onIndigoTint: AppColors.indigo,
    shadow: AppColors.ink,
  );

  static const AppPalette dark = AppPalette(
    background: AppColors.darkBackground,
    card: AppColors.darkCard,
    soft: AppColors.darkSoft,
    ink: AppColors.darkInk,
    muted: AppColors.darkMuted,
    line: AppColors.darkLine,
    primary: AppColors.indigoOnDark,
    onPrimary: AppColors.ink,
    coral: AppColors.coralOnDark,
    coralTint: Color(0xFF3A1F24),
    onCoralTint: Color(0xFFFFB4AA),
    amber: AppColors.amber,
    amberTint: Color(0xFF3A2C12),
    onAmberTint: Color(0xFFFFD98A),
    mint: AppColors.mintOnDark,
    mintTint: Color(0xFF123A31),
    onMintTint: Color(0xFF8CF0CF),
    indigoTint: Color(0xFF232244),
    onIndigoTint: Color(0xFFC9C5FF),
    shadow: Colors.black,
  );

  /// The palette for the current theme, falling back to light.
  ///
  /// The fallback exists for a widget pumped outside a `MaterialApp`, which is
  /// a common shape in widget tests. Returning null there would make every
  /// component require a theme wrapper just to render.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  @override
  AppPalette copyWith({
    Color? background,
    Color? card,
    Color? soft,
    Color? ink,
    Color? muted,
    Color? line,
    Color? primary,
    Color? onPrimary,
    Color? coral,
    Color? coralTint,
    Color? onCoralTint,
    Color? amber,
    Color? amberTint,
    Color? onAmberTint,
    Color? mint,
    Color? mintTint,
    Color? onMintTint,
    Color? indigoTint,
    Color? onIndigoTint,
    Color? shadow,
  }) {
    return AppPalette(
      background: background ?? this.background,
      card: card ?? this.card,
      soft: soft ?? this.soft,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      coral: coral ?? this.coral,
      coralTint: coralTint ?? this.coralTint,
      onCoralTint: onCoralTint ?? this.onCoralTint,
      amber: amber ?? this.amber,
      amberTint: amberTint ?? this.amberTint,
      onAmberTint: onAmberTint ?? this.onAmberTint,
      mint: mint ?? this.mint,
      mintTint: mintTint ?? this.mintTint,
      onMintTint: onMintTint ?? this.onMintTint,
      indigoTint: indigoTint ?? this.indigoTint,
      onIndigoTint: onIndigoTint ?? this.onIndigoTint,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralTint: Color.lerp(coralTint, other.coralTint, t)!,
      onCoralTint: Color.lerp(onCoralTint, other.onCoralTint, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberTint: Color.lerp(amberTint, other.amberTint, t)!,
      onAmberTint: Color.lerp(onAmberTint, other.onAmberTint, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      mintTint: Color.lerp(mintTint, other.mintTint, t)!,
      onMintTint: Color.lerp(onMintTint, other.onMintTint, t)!,
      indigoTint: Color.lerp(indigoTint, other.indigoTint, t)!,
      onIndigoTint: Color.lerp(onIndigoTint, other.onIndigoTint, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
