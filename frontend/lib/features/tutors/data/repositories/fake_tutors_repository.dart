import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/models/course_unit.dart';
import 'package:peerpass/core/models/tutor_standing.dart';
import 'package:peerpass/features/tutors/data/models/tutor_detail.dart';
import 'package:peerpass/features/tutors/data/models/tutor_hq.dart';
import 'package:peerpass/features/tutors/data/models/tutor_rail_entry.dart';
import 'package:peerpass/features/tutors/data/models/tutor_review.dart';
import 'package:peerpass/features/tutors/data/repositories/tutors_repository.dart';

/// In-memory stand-in for the tutor discovery endpoints.
///
/// What widget tests resolve, because a widget test has no server to talk to. It
/// implements the repository's shape rather than the datasource's, because that
/// is the seam a test cares about: overriding the repository is the only
/// composition the app supports.
///
/// A fake and not a stub, in the two places it matters: an unknown tutor really
/// 404s rather than returning a blank profile, and a rail filtered on a unit
/// really comes back short instead of returning everything. A stub that ignored
/// its argument would let a screen that renders the wrong set pass.
class FakeTutorsRepository implements TutorsRepository {
  FakeTutorsRepository({
    List<TutorRailEntry> tutors = const [],
    List<TutorDetail> profiles = const [],
    List<CourseUnit> courseUnits = const [],
    List<TutorReview> reviews = const [],
    TutorHq? hq,
    this.failure,
  }) : _tutors = List<TutorRailEntry>.of(tutors),
       _profiles = List<TutorDetail>.of(profiles),
       _courseUnits = List<CourseUnit>.of(courseUnits),
       _reviews = List<TutorReview>.of(reviews),
       _currentHq = hq ?? _zeroHq;

  final List<TutorRailEntry> _tutors;
  final List<TutorDetail> _profiles;
  final List<CourseUnit> _courseUnits;
  final List<TutorReview> _reviews;

  /// The failure both HQ calls throw, when a test wants the error path.
  final Failure? failure;

  /// A tutor who is on the platform and has no evidence yet.
  ///
  /// The sensible default for a widget test: the loaded card renders, rather
  /// than the no-profile branch, without the test having to spell out a whole
  /// summary it does not care about.
  static const TutorHq _zeroHq = TutorHq(
    hasTutorProfile: true,
    standingWire: 'probationary',
    standing: TutorStanding.probationary,
    completedSessions: 0,
    averageRating: null,
    ratingCount: 0,
    certifiedMinutes: 0,
    certificateRequiredMinutes: 2400,
    certificateRemainingMinutes: 2400,
    certificateEligible: false,
    certificateProgress: 0,
    acceptingRequests: true,
    promotion: TutorPromotionProgress(
      verified: false,
      ratedSessions: 0,
      sessionsRequired: 3,
      sessionsRemaining: 3,
      minimumAverage: 4.1,
      meetsAverage: false,
      progress: 0,
    ),
  );

  TutorHq _currentHq;

  /// How many times [myHq] has been called.
  int hqCalls = 0;

  /// The availability values [setAcceptingRequests] was asked to save, in order.
  ///
  /// Kept so a widget test can prove the switch sent the value it showed rather
  /// than a hardcoded one.
  final List<bool> acceptingRequestsCalls = [];

  /// The dashboard as it stands after any accepted availability change.
  TutorHq get currentHq => _currentHq;

  /// The tutor ids the reviews endpoint was asked about, in order.
  ///
  /// Kept so a screen test can prove the profile asked for *its* tutor rather
  /// than showing one fixed list to everybody.
  final List<String> reviewRequests = [];

  /// The course units the detail screen resolves endorsed ids against.
  List<CourseUnit> get catalogue => List<CourseUnit>.unmodifiable(_courseUnits);

  /// The `courseUnitId` values the rail was filtered by, in order.
  ///
  /// Kept so a test can prove the rail narrowed rather than being handed the
  /// whole list by a screen that ignored its input.
  final List<String?> railFilters = [];

  @override
  Future<TutorHq> myHq() async {
    hqCalls++;
    final thrown = failure;
    if (thrown != null) throw thrown;
    return _currentHq;
  }

  @override
  Future<TutorHq> setAcceptingRequests(bool accepting) async {
    acceptingRequestsCalls.add(accepting);
    final thrown = failure;
    if (thrown != null) throw thrown;
    final updated = _currentHq.copyWith(acceptingRequests: accepting);
    _currentHq = updated;
    return updated;
  }

  @override
  Future<List<TutorRailEntry>> topTutors({String? courseUnitId}) async {
    railFilters.add(courseUnitId);
    if (courseUnitId == null) return List<TutorRailEntry>.unmodifiable(_tutors);

    // Approximated with the endorsements the fake knows about. The real filter is
    // the API's competency gate for the unit, which this client cannot evaluate
    // and is not the place to start.
    return [
      for (final entry in _tutors)
        if (entry.endorsedCourseUnitIds.contains(courseUnitId)) entry,
    ];
  }

  @override
  Future<TutorDetail> tutor(String userId) async {
    for (final profile in _profiles) {
      if (profile.profile.userId == userId) return profile;
    }

    // A rail entry without its own profile becomes one, so a test that only
    // cares about the rail does not have to write the same tutor twice.
    for (final entry in _tutors) {
      if (entry.tutor.userId != userId) continue;
      return TutorDetail(
        profile: entry.tutor,
        endorsedCourseUnitIds: entry.endorsedCourseUnitIds,
        endorsementCount: entry.endorsementCount,
      );
    }

    // The API answers a non-tutor and a non-existent user identically, and so
    // does this: a student must not be able to learn which accounts hold the
    // tutor role from the shape of the refusal.
    throw const NotFoundFailure('That tutor could not be found.');
  }

  @override
  Future<List<TutorReview>> reviews(String userId, {int? limit}) async {
    reviewRequests.add(userId);
    // The reviews endpoint 404s for a non-tutor exactly as the profile does. A
    // fake that returned an empty list instead would let a screen show a
    // plausible "no reviews yet" for an id the API rejects.
    await tutor(userId);
    return List<TutorReview>.unmodifiable(
      limit == null ? _reviews : _reviews.take(limit),
    );
  }

  @override
  Future<List<CourseUnit>> courseUnits({String? universityId}) async =>
      List<CourseUnit>.unmodifiable(_courseUnits);
}
