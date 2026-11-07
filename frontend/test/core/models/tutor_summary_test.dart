import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/models/tutor_summary.dart';

Map<String, dynamic> _json({Map<String, dynamic> extra = const {}}) {
  return {
    'user_id': 'tutor-1',
    'full_name': 'Grace Okello',
    'standing': 'verified',
    'average_rating': '4.40',
    'completed_sessions': 18,
    ...extra,
  };
}

void main() {
  group('the tutor profile fields', () {
    test('are read when the API sends them', () {
      final tutor = TutorSummary.fromJson(
        _json(
          extra: {
            'bio': 'Third-year CS. I explain recursion with trees.',
            'avatar_url': 'https://cdn.peerpass.test/avatars/grace.jpg',
            'year_of_study': 3,
            'accepting_requests': false,
          },
        ),
      );

      expect(tutor.bio, startsWith('Third-year CS'));
      expect(tutor.avatarUrl, 'https://cdn.peerpass.test/avatars/grace.jpg');
      expect(tutor.yearOfStudy, 3);
      expect(tutor.yearLabel, 'Year 3');
      expect(tutor.hasBio, isTrue);
      expect(tutor.acceptingRequests, isFalse);
    });

    test('null is a normal state, not a parse failure', () {
      // The beta seeds generated avatars and no bios, so every one of these is
      // the common case rather than a fault.
      final tutor = TutorSummary.fromJson(_json());

      expect(tutor.bio, isNull);
      expect(tutor.avatarUrl, isNull);
      expect(tutor.yearOfStudy, isNull);
      expect(tutor.yearLabel, isNull);
      expect(tutor.hasBio, isFalse);
      // Absent means accepting: an older server that predates the pause must
      // not read as every tutor having stopped taking work.
      expect(tutor.acceptingRequests, isTrue);
    });

    test('an empty bio is treated as no bio', () {
      final tutor = TutorSummary.fromJson(_json(extra: {'bio': '   '}));

      expect(tutor.bio, '   ');
      expect(tutor.hasBio, isFalse);
    });

    test('only an explicit false is a pause', () {
      expect(
        TutorSummary.fromJson(
          _json(extra: {'accepting_requests': false}),
        ).acceptingRequests,
        isFalse,
      );
      expect(
        TutorSummary.fromJson(
          _json(extra: {'accepting_requests': true}),
        ).acceptingRequests,
        isTrue,
      );
    });
  });
}
