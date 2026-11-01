import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/models/academic_fallback.dart';
import 'package:peerpass/core/models/course_unit_option.dart';
import 'package:peerpass/core/models/grade_option.dart';
import 'package:peerpass/features/auth/data/repositories/auth_repository.dart';
import 'package:peerpass/features/competencies/data/repositories/competencies_repository.dart';

/// The university and faculty a claim would be recorded against.
typedef ClaimScope = ({String universityId, String? facultyId});

/// The course units a tutor may claim, scoped to their university and faculty.
///
/// Declared here rather than imported from `features/auth`, where an equivalent
/// provider exists for the onboarding wizard. The architecture rule allows a
/// feature to reach another only through that feature's repository contract, so
/// importing the wizard's provider is not available -- and it should not be: a
/// tutor choosing which unit to submit proof for is not the wizard's business, and
/// a screen that reached into another feature's providers would couple the two.
// Riverpod infers the family type from the generics; the analyzer cannot prove it.
// ignore: specify_nonobvious_property_types
final claimCourseUnitsProvider =
    FutureProvider.family<List<CourseUnitOption>, ClaimScope>((ref, scope) {
      if (scope.universityId.isEmpty) return Future.value(const []);
      return ref
          .read(authRepositoryProvider)
          .courseUnits(
            universityId: scope.universityId,
            subjectId: scope.facultyId,
          );
    });

/// Whether the university a tutor is enrolled at is MUST.
///
/// The submission form needs this to decide whether an empty grade list means
/// "this university has published no scale" or "the catalogue has not loaded", and
/// those two want different copy: one has nothing to offer, the other has something
/// and should offer it.
///
/// Identified by name against the signed-in university rather than by the fallback
/// sentinel id. A real enrolment at MUST is still MUST when its grade catalogue
/// happens to be empty, and that is the case worth a fallback scale -- while a
/// catalogue that failed to load is a different problem with a different remedy.
// ignore: specify_nonobvious_property_types
final isMustUniversityProvider = FutureProvider.family<bool, String>((
  ref,
  universityId,
) async {
  if (universityId.isEmpty) return false;
  try {
    final universities = await ref.read(authRepositoryProvider).universities();
    return universities.any(
      (u) => u.publicId == universityId && u.name == mustFallbackUniversityName,
    );
  } on Failure {
    // Not knowing is not being MUST. The fallback scale is offered on the merit of
    // its own provider, which already substitutes it whenever the live catalogue
    // is unavailable; this flag only decides whether to admit it in the copy.
    return false;
  }
});

/// The grades a tutor may claim, falling back to the saved MUST scale.
///
/// A grade is read from the university that published it, so the id in the
/// dropdown is only meaningful against that university's catalogue. When the live
/// scale is unavailable the MUST options are shown instead, and
/// [isMustFallbackGrade] marks them so the form resolves each one to a live id
/// before submitting rather than storing a synthetic one.
// ignore: specify_nonobvious_property_types
final claimGradesProvider = FutureProvider.family<List<GradeOption>, String>((
  ref,
  universityId,
) async {
  if (universityId.isEmpty) return const [];
  try {
    final live = await ref
        .read(authRepositoryProvider)
        .grades(universityId: universityId);
    if (live.isNotEmpty) return live;
  } on Failure {
    // Falls through to the fallback below, which is what the wizard does with an
    // unreachable catalogue.
  }
  return mustFallbackGrades;
});

/// Submits proof and reports whether it worked, for the submission form.
///
/// A [Provider] rather than a [Notifier], because it exposes no value of its own.
/// The screen owns the message, because the wording is a decision about where it
/// is read.
final submitClaimProvider = Provider<SubmitClaimController>(
  SubmitClaimController.new,
);

class SubmitClaimController {
  const SubmitClaimController(this._ref);

  final Ref _ref;

  CompetenciesRepository get _repository =>
      _ref.read(competenciesRepositoryProvider);

  /// Submits, and returns null on success or the [Failure] that stopped it.
  ///
  /// The repository has already turned transport and problem-document faults
  /// into a [Failure] carrying a message a tutor can read, so nothing here
  /// inspects an exception.
  ///
  /// Refreshes [myClaimsProvider] on success. A tutor who has just submitted proof
  /// and then opens their applications should see the claim that now exists, not
  /// an empty list from before the submission -- the two states differ only by
  /// this call, and a list cached across a submission is the one way the screen
  /// could report "you have not applied yet" about a tutor who has.
  Future<Failure?> submit({
    required String courseUnitId,
    required String gradeId,
    required String source,
    String? evidenceReference,
    String? notes,
  }) async {
    try {
      await _repository.submitClaim(
        courseUnitId: courseUnitId,
        gradeId: gradeId,
        source: source,
        evidenceReference: evidenceReference,
        notes: notes,
      );
      _ref.invalidate(myClaimsProvider);
      return null;
    } on Failure catch (failure) {
      return failure;
    }
  }
}
