import 'package:flutter/material.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_palette.dart';

/// A raised surface: the basic unit of the Campus Energy layout.
///
/// A card is white on cream, 24pt rounded, with one soft shadow. It has no
/// border on the page because the shadow already separates it; a border is only
/// used when the card sits on another white surface, where the shadow has
/// nothing to fall on. [outlined] covers that case explicitly rather than
/// leaving every screen to guess.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.lgPlus),
    this.onTap,
    this.tint,
    this.outlined = false,
    this.radius = AppDimens.radiusCard,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  final Widget child;

  /// Inner padding. Set to [EdgeInsets.zero] for a card that draws to its edge,
  /// such as one with a full-bleed header strip.
  final EdgeInsetsGeometry padding;

  /// Makes the whole card tappable. The ripple is clipped to the card radius.
  final VoidCallback? onTap;

  /// Replaces the card colour. Used for a tinted card, such as a live session
  /// in coral or a success notice in mint. Ignored when [onTap] is null? No:
  /// tint applies either way.
  final Color? tint;

  /// Draws a hairline instead of relying on the shadow, for a card on white.
  final bool outlined;

  final double radius;

  /// Read out by a screen reader when the card is tappable as a whole.
  final String? semanticLabel;

  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final decoration = BoxDecoration(
      color: tint ?? palette.card,
      borderRadius: BorderRadius.circular(radius),
      border: outlined ? Border.all(color: palette.line) : null,
      boxShadow: tint == null && !outlined ? AppDimens.cardShadow : null,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(
        decoration: decoration,
        child: Semantics(label: semanticLabel, child: content),
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      // A card given a label is describing itself as one thing. Without this,
      // the reader would announce the label and then every word inside it.
      excludeSemantics: semanticLabel != null,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: clipBehavior,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: content,
          ),
        ),
      ),
    );
  }
}
