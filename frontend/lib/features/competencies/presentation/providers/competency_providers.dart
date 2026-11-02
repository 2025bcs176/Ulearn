import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/models/academic_fallback.dart';
import 'package:peerpass/core/models/course_unit_option.dart';
import 'package:peerpass/core/models/grade_option.dart';
import 'package:peerpass/features/auth/data/repositories/auth_repository.dart';
import 'package:peerpass/features/competencies/data/models/tutor_claim.dart';
import 'package:peerpass/features/competencies/data/repositories/competencies_repository.dart';

final competenciesRepositoryProvider = Provider<CompetenciesRepository>(
  (ref) => throw UnimplementedError(
    'competenciesRepositoryProvider must be overridden in ProviderScope.',
  ),
);

final myClaimsProvider = FutureProvider<List<TutorClaim>>(
  (ref) => ref.read(competenciesRepositoryProvider).myClaims(),
  retry: (retryCount, error) => null,
);

typedef ClaimScope = ({String universityId, String? facultyId});

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

// Identified by name against the signed-in university.
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
    return false;
  }
});

// The grades a tutor may claim, falling back to the saved MUST scale.
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
    // Falls through to the fallback below.
  }
  return mustFallbackGrades;
});

final submitClaimProvider = Provider<SubmitClaimController>(
  SubmitClaimController.new,
);

class SubmitClaimController {
  const SubmitClaimController(this._ref);

  final Ref _ref;

  CompetenciesRepository get _repository =>
      _ref.read(competenciesRepositoryProvider);

  Future<({TutorClaim? claim, Failure? failure})> submit({
    required String courseUnitId,
    required String gradeId,
    required String source,
    String? evidenceReference,
    String? notes,
  }) async {
    try {
      final claim = await _repository.submitClaim(
        courseUnitId: courseUnitId,
        gradeId: gradeId,
        source: source,
        evidenceReference: evidenceReference,
        notes: notes,
      );
      _ref.invalidate(myClaimsProvider);
      return (claim: claim, failure: null);
    } on Failure catch (failure) {
      return (claim: null, failure: failure);
    }
  }

  Future<Failure?> uploadEvidence({
    required String competencyId,
    required PlatformFile file,
  }) async {
    try {
      await _repository.uploadEvidence(
        competencyId: competencyId,
        file: file,
      );
      _ref.invalidate(myClaimsProvider);
      return null;
    } on Failure catch (failure) {
      return failure;
    }
  }
}
