import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/features/sessions/data/datasources/remote_sessions_datasource.dart';
import 'package:peerpass/features/sessions/data/models/session_model.dart';
import 'package:peerpass/features/sessions/data/repositories/remote_sessions_repository.dart';

/// A recorded request, so a test can assert on what the client actually sent.
class _Call {
  _Call(this.method, this.path, this.body);

  final String method;
  final String path;
  final Object? body;

  @override
  String toString() => '$method $path $body';
}

/// Answers requests from a script, and records what it was asked.
///
/// Copied in shape from the auth repository's server: the thing under test here is
/// the wire -- which path, which field names, which body -- and a mock at the
/// datasource boundary would let a renamed field pass.
class _FakeServer implements HttpClientAdapter {
  final List<_Call> calls = [];
  final List<Object?> _replies = [];

  void reply(int status, Object? body) => _replies.add(_Reply(status, body));

  void fail(DioException error) => _replies.add(error);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(_Call(options.method, options.path, _decode(options.data)));

    final reply = _replies.removeAt(0);
    if (reply is DioException) throw reply;

    final r = reply! as _Reply;
    return ResponseBody.fromString(
      r.body == null ? '' : jsonEncode(r.body),
      r.status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Object? _decode(Object? data) {
  if (data is! String) return data;
  try {
    return jsonDecode(data);
  } on FormatException {
    return data;
  }
}

class _Reply {
  _Reply(this.status, this.body);

  final int status;
  final Object? body;
}

Map<String, dynamic> _session({
  String id = 'session-1',
  String status = 'scheduled',
}) {
  return {
    'id': id,
    'help_request_id': 'request-1',
    'tutee_id': 'student-1',
    'tutor_id': 'tutor-1',
    'course_unit_id': 'unit-1',
    'course_unit_code': 'MAT 221',
    'course_unit_name': 'Linear Algebra',
    'tutee_name': 'Adongo Sarah',
    'tutor_name': 'Okello Daniel',
    'topic': 'Second order ODEs',
    'status': status,
    'duration_minutes': 60,
    'is_rated': false,
    'created_at': '2026-03-01T08:00:00Z',
    'scheduled_start': '2026-03-04T09:00:00Z',
    'meeting_link': null,
  };
}

Map<String, dynamic> _rating({
  int score = 5,
  String? feedback,
  List<String> tags = const [],
}) {
  return {
    'id': 'rating-1',
    'session_id': 'session-1',
    'rater_id': 'student-1',
    'ratee_id': 'tutor-1',
    'score': score,
    'feedback_text': ?feedback,
    'tags': tags,
    'created_at': '2026-03-04T11:00:00Z',
  };
}

/// The API's own refusal, as `SessionCreate`'s sibling endpoints produce it.
Map<String, dynamic> _problem({
  int status = 422,
  String title = 'Validation failed',
  String detail = 'The server refused that change.',
  Map<String, String>? errors,
}) {
  return {
    'type': 'https://peerpass.app/problems/validation',
    'title': title,
    'status': status,
    'detail': detail,
    'errors': ?errors,
  };
}

void main() {
  late _FakeServer server;
  late RemoteSessionsRepository repository;

  setUp(() {
    server = _FakeServer();
    // validateStatus matches the production client, so a 4xx throws here exactly
    // as it would against the real API. A test client that returned error statuses
    // as values would never exercise the failure mapping.
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.peerpass.test',
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    )..httpClientAdapter = server;

    repository = RemoteSessionsRepository(RemoteSessionsDatasource(dio));
  });

  group('listing sessions', () {
    test('asks the endpoint the API documents, and parses the list', () async {
      server.reply(200, [_session(), _session(id: 'session-2')]);

      final sessions = await repository.sessionsForMe();

      expect(server.calls.single.method, 'GET');
      expect(server.calls.single.path, '/v1/sessions/me');
      expect(sessions.map((s) => s.id), ['session-1', 'session-2']);
      expect(sessions.first.status, TutoringSessionStatus.scheduled);
    });

    test('a session that is not found is a not-found failure', () async {
      server.reply(404, _problem(status: 404, detail: 'Session not found.'));

      await expectLater(
        repository.session('missing'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('a dropped connection is a network failure, not a crash', () async {
      server.fail(
        DioException(
          requestOptions: RequestOptions(path: '/v1/sessions/me'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repository.sessionsForMe(),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test(
      'a body the client cannot read is reported, not rethrown raw',
      () async {
        // A server fault, not a student's problem. Surfaced as a message a person can
        // act on rather than as a FormatException from inside a model.
        server.reply(200, [
          {'id': 'session-1', 'status': 'scheduled'},
        ]);

        await expectLater(
          repository.sessionsForMe(),
          throwsA(
            isA<ServerFailure>().having(
              (f) => f.message,
              'message',
              contains('could not read'),
            ),
          ),
        );
      },
    );
  });

  group('checking in', () {
    test('posts to the check-in endpoint with no body', () async {
      server.reply(200, _session(status: 'in_progress'));

      final session = await repository.checkIn(sessionId: 'session-1');

      expect(server.calls.single.method, 'POST');
      expect(server.calls.single.path, '/v1/sessions/session-1/check-in');
      // The token identifies the party. A body naming a user would be a client
      // able to check in for someone else.
      expect(server.calls.single.body, isNull);
      expect(session.status, TutoringSessionStatus.inProgress);
    });

    test(
      'a session that is no longer open surfaces the API sentence',
      () async {
        server.reply(
          409,
          _problem(
            status: 409,
            detail: 'This session is no longer open for check-in.',
          ),
        );

        await expectLater(
          repository.checkIn(sessionId: 'session-1'),
          throwsA(
            isA<ConflictFailure>().having(
              (f) => f.message,
              'message',
              'This session is no longer open for check-in.',
            ),
          ),
        );
      },
    );
  });

  group('finishing', () {
    test('posts to the finish endpoint with no body', () async {
      server.reply(200, _session(status: 'completed'));

      final session = await repository.finish(sessionId: 'session-1');

      expect(server.calls.single.method, 'POST');
      expect(server.calls.single.path, '/v1/sessions/session-1/finish');
      expect(server.calls.single.body, isNull);
      // The client does not stamp its own end time: the API records the hours,
      // and a duration the client invented is one the certificate maths would
      // trust.
      expect(session.status, TutoringSessionStatus.completed);
    });

    test('finishing before the session is live is a conflict', () async {
      server.reply(
        409,
        _problem(
          status: 409,
          detail:
              'Only a session both parties have checked in to can be finished.',
        ),
      );

      await expectLater(
        repository.finish(sessionId: 'session-1'),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('rating', () {
    test('posts the score and the note to the rating endpoint', () async {
      server.reply(201, _rating(score: 4, feedback: 'Clear and patient.'));

      final rating = await repository.rateSession(
        sessionId: 'session-1',
        score: 4,
        comprehensionHelped: true,
        feedbackText: 'Clear and patient.',
      );

      expect(server.calls.single.method, 'POST');
      expect(server.calls.single.path, '/v1/ratings/session-1');
      expect(server.calls.single.body, {
        'score': 4,
        'comprehension_helped': true,
        'feedback_text': 'Clear and patient.',
      });
      expect(rating.score, 4);
    });

    test('omits the note entirely when there is none to send', () async {
      // A blank note is the absence of a note. Sending `''` would assert that the
      // field is empty, which is a different claim and would overwrite a stored
      // note on a re-submission.
      server.reply(201, _rating());

      await repository.rateSession(
        sessionId: 'session-1',
        score: 5,
        comprehensionHelped: true,
      );

      expect(server.calls.single.body, {
        'score': 5,
        'comprehension_helped': true,
      });
    });

    test('sends the endorsed unit only when one is endorsed', () async {
      // The field is `endorsed_course_unit_ids`, a list, and an empty list is a
      // legitimate submission meaning "no endorsement". The API only accepts the
      // session's own course unit, so the client has nothing to choose: it either
      // names that unit or sends no field at all.
      server.reply(201, _rating());
      await repository.rateSession(
        sessionId: 'session-1',
        score: 5,
        comprehensionHelped: true,
      );
      server.reply(201, _rating());
      await repository.rateSession(
        sessionId: 'session-1',
        score: 5,
        comprehensionHelped: true,
        endorsedCourseUnitIds: ['unit-1'],
      );

      expect(server.calls.first.body, {
        'score': 5,
        'comprehension_helped': true,
      });
      expect(server.calls.last.body, {
        'score': 5,
        'comprehension_helped': true,
        'endorsed_course_unit_ids': ['unit-1'],
      });
    });

    test(
      'sends the tags in the order they were picked, and none when empty',
      () async {
        server.reply(201, _rating(tags: ['made_it_click', 'patient']));
        final rated = await repository.rateSession(
          sessionId: 'session-1',
          score: 5,
          comprehensionHelped: true,
          tags: ['made_it_click', 'patient'],
        );
        server.reply(201, _rating());
        await repository.rateSession(
          sessionId: 'session-1',
          score: 5,
          comprehensionHelped: true,
        );

        expect(server.calls.first.body, {
          'score': 5,
          'comprehension_helped': true,
          'tags': ['made_it_click', 'patient'],
        });
        // No tags is an absence, not an assertion that the student chose none
        // from a list -- the same reasoning as the blank note above.
        expect(server.calls.last.body, {
          'score': 5,
          'comprehension_helped': true,
        });
        expect(rated.tags, ['made_it_click', 'patient']);
      },
    );

    test('a score the API refuses is a validation failure', () async {
      server.reply(
        422,
        _problem(
          detail: 'Score must be between 1 and 5.',
          errors: {'score': 'out of range'},
        ),
      );

      await expectLater(
        repository.rateSession(
          sessionId: 'session-1',
          score: 6,
          comprehensionHelped: true,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('confirming a help request', () {
    Future<SessionModel> confirm() => repository.confirmRequest(
      requestId: 'request-1',
      courseUnitId: 'unit-1',
      topic: 'Second order ODEs',
      durationMinutes: 45,
    );

    test('posts the four fields the API documents, and nothing else', () async {
      server.reply(201, _session());

      final created = await confirm();

      expect(server.calls.single.method, 'POST');
      expect(server.calls.single.path, '/v1/sessions');
      // The body is asserted in full rather than key by key. A confirmation that
      // also sent a `status`, a `scheduled_start`, or a `tutee_id` would be a
      // client deciding things the API derives from the request, and an added key
      // is exactly the kind of change that looks harmless in review.
      expect(server.calls.single.body, {
        'help_request_id': 'request-1',
        'course_unit_id': 'unit-1',
        'topic': 'Second order ODEs',
        'duration_minutes': 45,
      });
      expect(created.id, 'session-1');
    });

    test('the duration is sent as the number the tutor typed', () async {
      server.reply(201, _session());

      await repository.confirmRequest(
        requestId: 'request-1',
        courseUnitId: 'unit-1',
        topic: 'graphs',
        durationMinutes: 90,
      );

      expect((server.calls.single.body! as Map)['duration_minutes'], 90);
    });

    test('a request someone else already confirmed is a conflict', () async {
      // The API refuses a second confirmation, and the reason it can is the unique
      // constraint on the request. A client that treated this as a server fault
      // would tell a tutor their tap failed when in fact the session exists.
      server.reply(
        409,
        _problem(
          status: 409,
          title: 'Conflict',
          detail: 'This help request is not waiting for your answer.',
        ),
      );

      await expectLater(confirm(), throwsA(isA<ConflictFailure>()));
    });

    test('a refused length names the field rather than arriving raw', () async {
      server.reply(
        422,
        _problem(
          detail: 'That length is not one the API accepts.',
          errors: {'duration_minutes': 'must be at most 480'},
        ),
      );

      await expectLater(
        confirm(),
        throwsA(
          isA<ValidationFailure>().having(
            (failure) => failure.fieldErrors,
            'fieldErrors',
            {'duration_minutes': 'must be at most 480'},
          ),
        ),
      );
    });

    test('a tutor with no access is an authorization failure', () async {
      server.reply(
        403,
        _problem(
          status: 403,
          title: 'Forbidden',
          detail: 'Only the tutor the student chose can confirm this request.',
        ),
      );

      await expectLater(confirm(), throwsA(isA<AuthFailure>()));
    });

    test('a dropped connection is a network failure, not a crash', () async {
      server.fail(
        DioException(
          requestOptions: RequestOptions(path: '/v1/sessions'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(confirm(), throwsA(isA<NetworkFailure>()));
    });
  });
}
