class TopicHeatmapEntry {
  const TopicHeatmapEntry({
    required this.courseUnitCode,
    required this.courseUnitName,
    required this.topic,
    required this.requestCount,
  });

  factory TopicHeatmapEntry.fromJson(Map<String, dynamic> json) =>
      TopicHeatmapEntry(
        courseUnitCode: json['course_unit_code'] as String,
        courseUnitName: json['course_unit_name'] as String,
        topic: json['topic'] as String,
        requestCount: (json['request_count'] as num).toInt(),
      );

  final String courseUnitCode;
  final String courseUnitName;
  final String topic;
  final int requestCount;
}

class TopicHeatmap {
  const TopicHeatmap({required this.minimumCohortSize, required this.entries});

  factory TopicHeatmap.fromJson(Map<String, dynamic> json) => TopicHeatmap(
    minimumCohortSize: (json['minimum_cohort_size'] as num).toInt(),
    entries: (json['entries'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TopicHeatmapEntry.fromJson)
        .toList(),
  );

  final int minimumCohortSize;
  final List<TopicHeatmapEntry> entries;
}
