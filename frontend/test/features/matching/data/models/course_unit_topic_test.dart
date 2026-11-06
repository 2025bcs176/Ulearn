import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/features/matching/data/models/course_unit_topic.dart';

void main() {
  group('reading a suggestion', () {
    test('keeps the id, label and order', () {
      final topic = CourseUnitTopic.fromJson(const {
        'id': 'topic-1',
        'label': 'SQL SELECT queries',
        'sort_order': 2,
      });

      expect(topic.publicId, 'topic-1');
      expect(topic.label, 'SQL SELECT queries');
      expect(topic.sortOrder, 2);
    });

    test('an absent order is zero, not a missing suggestion', () {
      final topic = CourseUnitTopic.fromJson(const {
        'id': 'topic-1',
        'label': 'Normalisation',
      });

      expect(topic.sortOrder, 0);
      expect(topic.label, 'Normalisation');
    });

    test('a suggestion with no phrase to show fails', () {
      // A chip with no label is a blank tap target; there is no neutral reading
      // of it, and the repository turns this into a message.
      for (final wire in [
        {'id': 'topic-1'},
        {'id': 'topic-1', 'label': ''},
        {'id': 'topic-1', 'label': '   '},
        {'label': 'Normalisation'},
      ]) {
        expect(
          () => CourseUnitTopic.fromJson(wire),
          throwsFormatException,
          reason: '$wire',
        );
      }
    });

    test('two suggestions are equal by their whole content', () {
      expect(
        CourseUnitTopic.fromJson(const {
          'id': 'topic-1',
          'label': 'Normalisation',
        }),
        CourseUnitTopic.fromJson(const {
          'id': 'topic-1',
          'label': 'Normalisation',
        }),
      );
    });
  });
}
