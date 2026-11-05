import 'package:intl/intl.dart';
import 'package:peerpass/core/models/course_unit.dart';
import 'package:peerpass/features/tutors/data/models/tutor_detail.dart';

/// The date a review was left, without a time.
///
/// A review is a day, not a moment: "4 Mar 2026" is what a browsing student is
/// deciding with, and the hour it was submitted at says nothing about the
/// session. Local time, because the reader is the one comparing it to now.
String reviewDateLabel(DateTime date) =>
    DateFormat('d MMM yyyy').format(date.toLocal());

/// The API's initials, as a byline is written.
///
/// The server sends letters only (`AS`); a byline reads `A.S.`. An account with
/// no usable name has no initials at all, and "A student" is a truer byline than
/// a lone question mark.
String initialsLabel(String initials) {
  final trimmed = initials.trim();
  if (trimmed.isEmpty || trimmed == '?') return 'A student';
  final letters = [
    for (final letter in trimmed.split(''))
      if (letter.trim().isNotEmpty) letter.toUpperCase(),
  ];
  if (letters.isEmpty) return 'A student';
  return '${letters.join('.')}.';
}

/// How many sessions a tutor has taught, as a student reads it.
///
/// One is "1 session taught" rather than "1 sessions", and zero says so plainly
/// rather than showing a bare 0 beside a rating: a tutor with no sessions is new
/// to the platform, which is a fact, not a fault.
String sessionsTaughtLabel(int count) {
  if (count <= 0) return 'No sessions yet';
  if (count == 1) return '1 session taught';
  return '$count sessions taught';
}

/// The endorsed units on a detail response, split by whether they can be named.
///
/// The API sends endorsement *ids* and a count, never a code or a name. So the
/// detail screen either resolves those ids against the course-unit catalogue or
/// it shows five uuids, which is not something a student can act on.
///
/// Returned rather than rendered here because a half-resolved list needs a
/// decision, and the screen is where that decision is visible: named units are
/// listed, and anything the catalogue could not name comes back as the
/// `unresolved` count, so the screen can say "2 more" instead of either dropping
/// them silently or inventing a placeholder. A test can call this on its own.
({List<CourseUnit> named, int unresolved}) endorsedUnitsOf(
  TutorDetail detail,
  List<CourseUnit> catalogue,
) {
  final byId = {for (final unit in catalogue) unit.publicId: unit};

  final named = <CourseUnit>[];
  final seen = <CourseUnit>{};
  for (final id in detail.endorsedCourseUnitIds) {
    // Deduplicated as it goes: a catalogue that lists one unit twice must not
    // produce two chips for it, and the count beside the list is the API's.
    final unit = byId[id];
    if (unit != null && seen.add(unit)) named.add(unit);
  }

  return (
    named: List<CourseUnit>.unmodifiable(named),
    unresolved: detail.endorsedCourseUnitIds.length - named.length,
  );
}
