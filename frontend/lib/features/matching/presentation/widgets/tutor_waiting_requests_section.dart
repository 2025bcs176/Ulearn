import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peerpass/app/router.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/core/widgets/section_header.dart';
import 'package:peerpass/features/matching/data/models/help_request.dart';
import 'package:peerpass/features/matching/presentation/providers/matching_providers.dart';

/// The "waiting on you" strip of a tutor's dashboard.
///
/// Deliberately a summary and not the request list: the accept/decline decision
/// belongs to the tutor requests screen, and a dashboard that offered a second place
/// to make it would be two implementations of one API call. Every tap here goes
/// to that screen, which owns the outcome.
///
/// At most two rows are shown because this is one section of a dashboard, not a
/// screen. The count in the header is of every request, so a tutor can tell that
/// there is more behind "See all" without the dashboard growing a list.
class TutorWaitingRequestsSection extends ConsumerWidget {
  const TutorWaitingRequestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(tutorRequestsProvider);
    final failure = requests.hasError ? failureFor(requests.error!) : null;

    final Widget content;
    if (failure != null) {
      content = _FailureNotice(
        message: failure.message,
        onRetry: () => ref.invalidate(tutorRequestsProvider),
      );
    } else {
      final loaded = requests.value;
      if (loaded == null) {
        content = const _LoadingNotice();
      } else {
        content = _Requests(requests: loaded);
      }
    }

    final loaded = failure == null ? requests.value : null;
    final subtitle = loaded == null || loaded.isEmpty
        ? 'New requests land here when a student asks for you.'
        : _countLabel(loaded.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Waiting on you',
          subtitle: subtitle,
          actionLabel: 'See all',
          onAction: () => context.push(AppRoutes.tutorRequests),
        ),
        const SizedBox(height: AppDimens.md),
        content,
      ],
    );
  }

  /// The header's one line, which counts every request rather than the two rows
  /// visible below it.
  ///
  /// No "this week": the list is whatever is still awaiting an answer, and the
  /// API does not bound it by time. A count labelled with a period it was not
  /// filtered by would be a number a tutor could catch out.
  String _countLabel(int count) =>
      count == 1 ? '1 request waiting.' : '$count requests waiting.';
}

/// The rows, or the calm answer that there are none.
class _Requests extends StatelessWidget {
  const _Requests({required this.requests});

  final List<HelpRequest> requests;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const _EmptyNotice();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final request in requests.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.sm),
            child: _RequestRow(request: request),
          ),
      ],
    );
  }
}

/// One request, reduced to what a tutor needs to decide whether to open it.
class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return AppCard(
      onTap: () => context.push(AppRoutes.tutorRequests),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.md,
      ),
      semanticLabel: 'Review the request: ${request.topic}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.topic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppDimens.xxs),
                // No unit id here. The request carries only the internal
                // course-unit uuid, and a row that read "9f1c… · Asked 2h ago"
                // would be showing a database key where a course name belongs.
                // The full request screen is where the tutor sees the context.
                Text(
                  'Asked ${_relativeTime(request.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Icon(Icons.chevron_right_rounded, color: palette.muted),
        ],
      ),
    );
  }

  /// How long ago the student asked, near enough for a summary row.
  ///
  /// A date library would be a dependency for one line, and the exact timestamp
  /// is on the request screen for a tutor who needs it.
  String _relativeTime(DateTime createdAt) {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
    return '${elapsed.inDays}d ago';
  }
}

/// The ordinary answer for a tutor nobody has chosen.
class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inbox_rounded, color: palette.primary),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No one is waiting on you yet.',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppDimens.xxs),
                Text(
                  'When a student picks you for help, their question appears '
                  'here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The section while the list is on its way.
class _LoadingNotice extends StatelessWidget {
  const _LoadingNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Semantics(
      liveRegion: true,
      child: AppCard(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              child: const LinearProgressIndicator(minHeight: AppDimens.sm),
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              'Checking for requests',
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reason the section could not be filled, with the one action that helps.
class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppDimens.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Try again',
              variant: AppButtonVariant.ghost,
              isFullWidth: false,
              isSmall: true,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}
