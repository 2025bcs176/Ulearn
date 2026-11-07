import 'package:flutter/foundation.dart';

/// One suggested question for a course unit, from the audience's own catalogue.
///
/// A suggestion is free text, not an enum: tapping it puts [label] into the
/// request's topic field, and the API stores that string against the help
/// request. The [publicId] exists only so a chip has a stable key; nothing is
/// sent back as an id, because a tutor reading the request must be able to see
/// the question in words.
@immutable
class CourseUnitTopic {
  const CourseUnitTopic({
    required this.publicId,
    required this.label,
    this.sortOrder = 0,
  });

  /// Reads the wire form.
  ///
  /// Strict about the two fields a chip cannot be drawn without. A
  /// [FormatException] becomes a `ServerFailure` in the repository, where a bare
  /// cast error would reach a bottom sheet as a type name.
  factory CourseUnitTopic.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    if (id is! String || label is! String || label.trim().isEmpty) {
      throw const FormatException(
        'topic response was missing a required field',
      );
    }

    return CourseUnitTopic(
      publicId: id,
      label: label,
      sortOrder: switch (json['sort_order']) {
        final num order => order.toInt(),
        // The list is already ordered by the API, so an absent order costs
        // nothing. It is not a reason to drop a suggestion a student could use.
        _ => 0,
      },
    );
  }

  final String publicId;

  /// The phrase as it will appear in the request and to the tutor.
  final String label;

  /// The publisher's order. Carried for completeness; the API sends the list in
  /// this order already.
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseUnitTopic &&
          other.publicId == publicId &&
          other.label == label &&
          other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(publicId, label, sortOrder);

  @override
  String toString() => 'CourseUnitTopic($label)';
}
