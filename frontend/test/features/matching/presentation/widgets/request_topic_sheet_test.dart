import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/features/matching/data/models/course_unit_topic.dart';
import 'package:peerpass/features/matching/data/repositories/fake_matching_repository.dart';
import 'package:peerpass/features/matching/data/repositories/matching_repository.dart';
import 'package:peerpass/features/matching/presentation/widgets/request_topic_sheet.dart';

CourseUnitTopic _topic(String label) {
  return CourseUnitTopic(publicId: 'topic-$label', label: label);
}

/// A screen with a button that opens the sheet, and the draft it returned.
class _Harness {
  _Harness(this.repository, {this.courseUnitId = 'unit-1', this.initialTopic});

  final FakeMatchingRepository repository;
  final String courseUnitId;
  final String? initialTopic;

  /// The sheet's answer, once it has closed. Null while it is open or after a
  /// cancel, which are the same thing to a caller.
  RequestDraft? draft;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matchingRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    draft = await showRequestTopicSheet(
                      context,
                      courseUnitId: courseUnitId,
                      initialTopic: initialTopic,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }
}

Future<void> _choose(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester) async {
  final button = find.widgetWithText(AppButton, 'Ask this tutor');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers the unit own suggestions as chips', (tester) async {
    final repository = FakeMatchingRepository(
      topicsByUnit: {
        'unit-1': [_topic('Normalisation'), _topic('SQL SELECT queries')],
      },
    );
    final harness = _Harness(repository);
    await harness.pump(tester);
    await harness.open(tester);

    expect(find.text('Common questions in this unit'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Normalisation'), findsOneWidget);
    expect(
      find.widgetWithText(ChoiceChip, 'SQL SELECT queries'),
      findsOneWidget,
    );
    // The sheet asked about the unit it was handed, not a fixed one.
    expect(repository.topicRequests, ['unit-1']);
    // Nothing is sent by merely opening the sheet.
    expect(harness.draft, isNull);
  });

  testWidgets('tapping a chip fills the topic and sends that phrase', (
    tester,
  ) async {
    final repository = FakeMatchingRepository(
      topicsByUnit: {
        'unit-1': [_topic('Normalisation'), _topic('Joins and subqueries')],
      },
    );
    final harness = _Harness(repository);
    await harness.pump(tester);
    await harness.open(tester);

    await _choose(tester, 'Joins and subqueries');

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Joins and subqueries'),
    );
    expect(chip.selected, isTrue);

    await _ask(tester);

    // The phrase travels as the student's own words: the API takes free text,
    // not a topic id a tutor would have to resolve.
    expect(harness.draft?.topic, 'Joins and subqueries');
  });

  testWidgets('a suggestion is a starting point, not a lock', (tester) async {
    final repository = FakeMatchingRepository(
      topicsByUnit: {
        'unit-1': [_topic('Normalisation')],
      },
    );
    final harness = _Harness(repository);
    await harness.pump(tester);
    await harness.open(tester);

    await _choose(tester, 'Normalisation');
    await tester.enterText(find.byType(TextField).first, 'Third normal form');
    await tester.pumpAndSettle();
    await _ask(tester);

    expect(harness.draft?.topic, 'Third normal form');
  });

  testWidgets('asks about the unit it was opened for', (tester) async {
    final repository = FakeMatchingRepository(
      topicsByUnit: {
        'unit-1': [_topic('Normalisation')],
        'unit-2': [_topic('Pointers and memory')],
      },
    );
    final harness = _Harness(repository, courseUnitId: 'unit-2');
    await harness.pump(tester);
    await harness.open(tester);

    expect(repository.topicRequests, ['unit-2']);
    expect(
      find.widgetWithText(ChoiceChip, 'Pointers and memory'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ChoiceChip, 'Normalisation'), findsNothing);
  });

  testWidgets('keeps the composer question as the starting text', (
    tester,
  ) async {
    final repository = FakeMatchingRepository(
      topicsByUnit: {
        'unit-1': [_topic('Normalisation')],
      },
    );
    final harness = _Harness(
      repository,
      initialTopic: 'How do I normalise a table?',
    );
    await harness.pump(tester);
    await harness.open(tester);

    // A quick question typed on Home is not thrown away by opening the sheet.
    expect(find.text('How do I normalise a table?'), findsOneWidget);
    await _ask(tester);
    expect(harness.draft?.topic, 'How do I normalise a table?');
  });

  testWidgets('a unit with no suggestions still takes a typed topic', (
    tester,
  ) async {
    final harness = _Harness(FakeMatchingRepository());
    await harness.pump(tester);
    await harness.open(tester);

    expect(find.byType(ChoiceChip), findsNothing);
    // No chips is not an error: the free-text field is the feature and the
    // suggestions are only an aid.
    await tester.enterText(find.byType(TextField).first, 'Eigenvalues');
    await tester.pumpAndSettle();
    await _ask(tester);

    expect(harness.draft?.topic, 'Eigenvalues');
  });

  testWidgets('a failed suggestion query does not block the form', (
    tester,
  ) async {
    final repository = FakeMatchingRepository(
      onCourseUnitTopics: (_) async => throw Exception('the network is gone'),
    );
    final harness = _Harness(repository);
    await harness.pump(tester);
    await harness.open(tester);

    // Said, not hidden, and never the exception's own text.
    expect(
      find.text(
        'Common questions could not be loaded. You can still write your own.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Retry suggestions'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Recursion');
    await tester.pumpAndSettle();
    await _ask(tester);

    expect(harness.draft?.topic, 'Recursion');
  });

  testWidgets('the retry asks again and shows what arrives', (tester) async {
    var attempts = 0;
    final repository = FakeMatchingRepository(
      onCourseUnitTopics: (_) async {
        attempts++;
        if (attempts == 1) throw Exception('the network is gone');
        return [_topic('Normalisation')];
      },
    );
    final harness = _Harness(repository);
    await harness.pump(tester);
    await harness.open(tester);

    expect(find.byTooltip('Retry suggestions'), findsOneWidget);
    await tester.tap(find.byTooltip('Retry suggestions'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.widgetWithText(ChoiceChip, 'Normalisation'), findsOneWidget);
  });
}
