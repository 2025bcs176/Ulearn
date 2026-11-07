import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/features/tutors/presentation/providers/tutor_providers.dart';

/// Whether students searching for a tutor can find this one.
///
/// Watches the HQ provider rather than owning a second copy of the flag. The
/// switch therefore always shows what the API last said, which is what makes a
/// failed save safe: the thumb never moves optimistically, so a save that fails
/// leaves the control already telling the truth.
class TutorAvailabilityToggle extends ConsumerStatefulWidget {
  const TutorAvailabilityToggle({super.key});

  @override
  ConsumerState<TutorAvailabilityToggle> createState() =>
      _TutorAvailabilityToggleState();
}

class _TutorAvailabilityToggleState
    extends ConsumerState<TutorAvailabilityToggle> {
  /// True while a save is in flight, so the switch cannot be tapped twice.
  bool _saving = false;

  Future<void> _setAccepting(bool accepting) async {
    setState(() => _saving = true);
    try {
      await ref.read(tutorHqProvider.notifier).setAcceptingRequests(accepting);
    } on Object catch (error) {
      // The notifier rethrows only so this widget can explain the save; the HQ
      // itself stays on screen because one failed setting is not a failed
      // dashboard.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureFor(error).message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hq = ref.watch(tutorHqProvider);

    // A load failure already has a card and a retry beside this control. Showing
    // a switch whose value is unknown would invite the tutor to change a setting
    // the app cannot read.
    if (hq.hasError) return const SizedBox.shrink();

    final value = hq.value;
    if (value == null) return const _LoadingTile();

    // A student has nothing to pause, and a switch reading "off" would imply a
    // setting they could turn on.
    if (!value.hasTutorProfile) return const SizedBox.shrink();

    final accepting = value.acceptingRequests ?? false;
    final palette = AppPalette.of(context);

    return Tooltip(
      message: accepting
          ? 'Turn off to hide from student searches'
          : 'Turn on to appear in student searches',
      child: AppCard(
        padding: EdgeInsets.zero,
        // Its own Material so the switch's ripple and background paint above
        // the card's DecoratedBox instead of being hidden by it.
        child: Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimens.lgPlus,
              vertical: AppDimens.xs,
            ),
            secondary: Icon(
              accepting
                  ? Icons.notifications_active_outlined
                  : Icons.pause_circle_outline_rounded,
              color: accepting ? palette.mint : palette.muted,
            ),
            title: const Text('Accepting requests'),
            subtitle: Text(
              accepting
                  ? 'Students can find you and send new requests.'
                  : 'You are hidden from student searches until you switch '
                        'this back on.',
            ),
            value: accepting,
            // Null while saving, which disables the tile without changing the
            // thumb. The provider rebuilds it once the API answers.
            onChanged: _saving ? null : _setAccepting,
          ),
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

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
            'Loading your availability',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.of(context).muted,
            ),
          ),
        ],
      ),
    );
  }
}
