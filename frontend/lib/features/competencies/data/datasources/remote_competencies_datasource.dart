import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:peerpass/features/competencies/data/models/tutor_claim.dart';

/// The remote shape of a tutor's own competency claims.
class RemoteCompetenciesDatasource {
  const RemoteCompetenciesDatasource(this._dio);

  final Dio _dio;

  /// Every proof the signed-in tutor has submitted, newest first.
  ///
  /// The endpoint takes no parameters and returns the caller's rows by
  /// construction, so there is nothing to filter here and no way for a query
  /// string to widen the scope.
  ///
  /// The body is validated rather than cast by Dio. `get<List<dynamic>>` fails
  /// on a non-list with a cast error the repository cannot name, and this is the
  /// one place that can tell the difference between "the API sent something we
  /// cannot read" and "the network is down".
  Future<List<TutorClaim>> myClaims() async {
    final response = await _dio.get<Object>('/v1/competencies/me');
    final body = response.data;
    if (body is! List) {
      throw FormatException(
        'the claims response was ${body == null ? 'empty' : body.runtimeType}, '
        'not a list',
      );
    }
    return body
        .map((item) {
          if (item is! Map) {
            throw const FormatException('a claim was not a JSON object');
          }
          return TutorClaim.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }

  /// Uploads transcript/QR evidence for an already-submitted claim.
  ///
  /// Returns the updated claim, whose [TutorClaim.evidenceReference] now
  /// points at the stored object key.
  Future<TutorClaim> uploadEvidence({
    required String competencyId,
    required PlatformFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'upload': MultipartFile.fromBytes(bytes, filename: file.name),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/competencies/$competencyId/evidence',
      data: formData,
    );
    final body = response.data;
    if (body == null) {
      throw const FormatException('the upload response carried no body');
    }
    return TutorClaim.fromJson(body);
  }

  /// Submits proof for one course unit.
  /// submitted can show the state the API actually recorded instead of assuming
  /// `pending`.
  Future<TutorClaim> submit({
    required String courseUnitId,
    required String gradeId,
    required String source,
    String? evidenceReference,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/competencies',
      data: {
        'course_unit_id': courseUnitId,
        'grade_id': gradeId,
        'source': source,
        'evidence_reference': evidenceReference,
        'notes': notes,
      },
    );
    final body = response.data;
    if (body == null) {
      throw const FormatException('the submission response carried no body');
    }
    return TutorClaim.fromJson(body);
  }
}
