import 'package:flutter/material.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_palette.dart';

/// A section's title, with at most one action beside it.
///
/// The one-action limit is deliberate: a header with three links turns a
/// screen into a menu, and the whole point of the redesign is that a student
/// always knows the next thing to press.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    super.key,
  });

  final String title;

  /// One line under the title. Never a paragraph.
  final String? subtitle;

  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              if (subtitle case final text?) ...[
                const SizedBox(height: AppDimens.xxs),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onAction != null)
          if (actionLabel case final label?)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.sm,
                  vertical: AppDimens.xs,
                ),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(label),
            )
          else
            IconButton(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.chevron_right_rounded),
              tooltip: 'More',
              visualDensity: VisualDensity.compact,
            ),
      ],
    );
  }
}
