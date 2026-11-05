import 'package:dio/dio.dart';
import 'package:peerpass/core/storage/session_cache.dart';

/// Talks to the `/v1/sessions` and `/v1/ratings` endpoints the screens use.
///
/// Throws [DioException], not a `Failure`. Classification belongs to
/// `core/network/network_exceptions.dart` and happens once, in the repository, so
/// a socket error and an RFC 9457 problem document are translated by the same
/// code whichever endpoint produced them. Bodies come back as raw JSON on purpose:
/// the repository is where the wire shape becomes a model, so there is one place
/// to look when the two disagree.
class RemoteSessionsDatasource {
  const RemoteSessionsDatasource(this._dio, {this.cache});

  final Dio _dio;
  final SessionCache? cache;

  /// Every session the signed-in user is part of, newest first.
  ///
  /// One request rather than a page per status: the API returns the caller's
  /// whole history in its own order, and the sessions screen only groups what
  /// comes back. Asking the server to pre-sort or pre-filter would be a second
  /// place where "active" is defined.
  Future<List<Map<String, dynamic>>> sessionsForMe() async {
    try {
      final response = await _dio.get<List<dynamic>>('/v1/sessions/me');
      final sessions = (response.data ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();
      await cache?.writeSessions(sessions);
      return sessions;
    } on DioException catch (error) {
      if (!_canUseCache(error)) rethrow;
      final cached = await cache?.readSessions();
      if (cached != null) {
        return [
          for (final row in cached) {...row, '_offline_cached': true},
        ];
      }
      rethrow;
    }
  }

  bool _canUseCache(DioException error) =>
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout;

  /// One session, re-read by public id.
  Future<Map<String, dynamic>> session(String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/sessions/$sessionId',
    );
    return response.data!;
  }

  /// Records the caller's own arrival, returning the session as it now stands.
  ///
  /// A bodyless POST because the only thing that identifies the party is the
  /// access token: a client cannot check in on behalf of anyone else, and there
  /// is no code to carry. The session goes live only when the other account
  /// has checked in too, which the API decides.
  ///
  /// Idempotent. A phone on a metered connection retrying the same tap is
  /// ordinary, and the API answers 200 without moving the recorded timestamp.
  Future<Map<String, dynamic>> checkIn(String sessionId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/sessions/$sessionId/check-in',
    );
    return response.data!;
  }

  /// Records the caller's own departure, returning the session as it now stands.
  ///
  /// A bodyless POST for the same reason as [checkIn]. The session completes
  /// only when both parties have finished, and the API records the earlier of
  /// the two departures as the end so a late tap cannot extend the hours.
  Future<Map<String, dynamic>> finish(String sessionId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/sessions/$sessionId/finish',
    );
    return response.data!;
  }

  /// Creates the session that a tutor confirmed a help request into.
  ///
  /// The request id is in the body rather than the path because the resource
  /// being created is a session, not a sub-resource of the request: the API
  /// refuses the call unless the request is one this tutor was named on and is
  /// still waiting, so the request id identifies *what is being confirmed* rather
  /// than naming the created thing.
  ///
  /// [courseUnitId] is sent because the API requires it, and the API then checks
  /// it against the request's own unit -- a mismatch is refused rather than
  /// trusted. `topic` is the student's own question as the tutor read it on the
  /// request; it is what the session is titled in both apps, so it is not left to
  /// the client to invent and not reworded into something the student did not ask.
  Future<Map<String, dynamic>> createFromRequest(
    String requestId, {
    required String courseUnitId,
    required String topic,
    required int durationMinutes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/sessions',
      data: <String, dynamic>{
        'help_request_id': requestId,
        'course_unit_id': courseUnitId,
        'topic': topic,
        'duration_minutes': durationMinutes,
      },
    );
    return response.data!;
  }

  /// Creates or updates the rating the signed-in user gives for a session.
  ///
  /// The session comes from the path, never from the body, so a client cannot
  /// rate a session it was not part of by sending someone else's id.
  Future<Map<String, dynamic>> submitRating(
    String sessionId, {
    required int score,
    required bool comprehensionHelped,
    String? feedbackText,
    List<String> tags = const [],
    List<String> endorsedCourseUnitIds = const [],
  }) async {
    final data = <String, dynamic>{
      'score': score,
      'comprehension_helped': comprehensionHelped,
    };
    // Only sent when there is something to say. A null `feedback_text` would be
    // read as "clear whatever was stored", which is not what an untouched field
    // on a re-submit means.
    if (feedbackText != null) data['feedback_text'] = feedbackText;
    // Sent only when tags were picked. A rating with no tags and a rating whose
    // tags were never offered are the same submission, and an empty list would
    // be a client asserting that the student chose none when nobody asked.
    if (tags.isNotEmpty) data['tags'] = tags;
    // The endorsements are sent as the API wants them: a list, absent when there is
    // nothing to claim. Note that "absent" and "empty" are the *same request* here
    // -- `RatingCreate.endorsed_course_unit_ids` defaults to an empty list, so
    // omitting the key arrives server-side as `[]`. That is not a way of leaving an
    // existing endorsement alone: the service replaces the set on every
    // submission, so an empty list withdraws what was there. Nothing this client
    // can do about it -- `RatingResponse` does not echo a rater's own endorsements,
    // so there is nowhere to read back what would be withdrawn. The rating screen
    // says so on a re-submission instead of letting it happen quietly.
    if (endorsedCourseUnitIds.isNotEmpty) {
      data['endorsed_course_unit_ids'] = endorsedCourseUnitIds;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/ratings/$sessionId',
      data: data,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>?> receivedRating(String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>?>(
      '/v1/ratings/session/$sessionId',
    );
    return response.data;
  }
}
