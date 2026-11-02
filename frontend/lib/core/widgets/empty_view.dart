import 'package:flutter/material.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_palette.dart';

/// Placeholder for a screen that has nothing to show.
///
/// Distinct from a failure: an empty tutor list is a normal state, not an
/// error, and the copy differs accordingly. The icon sits in a tinted circle so
/// the screen reads as "waiting for something" rather than as a broken page.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String title;

  /// Optional explanation of what would fill this screen.
  final String? message;

  final IconData icon;

  /// Optional call to action, such as widening a search filter.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.indigoTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: palette.onIndigoTint),
            ),
            const SizedBox(height: AppDimens.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            if (message case final text?) ...[
              const SizedBox(height: AppDimens.xs),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
            if (action case final widget?) ...[
              const SizedBox(height: AppDimens.xl),
              widget,
            ],
          ],
        ),
      ),
    );
  }
}
