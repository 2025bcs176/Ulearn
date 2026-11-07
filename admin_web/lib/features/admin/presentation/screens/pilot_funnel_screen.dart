import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass_admin/core/models/pilot_funnel.dart';
import 'package:peerpass_admin/core/theme/admin_theme.dart';
import 'package:peerpass_admin/features/admin/presentation/providers/admin_repository_provider.dart';

/// The pilot's request-to-rating funnel.
///
/// Stateful because the read outlives a rebuild: creating the future in
/// initState keeps a parent rebuild from re-fetching the funnel, and Retry
/// replaces only the future the screen is watching.
class PilotFunnelScreen extends ConsumerStatefulWidget {
  const PilotFunnelScreen({super.key});

  @override
  ConsumerState<PilotFunnelScreen> createState() => _PilotFunnelScreenState();
}

class _PilotFunnelScreenState extends ConsumerState<PilotFunnelScreen> {
  late Future<PilotFunnel> _funnel;

  @override
  void initState() {
    super.initState();
    _funnel = ref.read(adminRepositoryProvider).pilotFunnel();
  }

  void _retry() {
    setState(() {
      _funnel = ref.read(adminRepositoryProvider).pilotFunnel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PilotFunnel>(
      future: _funnel,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load the pilot funnel.'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _retry, child: const Text('Retry')),
              ],
            ),
          );
        }
        return _funnelBody(context, snapshot.data!);
      },
    );
  }

  Widget _funnelBody(BuildContext context, PilotFunnel funnel) {
    final theme = Theme.of(context);
    // Each share is against the stage before it, not against requests: a
    // completed session came from an accepted request, and measuring it against
    // every request would understate the stage that is working.
    final acceptedShare = _share(
      funnel.requestsAccepted,
      funnel.requestsTotal,
      'requests',
    );
    final completedShare = _share(
      funnel.sessionsCompleted,
      funnel.requestsAccepted,
      'accepted',
    );
    final ratedShare = _share(
      funnel.sessionsRated,
      funnel.sessionsCompleted,
      'completed',
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Pilot funnel',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AdminColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'How requests move through the pilot: asked, accepted, completed, '
          'and rated.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AdminColors.muted),
        ),
        if (funnel.requestsTotal == 0) ...[
          const SizedBox(height: 12),
          Text(
            'No requests yet — the funnel fills as students ask.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AdminColors.muted,
            ),
          ),
        ],
        const SizedBox(height: 24),
        _FunnelStep(label: 'Requests', value: funnel.requestsTotal),
        _FunnelStep(
          label: 'Accepted',
          value: funnel.requestsAccepted,
          detail: acceptedShare,
        ),
        _FunnelStep(
          label: 'Completed',
          value: funnel.sessionsCompleted,
          detail: completedShare,
        ),
        _FunnelStep(
          label: 'Rated',
          value: funnel.sessionsRated,
          detail: ratedShare,
        ),
      ],
    );
  }

  /// A stage's share of the one before it.
  ///
  /// Null when the denominator is zero: a stage nobody reached has no
  /// meaningful percentage, and showing 0% would invent one.
  String? _share(int part, int whole, String of) {
    if (whole == 0) return null;
    final percent = (part / whole * 100).round();
    return '$percent% of $of';
  }
}

/// One stage of the funnel: its label, its count, and its conversion.
class _FunnelStep extends StatelessWidget {
  const _FunnelStep({required this.label, required this.value, this.detail});

  final String label;
  final int value;

  /// The stage's share of the previous stage, or null when there is none.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = this.detail;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A dot rather than a step number: the count is the number the
            // operator is here to read, and two competing numerals on one card
            // make it ambiguous.
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: AdminColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AdminColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$value',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AdminColors.ink,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AdminColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
