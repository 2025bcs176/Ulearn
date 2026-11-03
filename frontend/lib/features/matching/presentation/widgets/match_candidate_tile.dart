import 'package:flutter/material.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/models/tutor_standing.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_avatar.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/core/widgets/app_pill.dart';
import 'package:peerpass/features/matching/data/models/match_result.dart';

/// One tutor the API is willing to propose, with the evidence behind it.
///
/// A vertical card rather than a rail row, because a candidate list is a list:
/// it is longer than a rail, it is read top to bottom, and each row carries the
/// unit's grade as well as the tutor. The extra width is spent on a bio and the
/// evidence a student would otherwise have to open the profile to find.
///
/// [onAsk] is what makes the list usable rather than a reading of one. It is
/// null on a tutor who has already been asked, which the caller expresses by
/// passing null rather than by passing a callback that does nothing -- a control
/// that looks pressable and does nothing is worse than no control.
class MatchCandidateTile extends StatelessWidget {
  const MatchCandidateTile({
    required this.candidate,
    required this.askLabel,
    this.onAsk,
    this.busy = false,
    super.key,
  });

  final MatchCandidate candidate;

  /// The button's wording, so the sentence about this tutor is built once.
  final String askLabel;

  /// Called when the student asks this tutor, or null when they already have.
  final VoidCallback? onAsk;

  /// Whether this student's request for this tutor is in flight.
  ///
  /// Only [onAsk]'s own row is busy. A list where every row disables itself while
  /// one is being sent leaves the student unable to tell which tutor they were
  /// choosing.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final tutor = candidate.tutor;
    final isVerified = tutor.standing == TutorStanding.verified;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(
                  name: tutor.fullName,
                  imageUrl: tutor.avatarUrl,
                  size: 48,
                  isVerified: isVerified,
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tutor.fullName,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppDimens.xxs),
                      Wrap(
                        spacing: AppDimens.xs,
                        runSpacing: AppDimens.xs,
                        children: [
                          AppPill(
                            tutor.standingLabel,
                            tone: _standingTone(tutor.standing),
                            isCompact: true,
                          ),
                          if (tutor.yearLabel case final year?)
                            AppPill(year, isCompact: true),
                          if (!tutor.acceptingRequests)
                            const AppPill(
                              'Paused',
                              tone: AppPillTone.danger,
                              isCompact: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            // The bio is the reason the student can choose between two
            // equally-qualified tutors. Without one the row falls back to the
            // evidence the API already sent, rather than leaving a gap.
            if (tutor.hasBio)
              Text(
                tutor.bio!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              )
            else
              Text(
                candidate.gradeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              ),
            const SizedBox(height: AppDimens.md),
            Wrap(
              spacing: AppDimens.sm,
              runSpacing: AppDimens.sm,
              children: [
                AppPill(
                  tutor.ratingLabel,
                  icon: Icons.star_rounded,
                  tone: tutor.hasRatings
                      ? AppPillTone.warning
                      : AppPillTone.neutral,
                  isCompact: true,
                ),
                AppPill(
                  '${tutor.completedSessions} sessions',
                  isCompact: true,
                ),
                if (candidate.competencyGradePoints != null)
                  AppPill(candidate.gradeLabel, isCompact: true),
              ],
            ),
            const SizedBox(height: AppDimens.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: busy ? 'Sending…' : askLabel,
                isSmall: true,
                isFullWidth: false,
                isLoading: busy,
                onPressed: onAsk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The standing, in the pill's vocabulary.
  ///
  /// The tone is semantic rather than a colour chosen here: a suspended tutor
  /// is the only one a student must not mistake for an available one.
  AppPillTone _standingTone(TutorStanding? standing) {
    return switch (standing) {
      TutorStanding.verified => AppPillTone.success,
      TutorStanding.reduced => AppPillTone.warning,
      TutorStanding.suspended => AppPillTone.danger,
      TutorStanding.probationary => AppPillTone.neutral,
      null => AppPillTone.danger,
    };
  }
}
