import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/features/sessions/data/models/session_model.dart';
import 'package:peerpass/features/sessions/presentation/formatting.dart';
import 'package:peerpass/features/sessions/presentation/providers/session_providers.dart';

/// The mutual check-in that starts a session, and the mutual finish that closes it.
///
/// Both halves live in one card because they are one pass: two people arriving,
/// then two people leaving. When this replaced the six-digit PIN, the screen
/// stopped asking one party to prove the other was present and started asking
/// each account to say what it knows -- that they are here, and that they are
/// done.
///
/// The card shows all four timestamps rather than only the reader's. Waiting on
/// someone is only tolerable when the screen says who, and a party who has not
/// tapped yet can see that the other one has.
///
/// No attempt counter and no local state: each tap is the API's to accept, and a
/// retried tap is idempotent there. A session that has completed or did not
/// happen draws nothing, because there is no action left and the detail screen
/// already carries the record.
class SessionAttendanceSection extends ConsumerWidget {
  const SessionAttendanceSection({
    required this.session,
    required this.viewerId,
    super.key,
  });

  final SessionModel session;

  /// The signed-in user's public id, which decides which side of the pass this
  /// reader stands on.
  ///
  /// Nullable because the profile loads on its own schedule and a session can be
  /// on screen before it arrives. A null id draws nothing rather than guessing a
  /// side: showing the wrong person's actions is worse than showing none.
  final String? viewerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = viewerId;
    if (viewer == null || session.otherPartyId(viewer) == null) {
      return const SizedBox.shrink();
    }

    final status = session.status;
    if (status != TutoringSessionStatus.scheduled &&
        status != TutoringSessionStatus.inProgress) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(sessionDetailProvider(session.id));
    final isTutee = session.isTutee(viewer);
    final otherId = session.otherPartyId(viewer)!;
    final otherName =
        session.otherPartyName(viewer) ??
        (isTutee ? 'Your tutor' : 'Your student');

    final viewerCheckedIn = session.hasCheckedIn(viewer);
    final viewerFinished = session.hasFinished(viewer);
    final live = status == TutoringSessionStatus.inProgress;

    final (title, body) = switch ((live, viewerCheckedIn, viewerFinished)) {
      (false, false, _) => (
        'Are you both here?',
        'Check in when you arrive. The session only starts when you and '
            '$otherName have both checked in.',
      ),
      (false, true, _) => (
        "You're checked in",
        'Waiting for $otherName to check in. The session starts as soon as they do.',
      ),
      (true, _, false) => (
        'Session in progress',
        'Finish when you are done. The session closes when you and '
            '$otherName have both finished.',
      ),
      (true, _, true) => (
        "You're finished",
        'Waiting for $otherName to finish. The time you were both here is what '
            'gets recorded.',
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Text(
                    'Session pass',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppDimens.xs),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            _Step(label: 'You checked in', at: session.checkedInAt(viewer)),
            _Step(
              label: '$otherName checked in',
              at: session.checkedInAt(otherId),
            ),
            _Step(label: 'You finished', at: session.finishedAt(viewer)),
            _Step(
              label: '$otherName finished',
              at: session.finishedAt(otherId),
              isLast: true,
            ),
            if (!viewerCheckedIn || (live && !viewerFinished)) ...[
              const SizedBox(height: AppDimens.lg),
              if (!viewerCheckedIn)
                AppButton(
                  label: "I'm here",
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: state.submitting,
                  onPressed: () => ref
                      .read(sessionDetailProvider(session.id).notifier)
                      .checkIn(),
                )
              else
                AppButton(
                  label: 'Finish session',
                  icon: Icons.task_alt_rounded,
                  isLoading: state.submitting,
                  onPressed: () => _confirmFinish(context, ref),
                ),
            ],
            if (state.actionFailure case final failure?) ...[
              const SizedBox(height: AppDimens.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  failure.message,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Finishing is the one tap in the pass that cannot be taken back.
  ///
  /// The API records the timestamp on the first call and the app has no undo
  /// route, so a stray tap in a pocket would truncate the session for both
  /// people. A confirmation is cheaper than a support message.
  Future<void> _confirmFinish(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finish this session?'),
        content: const Text(
          'Your finish time is recorded now and cannot be changed. The session '
          'closes once the other person has finished too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(sessionDetailProvider(session.id).notifier).finish();
  }
}

/// One line of the pass: who did it, and when.
///
/// A pending step keeps its place rather than disappearing, so the reader can
/// see the shape of what remains instead of watching the card grow as the other
/// party taps.
class _Step extends StatelessWidget {
  const _Step({required this.label, required this.at, this.isLast = false});

  final String label;
  final DateTime? at;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final done = at != null;
    final color = done ? palette.mint : palette.muted;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppDimens.sm),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 20,
            color: color,
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: done ? palette.ink : palette.muted),
            ),
          ),
          Text(
            at == null ? 'Pending' : momentLabel(at!),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
