import 'package:flutter/material.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_colors.dart';
import 'package:peerpass/core/theme/app_palette.dart';

/// The meaning a pill carries.
///
/// The tone is semantic, not decorative: a caller asks for "this is verified"
/// rather than for "green", so the palette can change without every badge in
/// the app needing to be found and repainted.
enum AppPillTone {
  /// Verified, completed, counted.
  success,

  /// Rising tutor, attention, pending.
  warning,

  /// Live, urgent, cancelled, or a destructive consequence.
  danger,

  /// Course, category, or a neutral piece of context.
  info,

  /// Metadata with no meaning of its own, such as a year of study.
  neutral,
}

/// A small status label.
class AppPill extends StatelessWidget {
  const AppPill(
    this.label, {
    this.tone = AppPillTone.neutral,
    this.icon,
    this.isCompact = false,
    super.key,
  });

  final String label;
  final AppPillTone tone;
  final IconData? icon;

  /// Drops the horizontal padding for a pill inside a dense row.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (background, foreground) = _colors(palette);
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: foreground,
      fontSize: isCompact ? 9 : 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? AppDimens.sm : 10,
          vertical: isCompact ? 3 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final glyph?) ...[
              Icon(glyph, size: isCompact ? 11 : 13, color: foreground),
              const SizedBox(width: AppDimens.xs),
            ],
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }

  (Color, Color) _colors(AppPalette palette) {
    return switch (tone) {
      AppPillTone.success => (palette.mintTint, palette.onMintTint),
      AppPillTone.warning => (palette.amberTint, palette.onAmberTint),
      AppPillTone.danger => (palette.coralTint, palette.onCoralTint),
      AppPillTone.info => (palette.indigoTint, palette.onIndigoTint),
      AppPillTone.neutral => (palette.soft, palette.muted),
    };
  }
}

/// The verified tick that sits on a tutor's avatar.
///
/// Drawn from the palette rather than from an asset so it keeps its contrast on
/// both themes.
class AppVerifiedDot extends StatelessWidget {
  const AppVerifiedDot({this.size = 14, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.mint,
        shape: BoxShape.circle,
        border: Border.all(color: palette.card, width: size * 0.14),
      ),
      child: Icon(
        Icons.check_rounded,
        size: size * 0.66,
        color: AppColors.white,
      ),
    );
  }
}
