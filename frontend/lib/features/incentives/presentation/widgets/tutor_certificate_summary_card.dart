import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peerpass/app/router.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/features/incentives/data/models/certificate_eligibility.dart';
import 'package:peerpass/features/incentives/presentation/formatting.dart';
import 'package:peerpass/features/incentives/presentation/providers/incentive_providers.dart';

/// The certificate section of a tutor's dashboard.
///
/// A compact restatement of the certificate screen, not a second owner of the
/// rule: the bar uses the API's `progress`, the label uses its minutes, and the
/// verdict is its `eligible`. The only thing this adds to the numbers is the
/// sentence they make in a dashboard-sized card.
///
/// A caller with no tutor profile is a different state, not a bar at zero. A
/// zero bar would tell a student they are failing a requirement the platform has
/// not yet given them a way to meet.
class TutorCertificateSummaryCard extends ConsumerWidget {
  const TutorCertificateSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibility = ref.watch(certificateEligibilityProvider);
    final failure = eligibility.hasError
        ? failureFor(eligibility.error!)
        : null;

    if (failure != null) {
      return _FailureNotice(
        message: failure.message,
        onRetry: () => ref.invalidate(certificateEligibilityProvider),
      );
    }

    final loaded = eligibility.value;
    if (loaded == null) return const _LoadingNotice();
    if (!loaded.hasTutorProfile) return const _NoProfileNotice();

    return _Progress(eligibility: loaded);
  }
}

/// The bar and the numbers, sized for one dashboard section.
class _Progress extends StatelessWidget {
  const _Progress({required this.eligibility});

  final CertificateEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final remaining = remainingLabel(eligibility);

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Certificate progress', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDimens.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            // The API already answered; animating up to the number would read as
            // work still happening on a total a tutor opened the card to check.
            child: LinearProgressIndicator(
              value: progressValue(eligibility),
              minHeight: AppDimens.sm,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppDimens.md),
          Text(
            certificateProgressLabel(eligibility),
            style: theme.textTheme.bodyLarge,
          ),
          if (remaining != null) ...[
            const SizedBox(height: AppDimens.xs),
            Text(
              remaining,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
          const SizedBox(height: AppDimens.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'View certificate',
              variant: AppButtonVariant.ghost,
              isFullWidth: false,
              isSmall: true,
              onPressed: () => context.push(AppRoutes.certificate),
            ),
          ),
        ],
      ),
    );
  }
}

/// The answer for an account that is not a tutor yet.
class _NoProfileNotice extends StatelessWidget {
  const _NoProfileNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: palette.primary),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Text(
                  'Certificate progress',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          Text(
            'Teaching hours will appear here once your tutor application is '
            'approved.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Apply to teach',
              variant: AppButtonVariant.ghost,
              isFullWidth: false,
              isSmall: true,
              onPressed: () => context.push(AppRoutes.tutorVerification),
            ),
          ),
        ],
      ),
    );
  }
}

/// The section while the answer is on its way.
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
              'Checking your certificate progress',
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reason the card could not be filled, with the one action that helps.
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
