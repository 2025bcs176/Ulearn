import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/features/sessions/data/models/session_model.dart';
import 'package:peerpass/features/sessions/data/repositories/fake_sessions_repository.dart';

/// A fake that behaves the way the API does about the things a test cannot see.
///
/// The repository tests assert on the wire. This one asserts on the seam widget
/// tests resolve, and a fake that quietly diverges from the API shows up as a
/// screen test passing against behaviour the server does not have.
void main() {
  FakeSessionsRepository repository() {
    return FakeSessionsRepository()
      ..withPendingStudent('student-1', tutorId: 'tutor-1');
  }

  Future<SessionModel> confirm(
    FakeSessionsRepository fake, {
    String requestId = 'request-1',
    int durationMinutes = 45,
  }) {
    return fake.confirmRequest(
      requestId: requestId,
      courseUnitId: 'unit-1',
      topic: 'eigenvalues',
      durationMinutes: durationMinutes,
    );
  }

  group('confirming a request', () {
    test(
      'records what was sent, so a screen test can check the real call',
      () async {
        final fake = repository();

        await confirm(fake, durationMinutes: 75);

        expect(fake.confirmations, hasLength(1));
        expect(fake.confirmations.single.requestId, 'request-1');
        expect(fake.confirmations.single.courseUnitId, 'unit-1');
        expect(fake.confirmations.single.topic, 'eigenvalues');
        expect(fake.confirmations.single.durationMinutes, 75);
      },
    );

    test('returns a scheduled session with nobody checked in yet', () async {
      final fake = repository();

      final created = await confirm(fake);

      expect(created.status, TutoringSessionStatus.scheduled);
      expect(created.helpRequestId, 'request-1');
      expect(created.tuteeId, 'student-1');
      expect(created.tutorId, 'tutor-1');
      expect(created.durationMinutes, 45);
      // The pass starts empty: a session created by a confirmation has no
      // attendance evidence until each party taps. A fake that pre-filled it
      // would let a screen skip the check-in and still pass.
      expect(created.tutorCheckedInAt, isNull);
      expect(created.tuteeCheckedInAt, isNull);
      expect(created.tutorFinishedAt, isNull);
      expect(created.tuteeFinishedAt, isNull);
    });

    test('the created session joins the list the screen already has', () async {
      final fake = repository();
      expect(fake.sessions, isEmpty);

      final created = await confirm(fake);

      expect(fake.sessions.map((s) => s.id), [created.id]);
    });

    test('a second confirmation is refused, as the API refuses it', () async {
      final fake = repository();
      await confirm(fake);

      // The API's unique constraint on the request is the real guarantee. A fake
      // that let a second confirmation through would let a screen ship a button
      // that turns one question into two sessions.
      await expectLater(confirm(fake), throwsA(isA<ConflictFailure>()));
      expect(fake.sessions, hasLength(1));
    });

    test('a zero length is refused the way the API refuses it', () async {
      final fake = repository();

      await expectLater(
        confirm(fake, durationMinutes: 0),
        throwsA(
          isA<ValidationFailure>().having(
            (failure) => failure.fieldErrors,
            'fieldErrors',
            {'duration_minutes': 'must be at least 1'},
          ),
        ),
      );
    });

    test('a refusal is still recorded, so a test can prove it was attempted', () async {
      final fake = repository();

      await expectLater(
        confirm(fake, durationMinutes: 0),
        throwsA(isA<Failure>()),
      );

      // Recorded before the refusal. A fake that only recorded successes would let
      // a screen test pass while the real request was never sent -- which is the
      // exact shape of a bug that a "the button does nothing" report produces.
      expect(fake.confirmations, hasLength(1));
    });
  });

  group('the check-in pass', () {
    SessionModel pass({
      String status = 'scheduled',
      String? startedAt,
      String? tutorCheckedInAt,
      String? tuteeCheckedInAt,
      String? tutorFinishedAt,
      String? tuteeFinishedAt,
    }) {
      return SessionModel.fromJson({
        'id': 'session-pass',
        'tutee_id': 'student-1',
        'tutor_id': 'tutor-1',
        'course_unit_id': 'unit-1',
        'course_unit_code': 'MAT 221',
        'course_unit_name': 'Linear Algebra',
        'topic': 'eigenvalues',
        'status': status,
        'duration_minutes': 60,
        'is_rated': false,
        'created_at': '2026-03-01T08:00:00Z',
        'started_at': startedAt,
        'tutor_checked_in_at': tutorCheckedInAt,
        'tutee_checked_in_at': tuteeCheckedInAt,
        'tutor_finished_at': tutorFinishedAt,
        'tutee_finished_at': tuteeFinishedAt,
      });
    }

    test('one check-in leaves the session scheduled', () async {
      final fake = FakeSessionsRepository(sessions: [pass()])
        ..currentUser = 'student-1';

      final checkedIn = await fake.checkIn(sessionId: 'session-pass');

      expect(fake.checkedInSessionIds, ['session-pass']);
      expect(checkedIn.tuteeCheckedInAt, isNotNull);
      expect(checkedIn.tutorCheckedInAt, isNull);
      // One account saying it is here is not evidence that anybody met. The
      // session stays scheduled until the other party taps.
      expect(checkedIn.status, TutoringSessionStatus.scheduled);
    });

    test('the second check-in starts the session', () async {
      final fake = FakeSessionsRepository(
        sessions: [pass(tutorCheckedInAt: '2026-03-04T09:00:00Z')],
      )..currentUser = 'student-1';

      final live = await fake.checkIn(sessionId: 'session-pass');

      expect(live.tutorCheckedInAt, DateTime.utc(2026, 3, 4, 9));
      expect(live.tuteeCheckedInAt, isNotNull);
      expect(live.status, TutoringSessionStatus.inProgress);
      expect(live.startedAt, isNotNull);
    });

    test('a retried check-in does not move the recorded time', () async {
      final fake = FakeSessionsRepository(sessions: [pass()])
        ..currentUser = 'student-1';

      final first = await fake.checkIn(sessionId: 'session-pass');
      final retried = await fake.checkIn(sessionId: 'session-pass');

      expect(retried.tuteeCheckedInAt, first.tuteeCheckedInAt);
    });

    test('finish before both parties checked in is refused', () async {
      final fake = FakeSessionsRepository(
        sessions: [pass(tutorCheckedInAt: '2026-03-04T09:00:00Z')],
      )..currentUser = 'tutor-1';

      await expectLater(
        fake.finish(sessionId: 'session-pass'),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('one finish leaves the session live', () async {
      final fake = FakeSessionsRepository(
        sessions: [
          pass(
            status: 'in_progress',
            startedAt: '2026-03-04T09:00:00Z',
            tutorCheckedInAt: '2026-03-04T09:00:00Z',
            tuteeCheckedInAt: '2026-03-04T09:02:00Z',
          ),
        ],
      )..currentUser = 'tutor-1';

      final finished = await fake.finish(sessionId: 'session-pass');

      expect(fake.finishedSessionIds, ['session-pass']);
      expect(finished.tutorFinishedAt, isNotNull);
      expect(finished.tuteeFinishedAt, isNull);
      // The other party has not said they are done, so the session is not over.
      expect(finished.status, TutoringSessionStatus.inProgress);
    });

    test(
      'the earlier departure closes the session and sets the hours',
      () async {
        final fake = FakeSessionsRepository(
          sessions: [
            pass(
              status: 'in_progress',
              startedAt: '2026-03-04T09:00:00Z',
              tutorCheckedInAt: '2026-03-04T09:00:00Z',
              tuteeCheckedInAt: '2026-03-04T09:02:00Z',
              // The student left at 09:30. The tutor finishing later must not
              // extend the session past the time the student can confirm.
              tuteeFinishedAt: '2026-03-04T09:30:00Z',
            ),
          ],
        )..currentUser = 'tutor-1';

        final completed = await fake.finish(sessionId: 'session-pass');

        expect(completed.status, TutoringSessionStatus.completed);
        expect(completed.endedAt, DateTime.utc(2026, 3, 4, 9, 30));
        expect(completed.durationMinutes, 30);
      },
    );

    test('a session that did not happen cannot be checked into', () async {
      final fake = FakeSessionsRepository(sessions: [pass(status: 'cancelled')])
        ..currentUser = 'student-1';

      await expectLater(
        fake.checkIn(sessionId: 'session-pass'),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });
}
