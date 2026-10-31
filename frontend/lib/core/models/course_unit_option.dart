import 'package:flutter/foundation.dart';

/// A course unit as returned from the academics reference endpoint.
@immutable
class CourseUnitOption {
  const CourseUnitOption({
    required this.publicId,
    required this.code,
    required this.name,
    this.yearLevel,
    this.semester,
  });

  factory CourseUnitOption.fromJson(Map<String, dynamic> json) =>
      CourseUnitOption(
        publicId: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        yearLevel: (json['year_level'] as num?)?.toInt(),
        semester: (json['semester'] as num?)?.toInt(),
      );

  final String publicId;
  final String code;
  final String name;
  final int? yearLevel;
  final int? semester;
}
