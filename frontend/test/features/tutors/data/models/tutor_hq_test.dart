import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/models/tutor_standing.dart';
import 'package:peerpass/features/tutors/data/models/tutor_hq.dart';

/// The API's full HQ response for a provisional tutor.
Map<String, dynamic> _payload() {
  return {
    'has_tutor_profile': true,
    'standing': 'probationary',
    'completed_sessions': 14,
    'average_rating': '4.80',
    'rating_count': 2,
    'certified_minutes': 600,
    'certificate_required_minutes': 2400,
    'certificate_remaining_minutes': 1800,
    'certificate_eligible': false,
    'certificate_progress': 0.25,
    'accepting_requests': true,
    'promotion': {
      'verified': false,
      'rated_sessions': 1,
      'sessions_required': 3,
      'sessions_remaining': 2,
      'minimum_average': '4.10',
      'meets_average': true,
      'progress': 0.3333333333333333,
    },
  };
}

void main() {
  test('reads every field from the wire, decimals included', () {
    final hq = TutorHq.fromJson(_payload());

    expect(hq.hasTutorProfile, isTrue);
    expect(hq.standingWire, 'probationary');
    expect(hq.standing, TutorStanding.probationary);
    expect(hq.completedSessions, 14);
    expect(hq.averageRating, 4.8);
    expect(hq.ratingCount, 2);
    expect(hq.certifiedMinutes, 600);
    expect(hq.certificateRequiredMinutes, 2400);
    expect(hq.certificateRemainingMinutes, 1800);
    expect(hq.certificateEligible, isFalse);
    expect(hq.certificateProgress, 0.25);
    expect(hq.acceptingRequests, isTrue);
    expect(hq.promotion.verified, isFalse);
    expect(hq.promotion.ratedSessions, 1);
    expect(hq.promotion.sessionsRequired, 3);
    expect(hq.promotion.sessionsRemaining, 2);
    expect(hq.promotion.minimumAverage, 4.1);
    expect(hq.promotion.meetsAverage, isTrue);
    expect(hq.promotion.progress, closeTo(0.3333333333333333, 0.0000001));
  });

  test('a caller with no tutor profile still parses', () {
    final hq = TutorHq.fromJson(const {
      'has_tutor_profile': false,
      'standing': null,
      'completed_sessions': 0,
      'average_rating': null,
      'rating_count': 0,
      'certified_minutes': 0,
      'certificate_required_minutes': 2400,
      'certificate_remaining_minutes': 0,
      'certificate_eligible': false,
      'certificate_progress': 0.0,
      'accepting_requests': null,
      'promotion': {
        'verified': false,
        'rated_sessions': 0,
        'sessions_required': 3,
        'sessions_remaining': 3,
        'minimum_average': '4.10',
        'meets_average': false,
        'progress': 0.0,
      },
    });

    expect(hq.hasTutorProfile, isFalse);
    expect(hq.standingWire, isNull);
    expect(hq.standing, isNull);
    expect(hq.averageRating, isNull);
    // Null, not false: there is no availability setting to be off.
    expect(hq.acceptingRequests, isNull);
    expect(hq.promotion.sessionsRemaining, 3);
  });

  test('an unrecognised standing is kept verbatim instead of hidden', () {
    final hq = TutorHq.fromJson({..._payload(), 'standing': 'emeritus'});

    expect(hq.standingWire, 'emeritus');
    expect(hq.standing, isNull);
  });

  test('a missing accepting_requests stays null, not false', () {
    final payload = _payload()..remove('accepting_requests');

    final hq = TutorHq.fromJson(payload);

    expect(hq.acceptingRequests, isNull);
  });

  test('a body missing a required counter is a FormatException', () {
    final payload = _payload()..remove('certified_minutes');

    expect(() => TutorHq.fromJson(payload), throwsFormatException);
  });

  test('a body missing the promotion block is a FormatException', () {
    final payload = _payload()..remove('promotion');

    expect(() => TutorHq.fromJson(payload), throwsFormatException);
  });

  test('a required decimal that is not a decimal is a FormatException', () {
    final payload = _payload();
    payload['promotion'] = {
      ...payload['promotion']! as Map<String, dynamic>,
      'minimum_average': 'not-a-number',
    };

    expect(() => TutorHq.fromJson(payload), throwsFormatException);
  });
}
