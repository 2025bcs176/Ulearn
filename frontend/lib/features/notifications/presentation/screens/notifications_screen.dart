import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/core/widgets/empty_view.dart';
import 'package:peerpass/core/widgets/failure_view.dart';
import 'package:peerpass/core/widgets/loading_view.dart';
import 'package:peerpass/features/notifications/data/models/notification_model.dart';
import 'package:peerpass/features/notifications/presentation/notification_links.dart';
import 'package:peerpass/features/notifications/presentation/providers/notification_providers.dart';
import 'package:peerpass/features/notifications/presentation/widgets/notification_tile.dart';

/// The signed-in user's inbox.
///
/// A list of things that happened, not a settings page. Every row opens the
/// screen that answers it, and an unread row is visibly different from one
/// already read. The tab badge is fed by the same provider, so reading here
/// clears it everywhere.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(notificationInboxProvider);
    final notifier = ref.read(notificationInboxProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if ((inbox.value?.unreadCount ?? 0) > 0)
            IconButton(
              tooltip: 'Mark all read',
              onPressed: () => unawaited(notifier.markAllRead()),
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
      ),
      body: inbox.when(
        loading: () =>
            const LoadingView(message: 'Loading your notifications…'),
        error: (error, stack) => FailureView(
          failure: failureFor(error),
          onRetry: () => unawaited(notifier.refresh()),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: state.isEmpty ? const _EmptyInbox() : _Inbox(state: state),
        ),
      ),
    );
  }
}

/// The scrollable an empty inbox uses.
///
/// A plain [EmptyView] in a `ListView` rather than an `Expanded`, so the
/// pull-to-refresh gesture still works on a screen with nothing to scroll.
class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      children: const [
        SizedBox(height: AppDimens.xxxl),
        EmptyView(
          icon: Icons.notifications_none_rounded,
          title: 'Nothing yet',
          message:
              'When a tutor answers, a session changes, or someone rates '
              'you, it lands here.',
        ),
      ],
    );
  }
}

class _Inbox extends ConsumerWidget {
  const _Inbox({required this.state});

  final NotificationInboxState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(notificationInboxProvider.notifier);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        AppDimens.md,
        AppDimens.screenPadding,
        AppDimens.xl,
      ),
      children: [
        if (state.actionFailure case final failure?) ...[
          _ActionFailureBanner(failure: failure),
          const SizedBox(height: AppDimens.md),
        ],
        for (final notification in state.items) ...[
          NotificationTile(
            notification: notification,
            onTap: () => unawaited(_open(context, ref, notification)),
          ),
          const SizedBox(height: AppDimens.md),
        ],
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.xs),
            child: AppButton(
              label: state.isLoadingMore ? 'Loading…' : 'Load older',
              variant: AppButtonVariant.outline,
              isLoading: state.isLoadingMore,
              onPressed: state.isLoadingMore
                  ? null
                  : () => unawaited(notifier.loadMore()),
            ),
          ),
      ],
    );
  }

  /// Opens the row and clears its unread state.
  ///
  /// Navigation starts before the request completes, so a slow connection does
  /// not make the tap feel broken. The read is still awaited here so a failure
  /// becomes the inbox's banner when the student comes back, rather than an
  /// unhandled future.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    final route = notificationRoute(notification);
    if (route != null) unawaited(context.push(route));
    await ref
        .read(notificationInboxProvider.notifier)
        .markRead(notification.id);
  }
}

/// Why the last action did not work, shown above the list it is about.
class _ActionFailureBanner extends StatelessWidget {
  const _ActionFailureBanner({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return AppCard(
      tint: palette.coralTint,
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: palette.onCoralTint,
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              failure.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.onCoralTint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
