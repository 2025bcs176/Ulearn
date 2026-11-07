/// The pilot's request-to-rating funnel, as the analytics endpoint reports it.
class PilotFunnel {
  const PilotFunnel({
    required this.requestsTotal,
    required this.requestsAccepted,
    required this.sessionsCompleted,
    required this.sessionsRated,
  });

  factory PilotFunnel.fromJson(Map<String, dynamic> json) => PilotFunnel(
    requestsTotal: (json['requests_total'] as num).toInt(),
    requestsAccepted: (json['requests_accepted'] as num).toInt(),
    sessionsCompleted: (json['sessions_completed'] as num).toInt(),
    sessionsRated: (json['sessions_rated'] as num).toInt(),
  );

  final int requestsTotal;
  final int requestsAccepted;
  final int sessionsCompleted;
  final int sessionsRated;
}
