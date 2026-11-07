import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/models/tutor_standing.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/features/tutors/data/models/tutor_hq.dart';
import 'package:peerpass/features/tutors/data/repositories/fake_tutors_repository.dart';
import 'package:peerpass/features/tutors/data/repositories/tutors_repository.dart';
import 'package:peerpass/features/tutors/presentation/widgets/tutor_hq_progress_card.dart';

TutorPromotionProgress _promotion({
  bool verified = false,
  int ratedSessions = 1,
  int sessionsRemaining = 2,
  bool meetsAverage = true,
  double progress = 0.3333333333333333,
}) {
  return TutorPromotionProgress(
    verified: verified,
    ratedSessions: ratedSessions,
    sessionsRequired: 3,
    sessionsRemaining: sessionsRemaining,
    minimumAverage: 4.1,
    meetsAverage: meetsAverage,
    progress: progress,
  );
}

TutorHq _hq({
  bool hasTutorProfile = true,
  String? standingWire = 'probationary',
  TutorStanding? standing = TutorStanding.probationary,
  int completedSessions = 14,
  double? averageRating = 4.8,
  int ratingCount = 2,
  bool? acceptingRequests = true,
  TutorPromotionProgress? promotion,
}) {
  return TutorHq(
    hasTutorProfile: hasTutorProfile,
    standingWire: standingWire,
    standing: standing,
    completedSessions: completedSessions,
    averageRating: averageRating,
    ratingCount: ratingCount,
    certifiedMinutes: 600,
    certificateRequiredMinutes: 2400,
    certificateRemainingMinutes: 1800,
    certificateEligible: false,
    certificateProgress: 0.25,
    acceptingRequests: acceptingRequests,
    promotion: promotion ?? _promotion(),
  );
}

ProviderContainer _container(TutorsRepository repository) {
  final container = ProviderContainer(
    overrides: [tutorsRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: TutorHqProgressCard(),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// A repository whose first fetch is held open until the test releases it.
class _PendingTutorsRepository extends FakeTutorsRepository {
  final Completer<TutorHq> _completer = Completer<TutorHq>();

  void answer(TutorHq hq) => _completer.complete(hq);

  @override
  Future<TutorHq> myHq() => _completer.future;
}

/// A repository whose first HQ fetch fails and whose second answers.
class _FlakyTutorsRepository extends FakeTutorsRepository {
  _FlakyTutorsRepository({required this.recovered});

  final TutorHq recovered;
  int attempts = 0;

  @override
  Future<TutorHq> myHq() async {
    attempts++;
    if (attempts == 1) {
      throw const ServerFailure('The HQ could not be loaded.');
    }
    return recovered;
  }
}

void main() {
  testWidgets('says so while the summary is still on its way', (tester) async {
    final repository = _PendingTutorsRepository();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container(repository),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: TutorHqProgressCard()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Loading your progress'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.answer(_hq());
    await _settle(tester);

    expect(find.text("You're almost there"), findsOneWidget);
  });

  testWidgets('shows the promotion ring and the evidence behind it', (
    tester,
  ) async {
    await _pump(tester, _container(FakeTutorsRepository(hq: _hq())));

    expect(find.text("You're almost there"), findsOneWidget);
    expect(
      find.text('You meet the 4.10 average. Just 2 more rated sessions.'),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('to Verified'), findsOneWidget);
    expect(find.text('4.8 average'), findsOneWidget);
    expect(find.text('14 sessions'), findsOneWidget);
    expect(find.text('2 reviews'), findsOneWidget);
    // The standing the API sent is still readable, not replaced by a number.
    expect(find.text('Probationary'), findsOneWidget);

    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, closeTo(0.3333333333333333, 0.0000001));
  });

  testWidgets('names both conditions when the average is short too', (
    tester,
  ) async {
    await _pump(
      tester,
      _container(
        FakeTutorsRepository(
          hq: _hq(
            averageRating: 3.7,
            promotion: _promotion(meetsAverage: false),
          ),
        ),
      ),
    );

    expect(
      find.text('2 more rated sessions and a 4.10 average.'),
      findsOneWidget,
    );
  });

  testWidgets('a verified tutor sees the check and no session countdown', (
    tester,
  ) async {
    await _pump(
      tester,
      _container(
        FakeTutorsRepository(
          hq: _hq(
            standingWire: 'verified',
            standing: TutorStanding.verified,
            promotion: _promotion(
              verified: true,
              ratedSessions: 3,
              sessionsRemaining: 0,
              progress: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text("You're verified"), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('to Verified'), findsNothing);
  });

  testWidgets('a tutor with no ratings says so instead of showing zero', (
    tester,
  ) async {
    await _pump(
      tester,
      _container(
        FakeTutorsRepository(hq: _hq(averageRating: null, ratingCount: 0)),
      ),
    );

    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.text('0 reviews'), findsOneWidget);
  });

  testWidgets('a caller with no tutor profile is offered the way in', (
    tester,
  ) async {
    await _pump(
      tester,
      _container(
        FakeTutorsRepository(
          hq: _hq(
            hasTutorProfile: false,
            standingWire: null,
            standing: null,
            completedSessions: 0,
            averageRating: null,
            ratingCount: 0,
            acceptingRequests: null,
            promotion: _promotion(
              ratedSessions: 0,
              sessionsRemaining: 3,
              meetsAverage: false,
              progress: 0,
            ),
          ),
        ),
      ),
    );

    expect(find.text("You're not a tutor yet"), findsOneWidget);
    expect(find.text('Apply to teach'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failure is a message and a retry, not raw exception text', (
    tester,
  ) async {
    await _pump(
      tester,
      _container(
        FakeTutorsRepository(
          failure: const ServerFailure('The HQ could not be loaded.'),
        ),
      ),
    );

    expect(find.text('The HQ could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('the retry asks the API again and renders what arrives', (
    tester,
  ) async {
    final repository = _FlakyTutorsRepository(recovered: _hq());
    final container = _container(repository);

    await _pump(tester, container);
    expect(repository.attempts, 1);
    expect(find.text('The HQ could not be loaded.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await _settle(tester);

    expect(repository.attempts, 2);
    expect(find.text("You're almost there"), findsOneWidget);
    expect(find.text('The HQ could not be loaded.'), findsNothing);
  });
}
