import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/features/tutors/data/models/tutor_review.dart';

Map<String, dynamic> _review({
  String id = 'review-1',
  int score = 5,
  String initials = 'AO',
  List<Object?>? tags = const ['patient'],
  String createdAt = '2026-03-04T11:00:00Z',
}) {
  return {
    'id': id,
    'score': score,
    'rater_initials': initials,
    'tags': ?tags,
    'created_at': createdAt,
  };
}

void main() {
  group('reading a review', () {
    test('keeps the score, initials, tags and date', () {
      final review = TutorReview.fromJson(
        _review(tags: const ['made_it_click', 'patient']),
      );

      expect(review.id, 'review-1');
      expect(review.score, 5);
      expect(review.raterInitials, 'AO');
      expect(review.tags, ['made_it_click', 'patient']);
      expect(review.createdAt, DateTime.utc(2026, 3, 4, 11));
    });

    test('a review with no tags is still a review', () {
      // Tags are optional on the wire because a student can score a tutor and
      // say nothing else. Reading that absence as a malformed response would
      // hide reviews the API published.
      final review = TutorReview.fromJson(_review(tags: null));

      expect(review.score, 5);
      expect(review.tags, isEmpty);
    });

    test('the payload carries no name, id or note to read', () {
      // The public shape is deliberately narrower than a rating: initials and a
      // score, never the rater, and never the note they confided. A review that
      // parsed those would be a client inviting a field the API must not send.
      final wire = _review();
      expect(wire.containsKey('rater_id'), isFalse);
      expect(wire.containsKey('feedback_text'), isFalse);
      expect(wire.containsKey('rater_name'), isFalse);
    });

    test('an unknown tag is kept for display rather than dropped', () {
      // A tag added after this build shipped is still something a student
      // chose to say; only its label is missing.
      final review = TutorReview.fromJson(
        _review(tags: const ['helps_with_proofs']),
      );

      expect(review.tags, ['helps_with_proofs']);
    });

    test('a review missing a field it cannot be drawn without fails', () {
      for (final field in ['id', 'score', 'rater_initials', 'created_at']) {
        final wire = _review()..remove(field);
        expect(
          () => TutorReview.fromJson(wire),
          throwsFormatException,
          reason: 'missing $field',
        );
      }
    });

    test('an unparseable date is a format failure, not a silent now', () {
      expect(
        () => TutorReview.fromJson(_review(createdAt: 'yesterday')),
        throwsFormatException,
      );
    });

    test('two reviews are equal by their whole content', () {
      expect(TutorReview.fromJson(_review()), TutorReview.fromJson(_review()));
      expect(
        TutorReview.fromJson(_review()),
        isNot(TutorReview.fromJson(_review(id: 'review-2'))),
      );
    });
  });
}
