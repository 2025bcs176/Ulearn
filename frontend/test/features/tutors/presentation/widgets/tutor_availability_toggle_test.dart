import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/models/tutor_standing.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/features/tutors/data/models/tutor_hq.dart';
import 'package:peerpass/features/tutors/data/repositories/fake_tutors_repository.dart';
import 'package:peerpass/features/tutors/data/repositories/tutors_repository.dart';
import 'package:peerpass/features/tutors/presentation/widgets/tutor_availability_toggle.dart';

TutorHq _hq({bool hasTutorProfile = true, bool? acceptingRequests = true}) {
  return TutorHq(
    hasTutorProfile: hasTutorProfile,
    standingWire: hasTutorProfile ? 'probationary' : null,
    standing: hasTutorProfile ? TutorStanding.probationary : null,
    completedSessions: 14,
    averageRating: 4.8,
    ratingCount: 2,
    certifiedMinutes: 600,
    certificateRequiredMinutes: 2400,
    certificateRemainingMinutes: 1800,
    certificateEligible: false,
    certificateProgress: 0.25,
    acceptingRequests: acceptingRequests,
    promotion: const TutorPromotionProgress(
      verified: false,
      ratedSessions: 1,
      sessionsRequired: 3,
      sessionsRemaining: 2,
      minimumAverage: 4.1,
      meetsAverage: true,
      progress: 0.3333333333333333,
    ),
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
          body: Padding(
            padding: EdgeInsets.all(16),
            child: TutorAvailabilityToggle(),
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

/// A repository whose fetch is held open until the test releases it.
class _PendingTutorsRepository extends FakeTutorsRepository {
  final Completer<TutorHq> _completer = Completer<TutorHq>();

  void answer(TutorHq hq) => _completer.complete(hq);

  @override
  Future<TutorHq> myHq() => _completer.future;
}

/// A repository whose saves fail while its summary loads normally.
class _FailingToggleRepository extends FakeTutorsRepository {
  _FailingToggleRepository({required super.hq});

  @override
  Future<TutorHq> setAcceptingRequests(bool accepting) async {
    acceptingRequestsCalls.add(accepting);
    throw const ServerFailure('You could not be paused. Try again.');
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
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TutorAvailabilityToggle(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Loading your availability'), findsOneWidget);

    repository.answer(_hq());
    await _settle(tester);

    expect(find.text('Accepting requests'), findsOneWidget);
  });

  testWidgets('is hidden for a caller with no tutor profile', (tester) async {
    await _pump(
      tester,
      _container(
        FakeTutorsRepository(
          hq: _hq(hasTutorProfile: false, acceptingRequests: null),
        ),
      ),
    );

    // Not an "off" switch: a student has no availability setting to change.
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(AppCard), findsNothing);
    expect(find.text('Accepting requests'), findsNothing);
  });

  testWidgets('is hidden when the summary cannot be read', (tester) async {
    await _pump(
      tester,
      _container(
        FakeTutorsRepository(
          failure: const ServerFailure('The HQ could not be loaded.'),
        ),
      ),
    );

    // The progress card beside it carries the retry; a switch that guessed
    // would invite the tutor to save over a value the app does not know.
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('the switch shows the API value and saves the new one', (
    tester,
  ) async {
    final repository = FakeTutorsRepository(hq: _hq());

    await _pump(tester, _container(repository));

    final before = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(before.value, isTrue);
    expect(find.text('Accepting requests'), findsOneWidget);
    expect(
      find.text('Students can find you and send new requests.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(SwitchListTile));
    await _settle(tester);

    expect(repository.acceptingRequestsCalls, [false]);
    expect(repository.currentHq.acceptingRequests, isFalse);
    final after = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(after.value, isFalse);
    expect(find.textContaining('hidden from student searches'), findsOneWidget);
  });

  testWidgets('a failed save leaves the switch alone and explains why', (
    tester,
  ) async {
    final repository = _FailingToggleRepository(hq: _hq());

    await _pump(tester, _container(repository));

    await tester.tap(find.byType(SwitchListTile));
    await _settle(tester);

    expect(repository.acceptingRequestsCalls, [false]);
    // No optimistic flip: the thumb never moved, so there is nothing to undo.
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
    expect(find.text('You could not be paused. Try again.'), findsOneWidget);
  });

  testWidgets('is disabled while the save is in flight', (tester) async {
    final repository = _SlowToggleRepository(hq: _hq());

    await _pump(tester, _container(repository));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    final saving = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(saving.onChanged, isNull);

    repository.completeSave();
    await _settle(tester);

    final saved = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(saved.value, isFalse);
    expect(saved.onChanged, isNotNull);
  });
}

/// A repository whose availability save is held open by the test.
class _SlowToggleRepository extends FakeTutorsRepository {
  _SlowToggleRepository({required super.hq});

  final Completer<TutorHq> _save = Completer<TutorHq>();
  bool _requested = false;

  void completeSave() {
    _save.complete(currentHq.copyWith(acceptingRequests: _requested));
  }

  @override
  Future<TutorHq> setAcceptingRequests(bool accepting) {
    acceptingRequestsCalls.add(accepting);
    _requested = accepting;
    return _save.future;
  }
}
