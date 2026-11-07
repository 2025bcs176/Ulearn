import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/models/course_unit.dart';
import 'package:peerpass/core/models/tutor_standing.dart';
import 'package:peerpass/core/models/tutor_summary.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/features/tutors/data/models/tutor_detail.dart';
import 'package:peerpass/features/tutors/data/models/tutor_review.dart';
import 'package:peerpass/features/tutors/data/repositories/fake_tutors_repository.dart';
import 'package:peerpass/features/tutors/data/repositories/tutors_repository.dart';
import 'package:peerpass/features/tutors/presentation/screens/tutor_detail_screen.dart';

TutorDetail _detail({String? bio}) {
  return TutorDetail(
    profile: TutorSummary(
      userId: 'tutor-1',
      fullName: 'Grace Okello',
      standing: TutorStanding.verified,
      standingWire: 'verified',
      averageRating: 4.6,
      completedSessions: 12,
      bio: bio,
    ),
    endorsedCourseUnitIds: const ['unit-1'],
    endorsementCount: 1,
  );
}

TutorReview _review({
  String id = 'review-1',
  int score = 5,
  String initials = 'AO',
  List<String> tags = const ['patient'],
  DateTime? createdAt,
}) {
  return TutorReview(
    id: id,
    score: score,
    raterInitials: initials,
    tags: tags,
    createdAt: createdAt ?? DateTime(2026, 3, 4),
  );
}

/// A repository whose review query fails, to prove the profile survives it.
class _FailingReviewsRepository extends FakeTutorsRepository {
  _FailingReviewsRepository({required super.profiles});

  @override
  Future<List<TutorReview>> reviews(String userId, {int? limit}) async {
    throw const ServerFailure('The reviews could not be loaded.');
  }
}

/// A repository that fails the first review query and answers the next one.
class _FlakyReviewsRepository extends FakeTutorsRepository {
  _FlakyReviewsRepository({required super.profiles, required this.replies});

  final List<TutorReview> replies;

  int attempts = 0;

  @override
  Future<List<TutorReview>> reviews(String userId, {int? limit}) async {
    attempts++;
    if (attempts == 1) {
      throw const ServerFailure('The reviews could not be loaded.');
    }
    return List<TutorReview>.unmodifiable(
      limit == null ? replies : replies.take(limit),
    );
  }
}

/// Pumps the profile against [repository].
///
/// The surface is made tall because the screen is a list and the reviews sit
/// under the standing, the stats and the endorsed units; a lazy list would not
/// build a section that far below the fold, and a test that scrolled to it would
/// be asserting on the scroll position as much as on the reviews.
Future<void> _pump(WidgetTester tester, TutorsRepository repository) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [tutorsRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const TutorDetailScreen(userId: 'tutor-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the bio', () {
    testWidgets('is shown when the tutor wrote one', (tester) async {
      await _pump(
        tester,
        FakeTutorsRepository(
          profiles: [
            _detail(bio: 'Third-year CS. I make hard proofs feel obvious.'),
          ],
          courseUnits: const [
            CourseUnit(
              publicId: 'unit-1',
              code: 'MAT 221',
              name: 'Linear Algebra II',
            ),
          ],
        ),
      );

      expect(find.text('About'), findsOneWidget);
      expect(
        find.text('Third-year CS. I make hard proofs feel obvious.'),
        findsOneWidget,
      );
    });

    testWidgets('and its heading are absent for a tutor without one', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeTutorsRepository(
          profiles: [_detail()],
          courseUnits: const [
            CourseUnit(
              publicId: 'unit-1',
              code: 'MAT 221',
              name: 'Linear Algebra II',
            ),
          ],
        ),
      );

      // An empty "About" heading with nothing under it reads like a field the
      // tutor forgot, when the API simply has no bio to show.
      expect(find.text('About'), findsNothing);
      expect(find.text('Grace Okello'), findsOneWidget);
    });
  });

  group('the reviews', () {
    testWidgets('are asked for by the tutor the profile is about', (
      tester,
    ) async {
      final repository = FakeTutorsRepository(
        profiles: [_detail()],
        courseUnits: const [
          CourseUnit(
            publicId: 'unit-1',
            code: 'MAT 221',
            name: 'Linear Algebra II',
          ),
        ],
        reviews: [_review()],
      );

      await _pump(tester, repository);

      expect(repository.reviewRequests, ['tutor-1']);
    });

    testWidgets('name the score, the tags and the rater by initials only', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeTutorsRepository(
          profiles: [_detail()],
          courseUnits: const [
            CourseUnit(
              publicId: 'unit-1',
              code: 'MAT 221',
              name: 'Linear Algebra II',
            ),
          ],
          reviews: [
            _review(score: 4, tags: ['made_it_click', 'patient']),
          ],
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
      expect(find.text('A.O. · 4 Mar 2026'), findsOneWidget);
      expect(find.text('Made it click'), findsOneWidget);
      expect(find.text('Patient'), findsOneWidget);
      // The note is written to the tutor and never published, so there is no
      // free text on this screen to find.
      expect(find.textContaining('Explained it twice'), findsNothing);
    });

    testWidgets('a score with no tags still reads as a review', (tester) async {
      await _pump(
        tester,
        FakeTutorsRepository(
          profiles: [_detail()],
          courseUnits: const [
            CourseUnit(
              publicId: 'unit-1',
              code: 'MAT 221',
              name: 'Linear Algebra II',
            ),
          ],
          reviews: [_review(score: 3, tags: const [])],
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
      expect(find.text('A.O. · 4 Mar 2026'), findsOneWidget);
    });

    testWidgets('the stars say the score out loud', (tester) async {
      await _pump(
        tester,
        FakeTutorsRepository(
          profiles: [_detail()],
          courseUnits: const [
            CourseUnit(
              publicId: 'unit-1',
              code: 'MAT 221',
              name: 'Linear Algebra II',
            ),
          ],
          reviews: [_review(score: 3)],
        ),
      );

      // Filled stars are a picture; this is what a screen reader gets.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '3 out of 5',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a new tutor with none says so without looking broken', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeTutorsRepository(
          profiles: [_detail()],
          courseUnits: const [
            CourseUnit(
              publicId: 'unit-1',
              code: 'MAT 221',
              name: 'Linear Algebra II',
            ),
          ],
        ),
      );

      expect(find.text('What students say'), findsOneWidget);
      expect(
        find.text(
          'No reviews yet. Reviews appear after a student rates a completed '
          'session.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed query costs the reviews and not the profile', (
      tester,
    ) async {
      await _pump(
        tester,
        _FailingReviewsRepository(profiles: [_detail(bio: 'Third-year CS.')]),
      );

      // The rating, name and standing are facts the screen already had. Hiding
      // them because a second request failed would be losing information to a
      // section that has its own retry.
      expect(find.text('Grace Okello'), findsOneWidget);
      expect(find.text('Third-year CS.'), findsOneWidget);
      expect(find.text('The reviews could not be loaded.'), findsOneWidget);
      expect(find.byTooltip('Retry reviews'), findsOneWidget);
    });

    testWidgets('the retry asks again and shows what arrives', (tester) async {
      final repository = _FlakyReviewsRepository(
        profiles: [_detail()],
        replies: [_review()],
      );

      await _pump(tester, repository);
      expect(find.text('The reviews could not be loaded.'), findsOneWidget);

      await tester.tap(find.byTooltip('Retry reviews'));
      await tester.pumpAndSettle();

      expect(repository.attempts, 2);
      expect(find.text('A.O. · 4 Mar 2026'), findsOneWidget);
      expect(find.text('The reviews could not be loaded.'), findsNothing);
    });
  });
}
