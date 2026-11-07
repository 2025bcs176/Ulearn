import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass_admin/core/models/admin_session.dart';
import 'package:peerpass_admin/core/models/pilot_funnel.dart';
import 'package:peerpass_admin/core/providers/admin_providers.dart';
import 'package:peerpass_admin/core/theme/admin_theme.dart';
import 'package:peerpass_admin/features/admin/presentation/providers/admin_repository_provider.dart';
import 'package:peerpass_admin/features/admin/presentation/screens/pilot_funnel_screen.dart';

import '../../../../support/fake_admin_repository.dart';

const _session = AdminSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  email: 'operator@peerpass.test',
);

/// A signed-in console backed by [repository].
///
/// The default surface is the narrowest window the console supports, so the
/// stage cards are exercised where a horizontal overflow would show first.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeAdminRepository repository, {
  Size size = const Size(700, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer.test(
    overrides: [adminRepositoryProvider.overrideWithValue(repository)],
  );
  container.read(sessionProvider.notifier).signedIn(_session);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAdminTheme(),
        home: const Scaffold(body: PilotFunnelScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('the pilot funnel', () {
    testWidgets('shows each stage and its conversion from the stage before', (
      tester,
    ) async {
      final repository = FakeAdminRepository(
        funnel: const PilotFunnel(
          requestsTotal: 7,
          requestsAccepted: 3,
          sessionsCompleted: 2,
          sessionsRated: 1,
        ),
      );

      await _pump(tester, repository);

      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('43% of requests'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('67% of accepted'), findsOneWidget);
      expect(find.text('Rated'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('50% of completed'), findsOneWidget);
    });

    testWidgets('a quiet pilot shows four zeroes and says why', (tester) async {
      await _pump(tester, FakeAdminRepository());

      expect(find.text('0'), findsNWidgets(4));
      expect(
        find.text('No requests yet — the funnel fills as students ask.'),
        findsOneWidget,
      );
      // Nothing was attempted and nothing failed, so no failure copy appears.
      expect(find.text('Could not load the pilot funnel.'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a failed read says so and Retry re-reads and recovers', (
      tester,
    ) async {
      final repository = FakeAdminRepository(
        funnel: const PilotFunnel(
          requestsTotal: 5,
          requestsAccepted: 2,
          sessionsCompleted: 1,
          sessionsRated: 1,
        ),
      )..funnelError = StateError('upstream host secret');

      await _pump(tester, repository);

      expect(find.text('Could not load the pilot funnel.'), findsOneWidget);
      expect(find.textContaining('upstream host secret'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(repository.pilotFunnelReads, 1);

      repository.funnelError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(repository.pilotFunnelReads, 2);
      expect(find.text('Could not load the pilot funnel.'), findsNothing);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });
}
