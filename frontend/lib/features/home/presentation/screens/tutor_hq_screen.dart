import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/models/user_profile.dart';
import 'package:peerpass/core/state/session.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_avatar.dart';
import 'package:peerpass/core/widgets/content_width_limiter.dart';

/// A tutor's own landing screen.
///
/// The progress card, the availability toggle, the request list, and the
/// certificate belong to four different features. They arrive here as widgets,
/// exactly like the home screen receives its composer, card, and rail: naming
/// any of those features in this file would make home a second place that has
/// to change whenever they do, and AGENTS.md forbids one feature importing
/// another's presentation layer.
///
/// The screen itself is display only. It places the sections and says hello; it
/// does not decide what "available" means, when hours become a certificate, or
/// which request is worth showing. Those are rules the backend owns, and a
/// client copy would eventually disagree with it.
class TutorHqScreen extends ConsumerWidget {
  const TutorHqScreen({
    required this.progressCard,
    required this.availabilityToggle,
    required this.requestsSection,
    required this.certificateCard,
    this.onRefresh,
    super.key,
  });

  /// Hours, standing, and the next thing the tutor should do about them.
  final Widget progressCard;

  /// The control that takes the tutor off the rail, or puts them back on it.
  final Widget availabilityToggle;

  /// The requests waiting on an answer. Goes above the certificate because a
  /// student is waiting on it.
  final Widget requestsSection;

  /// The record of what the tutor has earned so far.
  final Widget certificateCard;

  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final profile = ref.watch(sessionControllerProvider).profile;
    final refresh = onRefresh;

    final content = SingleChildScrollView(
      // A refresh needs a scrollable that will report a drag even when the
      // content fits one screen, which is the common case on a large phone.
      physics: refresh == null
          ? const ClampingScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      child: ContentWidthLimiter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            AppDimens.lg,
            AppDimens.screenPadding,
            AppDimens.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppAvatar(name: profile?.fullName ?? '?'),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your tutor HQ',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppDimens.xxs),
                        Text(
                          _greeting(profile),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.xl),
              progressCard,
              const SizedBox(height: AppDimens.xl),
              availabilityToggle,
              // The request list is the one section about somebody else waiting
              // for something, so it gets a wider gap to mark where the tutor's
              // own status ends and other people's asks begin.
              const SizedBox(height: AppDimens.xxl),
              requestsSection,
              const SizedBox(height: AppDimens.xxl),
              certificateCard,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Tutor HQ')),
      body: SafeArea(
        child: Center(
          child: refresh == null
              ? content
              : RefreshIndicator(onRefresh: refresh, child: content),
        ),
      ),
    );
  }

  /// A greeting from the stored name, not a prompt for one.
  ///
  /// Falls back to "Hello there." rather than a bare "Good evening,": a tutor
  /// who reaches this screen without a name is not a state the router allows,
  /// so this only guards against a heading that would otherwise read
  /// "Good evening, .".
  String _greeting(UserProfile? profile) {
    final firstName = profile?.firstName;
    return firstName == null ? 'Hello there.' : 'Good evening, $firstName.';
  }
}
