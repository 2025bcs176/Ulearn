import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peerpass/app/router.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/models/tutor_standing.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/features/tutors/data/models/tutor_hq.dart';
import 'package:peerpass/features/tutors/presentation/providers/tutor_providers.dart';
import 'package:peerpass/features/tutors/presentation/widgets/tutor_standing_chip.dart';

/// The diameter of the promotion ring.
///
/// A layout constant rather than a spacing token: [AppDimens] is the 4pt gap
/// scale, and a 96pt ring is not a gap.
const double _ringSize = 96;

/// The tutor's own promotion progress, as the hero of their HQ.
///
/// Watches the provider itself rather than taking a summary parameter, because
/// every state -- loading, failure, no profile, loaded -- belongs to this one
/// piece of the dashboard. A caller that passed a summary in would have to
/// reproduce the other three states around it.
class TutorHqProgressCard extends ConsumerWidget {
  const TutorHqProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hq = ref.watch(tutorHqProvider);

    // The failure is checked before the value, for the reason the rail checks it
    // first: while an error is standing `value` is null, and null is also what
    // "still loading" looks like.
    final failure = hq.hasError ? failureFor(hq.error!) : null;
    if (failure != null) {
      return _FailureCard(
        failure: failure,
        onRetry: () => ref.invalidate(tutorHqProvider),
      );
    }

    final value = hq.value;
    if (value == null) return const _LoadingCard();
    if (!value.hasTutorProfile) return const _NoProfileCard();

    return _LoadedCard(hq: value);
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppDimens.md),
          Text(
            'Loading your progress',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.of(context).muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: theme.colorScheme.error,
                size: 22,
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Text(failure.message, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _NoProfileCard extends StatelessWidget {
  const _NoProfileCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimens.md),
                decoration: BoxDecoration(
                  color: palette.amberTint,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: palette.onAmberTint,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're not a tutor yet",
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppDimens.xs),
                    Text(
                      'Apply to teach and your sessions, ratings and progress '
                      'will appear here once you are approved.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),
          FilledButton.tonal(
            onPressed: () => context.push(AppRoutes.tutorVerification),
            child: const Text('Apply to teach'),
          ),
        ],
      ),
    );
  }
}

class _LoadedCard extends StatelessWidget {
  const _LoadedCard({required this.hq});

  final TutorHq hq;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final promotion = hq.promotion;
    final verified = promotion.verified;
    final standingWire = hq.standingWire;

    return AppCard(
      tint: palette.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PromotionRing(promotion: promotion),
              const SizedBox(width: AppDimens.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppDimens.sm,
                      runSpacing: AppDimens.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          verified ? "You're verified" : "You're almost there",
                          style: theme.textTheme.headlineSmall,
                        ),
                        if (standingWire != null)
                          TutorStandingChip(
                            standingWire: standingWire,
                            standing: hq.standing,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.sm),
                    Text(
                      _promotionSentence(hq),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),
          _StatsRow(hq: hq),
        ],
      ),
    );
  }
}

class _PromotionRing extends StatelessWidget {
  const _PromotionRing({required this.promotion});

  final TutorPromotionProgress promotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final verified = promotion.verified;

    // A tutor with the rated sessions in place is not "0 to Verified": the
    // remaining condition is the average, or a standing the client must not
    // re-derive. The ring therefore drops the count and says what the filled
    // bar actually represents, leaving the sentence below to explain why the
    // badge has not arrived.
    final sessionsOutstanding = promotion.sessionsRemaining > 0;

    return Semantics(
      label: verified
          ? 'Promotion progress complete'
          : sessionsOutstanding
          ? '${promotion.sessionsRemaining} more rated sessions to '
                'verification'
          : 'Rated session requirement met',
      child: SizedBox(
        width: _ringSize,
        height: _ringSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: promotion.progress,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: palette.soft,
              color: verified ? palette.mint : palette.amber,
            ),
            Center(
              child: verified
                  ? Icon(Icons.check_rounded, size: 34, color: palette.mint)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sessionsOutstanding
                              ? '${promotion.sessionsRemaining}'
                              : '—',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          sessionsOutstanding
                              ? 'to Verified'
                              : 'rated sessions',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.hq});

  final TutorHq hq;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final average = hq.averageRating;

    final style = theme.textTheme.bodySmall?.copyWith(color: palette.muted);

    return Wrap(
      spacing: AppDimens.lg,
      runSpacing: AppDimens.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (average == null)
          Text('No ratings yet', style: style)
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 15, color: palette.amber),
              const SizedBox(width: AppDimens.xs),
              Text('${average.toStringAsFixed(1)} average', style: style),
            ],
          ),
        Text(
          '${hq.completedSessions} '
          '${hq.completedSessions == 1 ? 'session' : 'sessions'}',
          style: style,
        ),
        Text(
          '${hq.ratingCount} '
          '${hq.ratingCount == 1 ? 'review' : 'reviews'}',
          style: style,
        ),
      ],
    );
  }
}

/// What still stands between the tutor and verification.
///
/// Both halves come from the API: [TutorPromotionProgress.sessionsRemaining]
/// and [TutorPromotionProgress.meetsAverage]. The sentence never recomputes
/// either, so a changed threshold or session count reads correctly without a
/// client release.
String _promotionSentence(TutorHq hq) {
  final promotion = hq.promotion;
  final average = promotion.minimumAverage.toStringAsFixed(2);
  final sessions = promotion.sessionsRemaining;
  final sessionWord = sessions == 1 ? 'session' : 'sessions';

  // A standing the client cannot promote is explained as itself, not as a
  // promotion that is "being applied". The thresholds do not know about
  // suspension or a reduced standing, and a tutor reading "verification is
  // being applied" while their profile says Suspended is being told the wrong
  // thing by the same screen.
  if (!promotion.verified && hq.standing == TutorStanding.suspended) {
    return 'Your account is suspended, so students cannot book you right now.';
  }
  if (!promotion.verified && hq.standing == TutorStanding.reduced) {
    return 'Your standing is reduced. A $average average is what brings it '
        'back up.';
  }

  if (promotion.verified) {
    return 'You meet the $average average. Keep your rating above it to stay '
        'verified.';
  }

  if (sessions <= 0) {
    return promotion.meetsAverage
        ? 'Your rated sessions are in place. Your standing updates with your '
              'next rating.'
        : 'You have the sessions. A $average average is what stands between '
              'you and verification.';
  }

  if (promotion.meetsAverage) {
    return 'You meet the $average average. Just $sessions more rated '
        '$sessionWord.';
  }

  return '$sessions more rated $sessionWord and a $average average.';
}
