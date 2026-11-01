import 'package:peerpass_admin/core/models/admin_page.dart';

class AdminSessionReport {
  const AdminSessionReport({
    required this.id,
    required this.sessionId,
    required this.reporterId,
    required this.reporterEmail,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory AdminSessionReport.fromJson(Map<String, dynamic> json) =>
      AdminSessionReport(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        reporterId: json['reporter_id'] as String,
        reporterEmail: json['reporter_email'] as String,
        category: json['category'] as String,
        description: json['description'] as String?,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String sessionId;
  final String reporterId;
  final String reporterEmail;
  final String category;
  final String? description;
  final String status;
  final DateTime createdAt;
}

typedef AdminSessionReportPage = AdminPage<AdminSessionReport>;
