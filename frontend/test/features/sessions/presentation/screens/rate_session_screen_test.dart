import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:peerpass/app/router.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/models/user_profile.dart';
import 'package:peerpass/core/models/user_role.dart';
import 'package:peerpass/core/state/session.dart';
import 'package:peerpass/features/auth/data/repositories/auth_repository.dart';
import 'package:peerpass/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:peerpass/features/sessions/data/models/rating_model.dart';
import 'package:peerpass/features/sessions/data/models/session_model.dart';
import 'package:peerpass/features/sessions/data/repositories/fake_sessions_repository.dart';
import 'package:peerpass/features/sessions/data/repositories/sessions_repository.dart';
import 'package:peerpass/features/sessions/presentation/screens/rate_session_screen.dart';

const UserProfile _tutee = UserProfile(
  publicId: 'student-1',
  email: 'student@must.ac.ug',
  fullName: 'Achieng Okello',
  roles: <UserRole>{UserRole.student},
  universityId: 'university-1',
  facultyId: 'subject-1',
  yearOfStudy: 2,
);

const UserProfile _tutor = UserProfile(
  publicId: 'tutor-1',
  email: 'tutor@must.ac.ug',
  fullName: 'Daniel Okot',
  roles: <UserRole>{UserRole.student, UserRole.tutor},
  universityId: 'university-1',
  facultyId: 'subject-1',
  yearOfStudy: 3,
);

const String _sessionId = 'session-1';

SessionModel completed({bool isRated = false}) {
  return SessionModel.fromJson({
    'id': _sessionId,
    'tutee_id': _tutee.publicId,
    'tutor_id': _tutor.publicId,
    'course_unit_id': 'unit-1',
    'course_unit_code': 'MAT 221',
    'course_unit_name': 'Linear Algebra',
    'tutee_name': 'Adongo Sarah',
    'tutor_name': 'Okello Daniel',
    'topic': 'Second order ODEs',
    'status': 'completed',
    'duration_minutes': 60,
    'is_rated': isRated,
    'created_at': '2026-03-01T08:00:00Z',
    'scheduled_start': '2026-03-04T09:00:00Z',
    'ended_at': '2026-03-04T10:00:00Z',
  });
}

/// A container holding [repository], signed in as [profile].
///
/// The rating screen reads the session through the detail provider, so the
/// session has to be in the repository for the form to appear at all.
ProviderContainer _container(
  FakeSessionsRepository repository,
  UserProfile profile,
) {
  final container = ProviderContainer(
    overrides: [
      sessionsRepositoryProvider.overrideWithValue(repository),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(session: profile, refreshToken: 'refresh'),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(sessionControllerProvider.notifier).signedIn(profile);
  return container;
}

/// A router with the rate screen pushed on top of a stub page.
///
/// The screen pops itself once a rating is accepted, so it needs something to pop
/// *to*. In the app the detail screen pushes this route on top of itself; the test
/// does the same, through the same [AppRoutes.rateSessionPath] helper, so a broken
/// path shows up here rather than only in the app.
Future<FakeSessionsRepository> _pumpRate(
  WidgetTester tester,
  UserProfile profile, {
  FakeSessionsRepository? repository,
}) async {
  final sessions =
      repository ?? FakeSessionsRepository(sessions: [completed()]);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold()),
      GoRoute(
        path: '${AppRoutes.sessions}/:sessionId/rate',
        builder: (context, state) => RateSessionScreen(
          sessionId: state.pathParameters['sessionId'] ?? _sessionId,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container(sessions, profile),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  unawaited(router.push(AppRoutes.rateSessionPath(_sessionId)));
  await _settle(tester);
  return sessions;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Future<void> _chooseHelped(WidgetTester tester) async {
  await tester.tap(find.text('Yes'));
  await _settle(tester);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await _settle(tester);
}

/// A repository that refuses the rating, the way an out-of-range score or a
/// session the API will not accept is refused.
class _RefusingSessionsRepository extends FakeSessionsRepository {
  _RefusingSessionsRepository({super.sessions});

  @override
  Future<RatingModel> rateSession({
    required String sessionId,
    required int score,
    bool comprehensionHelped = false,
    String? feedbackText,
    List<String> tags = const [],
    List<String> endorsedCourseUnitIds = const [],
  }) async {
    throw const ValidationFailure(
      'A session can only be rated once it has finished.',
      fieldErrors: {'session_id': 'not completed'},
    );
  }
}

void main() {
  testWidgets('both feedback answers are required', (tester) async {
    final sessions = await _pumpRate(tester, _tutee);

    // Neither mandatory answer can be omitted.
    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNull);

    await tester.tap(find.bySemanticsLabel('4 of 5'));
    await _settle(tester);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await _chooseHelped(tester);
    await _submit(tester);

    expect(sessions.submittedRatings.single.score, 4);
  });

  testWidgets('the note goes out as written, and a blank one is not sent', (
    tester,
  ) async {
    final sessions = await _pumpRate(tester, _tutee);

    await tester.tap(find.bySemanticsLabel('5 of 5'));
    await _settle(tester);
    await _chooseHelped(tester);
    await tester.enterText(find.byType(TextField), 'Explained it twice. ');
    await _settle(tester);
    await _submit(tester);

    // Trimmed on the way out. The surrounding whitespace is the phone keyboard's,
    // not something the student meant to say.
    expect(
      sessions.submittedRatings.single.feedbackText,
      'Explained it twice.',
    );

    final second = FakeSessionsRepository(sessions: [completed()]);
    await _pumpRate(tester, _tutee, repository: second);
    await tester.tap(find.bySemanticsLabel('3 of 5'));
    await _settle(tester);
    await _chooseHelped(tester);
    await _submit(tester);

    // A blank note is the absence of a note. Sending `''` would assert that the
    // field is empty, which is a different claim and would clear a stored one on
    // a re-submission.
    expect(second.submittedRatings.single.feedbackText, isNull);
  });

  group('the tags', () {
    Future<void> pick(WidgetTester tester, String label) async {
      final chip = find.widgetWithText(FilterChip, label);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await _settle(tester);
    }

    bool isPicked(WidgetTester tester, String label) => tester
        .widget<FilterChip>(find.widgetWithText(FilterChip, label))
        .selected;

    testWidgets('go out as wire values in the order they were picked', (
      tester,
    ) async {
      final sessions = await _pumpRate(tester, _tutee);

      await tester.tap(find.bySemanticsLabel('5 of 5'));
      await _settle(tester);
      await _chooseHelped(tester);
      await pick(tester, 'Patient');
      await pick(tester, 'Explained clearly');
      await _submit(tester);

      // The order is the student's, and the API stores the list as sent: a set
      // would reorder what they chose to say first.
      expect(sessions.submittedRatings.single.tags, [
        'patient',
        'clear_explanation',
      ]);
    });

    testWidgets('are optional, and none is sent when none is picked', (
      tester,
    ) async {
      final sessions = await _pumpRate(tester, _tutee);

      await tester.tap(find.bySemanticsLabel('4 of 5'));
      await _settle(tester);
      await _chooseHelped(tester);
      await _submit(tester);

      // A student who wants to leave a score and go is not made to describe the
      // tutor to get past the form.
      expect(sessions.submittedRatings.single.tags, isEmpty);
    });

    testWidgets('a picked tag can be taken back', (tester) async {
      final sessions = await _pumpRate(tester, _tutee);

      await tester.tap(find.bySemanticsLabel('5 of 5'));
      await _settle(tester);
      await _chooseHelped(tester);
      await pick(tester, 'On time');
      expect(isPicked(tester, 'On time'), isTrue);
      await pick(tester, 'On time');
      expect(isPicked(tester, 'On time'), isFalse);
      await _submit(tester);

      expect(sessions.submittedRatings.single.tags, isEmpty);
    });

    testWidgets('stop at four, and the rest are disabled rather than refused', (
      tester,
    ) async {
      final sessions = await _pumpRate(tester, _tutee);

      await tester.tap(find.bySemanticsLabel('5 of 5'));
      await _settle(tester);
      await _chooseHelped(tester);
      for (final label in [
        'Explained clearly',
        'Patient',
        'Well prepared',
        'Made it click',
      ]) {
        await pick(tester, label);
      }

      // The API rejects a fifth. A chip that fails on tap is a form arguing with
      // a student, so the remaining chips are visibly unavailable instead.
      final fifth = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Real examples'),
      );
      expect(fifth.onSelected, isNull);

      await _submit(tester);
      expect(sessions.submittedRatings.single.tags, hasLength(4));
    });

    testWidgets('are not offered to a tutor, who is not the one rating', (
      tester,
    ) async {
      // Only the tutee submits feedback, and the profile publishes tags about a
      // tutor. A tutor rating a student is not a review anybody can read.
      await _pumpRate(tester, _tutor);

      expect(find.byType(FilterChip), findsNothing);
    });
  });

  group('the endorsement', () {
    testWidgets('is off by default, and off means nothing is endorsed', (
      tester,
    ) async {
      final sessions = await _pumpRate(tester, _tutee);

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isFalse);

      await tester.tap(find.bySemanticsLabel('5 of 5'));
      await _settle(tester);
      await _chooseHelped(tester);
      await _submit(tester);

      // A student who wants to leave a mark and go is not made to assert a claim
      // about a tutor's coverage to get past a form. That is the failure the API
      // documents this field as guarding against.
      expect(sessions.endorsementSubmissions.single, isEmpty);
    });

    testWidgets('names the session own unit when it is ticked', (tester) async {
      final sessions = await _pumpRate(tester, _tutee);

      await tester.tap(find.bySemanticsLabel('5 of 5'));
      await _settle(tester);
      await _chooseHelped(tester);

      // The tag chips sit above the checkbox, so the endorsement is below the
      // fold once the form has grown. Scrolling to it first keeps the tap on the
      // row rather than on empty space above the list.
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await _settle(tester);
      await _submit(tester);

      // Exactly the unit the session was booked for. The API's service refuses any
      // other unit, so a list of units to pick from would be a list where every
      // choice but this one is rejected by the server.
      expect(sessions.endorsementSubmissions.single, ['unit-1']);
    });

    testWidgets('is not offered to a tutor, who has no tutor to endorse', (
      tester,
    ) async {
      // The API derives the ratee from the session and writes the endorsement to
      // that ratee's tutor record. A tutor rating a student would be recorded as
      // a tutor endorsing a student, which is not what the field means.
      await _pumpRate(tester, _tutor);

      expect(find.byType(CheckboxListTile), findsNothing);
    });
  });

  testWidgets('a refused rating keeps the draft and says why', (tester) async {
    await _pumpRate(
      tester,
      _tutee,
      repository: _RefusingSessionsRepository(sessions: [completed()]),
    );

    await tester.tap(find.bySemanticsLabel('5 of 5'));
    await _settle(tester);
    await _chooseHelped(tester);
    await tester.enterText(find.byType(TextField), 'Worth saying.');
    await _settle(tester);
    await _submit(tester);

    // The screen stays open and the note survives, so fixing the problem does not
    // mean retyping. The failure's own message, never the exception.
    expect(
      find.text('A session can only be rated once it has finished.'),
      findsOneWidget,
    );
    expect(find.text('Worth saying.'), findsOneWidget);
  });

  testWidgets('a session with a rating already blocks a second submission', (
    tester,
  ) async {
    await _pumpRate(
      tester,
      _tutee,
      repository: FakeSessionsRepository(sessions: [completed(isRated: true)]),
    );

    expect(
      find.text('Feedback has already been submitted for this session.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('a submitted rating cannot withdraw its recommendation', (
    tester,
  ) async {
    await _pumpRate(
      tester,
      _tutee,
      repository: FakeSessionsRepository(sessions: [completed(isRated: true)]),
    );

    expect(
      find.text('Feedback has already been submitted for this session.'),
      findsOneWidget,
    );
  });

  testWidgets('a first rating cannot be dismissed', (tester) async {
    await _pumpRate(tester, _tutee);

    expect(
      find.text('Both answers are required to finish this session review.'),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsNothing);
  });
}
