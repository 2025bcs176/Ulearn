import 'package:flutter/foundation.dart';
import 'package:peerpass/core/models/rating_tag.dart';

/// One review as any signed-in student reads it on a tutor's profile.
///
/// Deliberately not a `RatingModel`, which is the record of a transaction between
/// two people: that one names the rater and carries the note they wrote. This is
/// a publication to strangers, so the rater is an initial, the note is absent,
/// and there is no id belonging to anyone but the review itself.
///
/// [tags] are wire values rather than enum members. A tag added after this build
/// shipped is still something a student chose to say, and `ratingTagLabel` can
/// name it without a member existing for it.
@immutable
class TutorReview {
  const TutorReview({
    required this.id,
    required this.score,
    required this.raterInitials,
    required this.createdAt,
    this.tags = const [],
  });

  /// Reads the wire form.
  ///
  /// Strict about the four fields a review cannot be drawn without, for the
  /// reason given on `RatingModel.fromJson`: a [FormatException] becomes a
  /// server fault in the repository, where a bare cast error would not.
  factory TutorReview.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final score = json['score'];
    final initials = json['rater_initials'];
    final createdAt = json['created_at'];

    if (id is! String ||
        score is! num ||
        initials is! String ||
        createdAt is! String) {
      throw const FormatException(
        'review response was missing a required field',
      );
    }

    return TutorReview(
      id: id,
      score: score.toInt(),
      raterInitials: initials,
      tags: readRatingTags(json['tags']),
      createdAt: DateTime.parse(createdAt),
    );
  }

  final String id;

  /// The whole-number score, which the API bounds to 1..5.
  ///
  /// Not clamped here. The API is the bound, and a client that hid a score the
  /// server chose would be inventing a second rule; the stars simply fill up to
  /// this number.
  final int score;

  /// The first letters of the rater's name, computed server-side.
  ///
  /// An initial and nothing more: the name is not in the payload and neither is
  /// any id belonging to the rater, so a review cannot be walked back to the
  /// account that left it.
  final String raterInitials;

  /// The tags the rater chose, from the API's fixed vocabulary.
  final List<String> tags;

  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TutorReview &&
          other.id == id &&
          other.score == score &&
          other.raterInitials == raterInitials &&
          listEquals(other.tags, tags) &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, score, raterInitials, Object.hashAll(tags), createdAt);

  @override
  String toString() => 'TutorReview($id, $score by $raterInitials)';
}
