import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:peerpass/app/router.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/features/matching/data/models/help_request.dart';
import 'package:peerpass/features/matching/data/repositories/fake_matching_repository.dart';
import 'package:peerpass/features/matching/data/repositories/matching_repository.dart';
import 'package:peerpass/features/matching/presentation/widgets/tutor_waiting_requests_section.dart';

/// A request a tutor was named on, as the API would return it.
HelpRequest _request({
  String id = 'request-1',
  String topic = 'eigenvalues',
  String courseUnitId = 'unit-1',
  Duration age = const Duration(hours: 2),
}) {
  return HelpRequest(
    id: id,
    tuteeId: 'student-1',
    courseUnitId: courseUnitId,
    topic: topic,
    statusWire: HelpRequestStatus.pendingConfirmation.wireValue,
    status: HelpRequestStatus.pendingConfirmation,
    matchedTutorId: 'tutor-1',
    createdAt: DateTime.now().subtract(age),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: SingleChildScrollView(child: TutorWaitingRequestsSection()),
        ),
      ),
      GoRoute(
        path: AppRoutes.tutorRequests,
        builder: (_, _) => const Scaffold(body: Text('Tutor requests screen')),
      ),
    ],
  );
}

Widget _app(MatchingRepository repository, GoRouter router) {
  final container = ProviderContainer(
    overrides: [matchingRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

/// Pumps long enough for the provider's future to land, without settling an
/// animation the section does not own.
Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

Future<void> _pump(
  WidgetTester tester,
  FakeMatchingRepository repository,
) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(_app(repository, router));
  await _flush(tester);
}

FakeMatchingRepository _repository({
  required Future<List<HelpRequest>?> Function() onAwaiting,
}) {
  return FakeMatchingRepository(onRequestsAwaitingMe: onAwaiting);
}

void main() {
  testWidgets('shows two requests and counts every request in the header', (
    tester,
  ) async {
    await _pump(
      tester,
      _repository(
        onAwaiting: () async => [
          _request(),
          _request(
            id: 'request-2',
            topic: 'normalization',
            courseUnitId: 'unit-2',
          ),
          _request(id: 'request-3', topic: 'SQL joins', courseUnitId: 'unit-3'),
        ],
      ),
    );

    expect(find.text('Waiting on you'), findsOneWidget);
    expect(find.text('3 requests waiting.'), findsOneWidget);
    expect(find.text('eigenvalues'), findsOneWidget);
    expect(find.text('normalization'), findsOneWidget);
    // The third is behind "See all", not on the dashboard.
    expect(find.text('SQL joins'), findsNothing);
    // The request carries a uuid, not a course name, so the row must not print
    // one where a student would expect their unit.
    expect(find.textContaining('unit-1'), findsNothing);
    expect(find.textContaining('unit-2'), findsNothing);
    expect(find.textContaining('Asked'), findsNWidgets(2));
  });

  testWidgets('says how many when only one student is waiting', (tester) async {
    await _pump(tester, _repository(onAwaiting: () async => [_request()]));

    expect(find.text('1 request waiting.'), findsOneWidget);
    expect(find.text('eigenvalues'), findsOneWidget);
  });

  testWidgets('nobody waiting is a calm section, not a failure', (
    tester,
  ) async {
    await _pump(tester, _repository(onAwaiting: () async => const []));

    expect(find.text('Waiting on you'), findsOneWidget);
    expect(find.text('No one is waiting on you yet.'), findsOneWidget);
    expect(
      find.textContaining('When a student picks you for help'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('says so while the list is still on its way', (tester) async {
    final completer = Completer<List<HelpRequest>?>();
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(_repository(onAwaiting: () => completer.future), router),
    );
    await tester.pump();

    expect(find.text('Checking for requests'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    completer.complete(const []);
    await _flush(tester);

    expect(find.text('No one is waiting on you yet.'), findsOneWidget);
  });

  testWidgets('a list that will not load offers a retry', (tester) async {
    var calls = 0;
    final repository = _repository(
      onAwaiting: () async {
        calls++;
        if (calls == 1) throw const NetworkFailure();
        return [_request()];
      },
    );

    await _pump(tester, repository);

    expect(
      find.text('No connection. Check your network and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text('No one is waiting on you yet.'), findsNothing);

    await tester.tap(find.text('Try again'));
    await _flush(tester);

    expect(calls, 2);
    expect(find.text('eigenvalues'), findsOneWidget);
  });

  testWidgets('See all opens the tutor requests screen', (tester) async {
    await _pump(tester, _repository(onAwaiting: () async => [_request()]));

    await tester.tap(find.text('See all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tutor requests screen'), findsOneWidget);
  });

  testWidgets('tapping a request opens the tutor requests screen', (
    tester,
  ) async {
    await _pump(tester, _repository(onAwaiting: () async => [_request()]));

    await tester.tap(find.text('eigenvalues'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tutor requests screen'), findsOneWidget);
  });
}
