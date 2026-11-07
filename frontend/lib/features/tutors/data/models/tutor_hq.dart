import 'package:flutter/foundation.dart';
import 'package:peerpass/core/models/json_decimal.dart';
import 'package:peerpass/core/models/tutor_standing.dart';

/// How far a provisional tutor is from being verified.
///
/// The API owns every threshold here: [sessionsRequired] and [minimumAverage]
/// are read from the response rather than held as constants in the client. A
/// pilot that changes either must not need an app release, and a tutor must
/// never be shown a bar this screen computed from a rule it invented.
@immutable
class TutorPromotionProgress {
  const TutorPromotionProgress({
    required this.verified,
    required this.ratedSessions,
    required this.sessionsRequired,
    required this.sessionsRemaining,
    required this.minimumAverage,
    required this.meetsAverage,
    required this.progress,
  });

  /// Reads the promotion block the HQ response nests.
  ///
  /// Every field is required. A body missing one is a contract change rather
  /// than a partial answer, and the repository turns the [FormatException] into
  /// a server fault the screen can render.
  factory TutorPromotionProgress.fromJson(Map<String, dynamic> json) {
    final verified = json['verified'];
    final ratedSessions = json['rated_sessions'];
    final sessionsRequired = json['sessions_required'];
    final sessionsRemaining = json['sessions_remaining'];
    final meetsAverage = json['meets_average'];

    if (verified is! bool ||
        ratedSessions is! num ||
        sessionsRequired is! num ||
        sessionsRemaining is! num ||
        meetsAverage is! bool) {
      throw const FormatException(
        'tutor promotion response was missing a required field',
      );
    }

    return TutorPromotionProgress(
      verified: verified,
      ratedSessions: ratedSessions.toInt(),
      sessionsRequired: sessionsRequired.toInt(),
      sessionsRemaining: sessionsRemaining.toInt(),
      minimumAverage: readRequiredDecimal(
        json['minimum_average'],
        'minimum_average',
      ),
      meetsAverage: meetsAverage,
      progress: readRequiredDecimal(json['progress'], 'progress'),
    );
  }

  /// Whether the API considers promotion already earned.
  final bool verified;

  /// Rated sessions that count towards promotion.
  final int ratedSessions;

  /// How many rated sessions promotion needs.
  final int sessionsRequired;

  /// How many more are needed. The API's subtraction, not this client's.
  final int sessionsRemaining;

  /// The average rating needed for promotion.
  ///
  /// A double for display only. The verdict is [meetsAverage]; comparing the
  /// tutor's own rating to this here would be a second copy of a matching rule.
  final double minimumAverage;

  /// Whether the tutor's current average clears [minimumAverage].
  final bool meetsAverage;

  /// How far along the promotion path, from 0.0 to 1.0.
  final double progress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TutorPromotionProgress &&
          other.verified == verified &&
          other.ratedSessions == ratedSessions &&
          other.sessionsRequired == sessionsRequired &&
          other.sessionsRemaining == sessionsRemaining &&
          other.minimumAverage == minimumAverage &&
          other.meetsAverage == meetsAverage &&
          other.progress == progress;

  @override
  int get hashCode => Object.hash(
    verified,
    ratedSessions,
    sessionsRequired,
    sessionsRemaining,
    minimumAverage,
    meetsAverage,
    progress,
  );

  @override
  String toString() =>
      'TutorPromotionProgress($ratedSessions/$sessionsRequired, '
      'verified: $verified)';
}

/// The signed-in tutor's dashboard: standing, totals, and promotion progress.
///
/// A wire DTO. Nothing here is derived from the caller's roles or from the
/// individual session list: the API answers the whole summary in one response,
/// and a client that recomputed the certificate bar would keep showing the old
/// threshold after an operator changed it.
@immutable
class TutorHq {
  const TutorHq({
    required this.hasTutorProfile,
    required this.standingWire,
    required this.standing,
    required this.completedSessions,
    required this.averageRating,
    required this.ratingCount,
    required this.certifiedMinutes,
    required this.certificateRequiredMinutes,
    required this.certificateRemainingMinutes,
    required this.certificateEligible,
    required this.certificateProgress,
    required this.acceptingRequests,
    required this.promotion,
  });

  /// Reads the `/v1/tutors/me` response.
  ///
  /// The nullable fields are the three the API also answers for a caller with
  /// no tutor profile: [standingWire] (and therefore [standing]),
  /// [averageRating], and [acceptingRequests]. They stay null rather than
  /// becoming defaults, because false is a real availability setting and zero
  /// is a real rating.
  factory TutorHq.fromJson(Map<String, dynamic> json) {
    final hasTutorProfile = json['has_tutor_profile'];
    final completedSessions = json['completed_sessions'];
    final ratingCount = json['rating_count'];
    final certifiedMinutes = json['certified_minutes'];
    final certificateRequiredMinutes = json['certificate_required_minutes'];
    final certificateRemainingMinutes = json['certificate_remaining_minutes'];
    final certificateEligible = json['certificate_eligible'];

    if (hasTutorProfile is! bool ||
        completedSessions is! num ||
        ratingCount is! num ||
        certifiedMinutes is! num ||
        certificateRequiredMinutes is! num ||
        certificateRemainingMinutes is! num ||
        certificateEligible is! bool) {
      throw const FormatException(
        'tutor headquarters response was missing a required field',
      );
    }

    final standingWire = json['standing'];
    if (standingWire != null && standingWire is! String) {
      throw const FormatException('tutor standing was not a string');
    }

    final acceptingRequests = json['accepting_requests'];
    if (acceptingRequests != null && acceptingRequests is! bool) {
      throw const FormatException('accepting_requests was not a bool');
    }

    final promotion = json['promotion'];
    if (promotion is! Map<String, dynamic>) {
      throw const FormatException(
        'tutor headquarters response carried no promotion block',
      );
    }

    return TutorHq(
      hasTutorProfile: hasTutorProfile,
      standingWire: standingWire as String?,
      standing: TutorStanding.fromWire(standingWire),
      completedSessions: completedSessions.toInt(),
      averageRating: readDecimal(json['average_rating']),
      ratingCount: ratingCount.toInt(),
      certifiedMinutes: certifiedMinutes.toInt(),
      certificateRequiredMinutes: certificateRequiredMinutes.toInt(),
      certificateRemainingMinutes: certificateRemainingMinutes.toInt(),
      certificateEligible: certificateEligible,
      certificateProgress: readRequiredDecimal(
        json['certificate_progress'],
        'certificate_progress',
      ),
      acceptingRequests: acceptingRequests as bool?,
      promotion: TutorPromotionProgress.fromJson(promotion),
    );
  }

  /// Whether the caller has a tutor profile.
  ///
  /// The API's answer rather than something inferred from a role: a student and
  /// a brand-new tutor both read as zeroes, and only one of them has an HQ.
  final bool hasTutorProfile;

  /// The standing exactly as the API spelled it, so an unfamiliar value can be
  /// shown verbatim rather than hidden.
  final String? standingWire;

  /// [standingWire] parsed, or null when this client predates the value.
  final TutorStanding? standing;

  /// Sessions the tutor has completed.
  final int completedSessions;

  /// Average rating, or null when nobody has rated the tutor yet.
  final double? averageRating;

  /// How many ratings back [averageRating].
  final int ratingCount;

  /// Minutes that count towards a certificate.
  final int certifiedMinutes;

  /// The configured certificate threshold.
  final int certificateRequiredMinutes;

  /// Minutes still to go, already computed by the API.
  final int certificateRemainingMinutes;

  /// The API's verdict on the certificate threshold.
  final bool certificateEligible;

  /// How far along the certificate, from 0.0 to 1.0.
  final double certificateProgress;

  /// Whether the tutor is shown to students searching for one.
  ///
  /// Null for a caller without a tutor profile, and that is not false: there is
  /// no setting to be off.
  final bool? acceptingRequests;

  /// Promotion progress towards verified standing.
  final TutorPromotionProgress promotion;

  /// A copy with the availability flag changed.
  ///
  /// Only the field the toggle owns is replaceable. The rest of the summary is
  /// the API's answer, and a copy helper that let a caller edit a total would
  /// make the client a second source of truth for it.
  TutorHq copyWith({bool? acceptingRequests}) {
    return TutorHq(
      hasTutorProfile: hasTutorProfile,
      standingWire: standingWire,
      standing: standing,
      completedSessions: completedSessions,
      averageRating: averageRating,
      ratingCount: ratingCount,
      certifiedMinutes: certifiedMinutes,
      certificateRequiredMinutes: certificateRequiredMinutes,
      certificateRemainingMinutes: certificateRemainingMinutes,
      certificateEligible: certificateEligible,
      certificateProgress: certificateProgress,
      acceptingRequests: acceptingRequests ?? this.acceptingRequests,
      promotion: promotion,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TutorHq &&
          other.hasTutorProfile == hasTutorProfile &&
          other.standingWire == standingWire &&
          other.standing == standing &&
          other.completedSessions == completedSessions &&
          other.averageRating == averageRating &&
          other.ratingCount == ratingCount &&
          other.certifiedMinutes == certifiedMinutes &&
          other.certificateRequiredMinutes == certificateRequiredMinutes &&
          other.certificateRemainingMinutes == certificateRemainingMinutes &&
          other.certificateEligible == certificateEligible &&
          other.certificateProgress == certificateProgress &&
          other.acceptingRequests == acceptingRequests &&
          other.promotion == promotion;

  @override
  int get hashCode => Object.hashAll([
    hasTutorProfile,
    standingWire,
    standing,
    completedSessions,
    averageRating,
    ratingCount,
    certifiedMinutes,
    certificateRequiredMinutes,
    certificateRemainingMinutes,
    certificateEligible,
    certificateProgress,
    acceptingRequests,
    promotion,
  ]);

  @override
  String toString() =>
      'TutorHq($standingWire, $completedSessions sessions, '
      'accepting: $acceptingRequests)';
}
