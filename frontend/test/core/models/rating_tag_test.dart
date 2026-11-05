import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/models/rating_tag.dart';

void main() {
  group('the vocabulary', () {
    test('every tag has a phrase a student would say', () {
      for (final tag in RatingTag.values) {
        expect(tag.label, isNotEmpty);
        // The label is not the wire value with the underscores removed: a chip
        // reading "clear_explanation" is a database field shown to a student.
        expect(tag.label.contains('_'), isFalse);
      }
    });

    test('the wire values are the API contract', () {
      expect(RatingTag.values.map((tag) => tag.wireValue), [
        'clear_explanation',
        'patient',
        'well_prepared',
        'made_it_click',
        'practical_examples',
        'on_time',
      ]);
    });

    test('a value this build does not know is named, not dropped', () {
      // A tag added on the server after this APK shipped is still something a
      // student chose to say. Showing nothing would make a newer review look
      // like it had fewer tags than it does.
      expect(ratingTagLabel('clear_explanation'), 'Explained clearly');
      expect(ratingTagLabel('helps_with_proofs'), 'Helps with proofs');
      expect(ratingTagLabel('onTime'), 'OnTime');
    });

    test('an unknown value never comes back blank', () {
      expect(ratingTagLabel(''), '');
      expect(ratingTagLabel('__'), '__');
    });
  });

  group('reading a tag list', () {
    test('keeps strings and drops anything else', () {
      // Display-only metadata: one bad value should cost that tag, not the whole
      // rating or review it arrived with.
      expect(readRatingTags(['patient', 4, 'on_time', null]), [
        'patient',
        'on_time',
      ]);
    });

    test('an absent or malformed field is no tags', () {
      expect(readRatingTags(null), isEmpty);
      expect(readRatingTags('patient'), isEmpty);
      expect(readRatingTags(<Object?>[]), isEmpty);
    });

    test('the labels come back in the order they were chosen', () {
      expect(ratingTagLabels(['made_it_click', 'patient']), [
        'Made it click',
        'Patient',
      ]);
    });
  });
}
