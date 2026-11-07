/// What a student may say about a tutor beyond the score.
///
/// The vocabulary is the API's, not this client's: `RatingTag` mirrors
/// `app.models.enums.RatingTag`, and the list here is what the rating form
/// offers. A tag added on the server after this build ships is still *shown* on
/// a profile, because [ratingTagLabel] reads the wire value rather than
/// requiring a member -- an older APK must not drop a newer review's tags.
///
/// Every label is a phrase a student would say out loud, not the wire value with
/// the underscores taken out. Whether a tag makes a tutor eligible for anything
/// is a matching rule and lives in the API; this enum only decides how one is
/// displayed and offered.
enum RatingTag {
  clearExplanation('clear_explanation'),
  patient('patient'),
  wellPrepared('well_prepared'),
  madeItClick('made_it_click'),
  practicalExamples('practical_examples'),
  onTime('on_time');

  RatingTag(this.wireValue);

  /// The value the API stores and returns.
  ///
  /// Held separately from [name], for the same reason `TutorStanding` holds it
  /// separately: renaming the Dart identifier must not change what is sent.
  final String wireValue;

  /// How the tag is written on a chip and on a review.
  String get label => switch (this) {
    clearExplanation => 'Explained clearly',
    patient => 'Patient',
    wellPrepared => 'Well prepared',
    madeItClick => 'Made it click',
    practicalExamples => 'Real examples',
    onTime => 'On time',
  };

  /// The tag for a wire value, or null when it is one this build does not know.
  static RatingTag? fromWire(String? value) {
    for (final tag in RatingTag.values) {
      if (tag.wireValue == value) return tag;
    }
    return null;
  }
}

/// The most tags one rating may carry.
///
/// The API refuses a fifth with a 422. This copy exists so the form can disable
/// the chips instead of letting a student tap one and be told no -- it is an
/// affordance, not a second rule, and the API remains the thing that decides.
const int maxRatingTags = 4;

/// The labels for a list of wire tags, in the order they were chosen.
///
/// The helper every screen uses, so a rating and a review cannot disagree about
/// what a tag is called.
List<String> ratingTagLabels(Iterable<String> wireValues) => [
  for (final value in wireValues) ratingTagLabel(value),
];

/// The tags out of a decoded JSON body, tolerantly.
///
/// Unlike the fields a screen cannot render without, a malformed tag list is
/// display-only metadata: one non-string value inside it should cost that tag,
/// not the whole rating or review. An absent field is an older response and is
/// the same as no tags.
List<String> readRatingTags(Object? value) {
  if (value is! List) return const [];
  return List<String>.unmodifiable(value.whereType<String>());
}

/// The label for a wire tag, including one this build has never heard of.
///
/// An unknown value comes back humanised rather than blank or missing: a tag is
/// a word the server chose, and dropping it would make a newer review look like
/// it had fewer tags than the student actually picked.
String ratingTagLabel(String wireValue) {
  final known = RatingTag.fromWire(wireValue);
  if (known != null) return known.label;

  final words = wireValue
      .split('_')
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return wireValue;
  final first = words.first;
  final capitalised = '${first[0].toUpperCase()}${first.substring(1)}';
  return [capitalised, ...words.skip(1)].join(' ');
}
