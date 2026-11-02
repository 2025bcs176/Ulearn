import 'package:flutter/material.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_colors.dart';
import 'package:peerpass/core/theme/app_palette.dart';

/// The weight a button carries on a screen.
enum AppButtonVariant {
  /// Indigo. The single confirming action: accept, send, check in.
  primary,

  /// Amber. The one action a screen exists for, used at most once per screen.
  accent,

  /// Outlined indigo. A secondary action sitting beside a primary one.
  outline,

  /// Text only. A quiet action that must not compete, such as "Not this one".
  ghost,
}

/// The app's button.
///
/// Wraps the Material buttons rather than drawing a container, so focus, hover,
/// and the platform tap target all behave the way the framework intends. The
/// thing this adds is the design's own vocabulary: four variants, one height,
/// one radius, and a loading state that does not change the button's size.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isSmall = false,
    super.key,
  });

  final String label;

  /// Null disables the button. A loading button passes its own null here and
  /// sets [isLoading] instead, so the two states cannot disagree.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;

  final IconData? icon;

  /// Keeps the label in place so the button does not jump when work starts.
  final bool isLoading;

  final bool isFullWidth;

  /// Uses the secondary height. For a button beside another one.
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final height = isSmall
        ? AppDimens.buttonHeightSmall
        : AppDimens.buttonHeight;

    final child = _Label(
      label: label,
      icon: icon,
      isLoading: isLoading,
      color: _foreground(palette),
    );

    final size = Size(
      isFullWidth ? double.infinity : 0,
      height,
    );

    final effectiveOnPressed = isLoading ? null : onPressed;

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(minimumSize: size),
        child: child,
      ),
      AppButtonVariant.accent => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          minimumSize: size,
          backgroundColor: palette.amber,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: palette.amberTint,
          disabledForegroundColor: palette.onAmberTint,
        ),
        child: child,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          side: BorderSide(color: palette.primary, width: 1.4),
        ),
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(minimumSize: size),
        child: child,
      ),
    };

    return Semantics(
      // A screen reader should say "busy", not read a spinner.
      liveRegion: isLoading,
      label: isLoading ? '$label, working' : label,
      button: true,
      enabled: effectiveOnPressed != null,
      excludeSemantics: true,
      child: button,
    );
  }

  Color? _foreground(AppPalette palette) {
    return switch (variant) {
      AppButtonVariant.primary => palette.onPrimary,
      AppButtonVariant.accent => AppColors.ink,
      AppButtonVariant.outline || AppButtonVariant.ghost => palette.primary,
    };
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.color,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: color,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: color,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 20, color: color),
        if (isLoading || icon != null) const SizedBox(width: AppDimens.sm),
        // The label stays visible during loading; the spinner sits beside it.
        // Replacing the text would resize the button under the student's thumb.
        Text(label, style: textStyle),
      ],
    );
  }
}
