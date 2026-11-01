import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass_admin/core/models/admin_page.dart';
import 'package:peerpass_admin/core/models/admin_session_report.dart';
import 'package:peerpass_admin/features/admin/presentation/providers/admin_repository_provider.dart';

class SessionReportsScreen extends ConsumerStatefulWidget {
  const SessionReportsScreen({super.key});

  @override
  ConsumerState<SessionReportsScreen> createState() =>
      _SessionReportsScreenState();
}

class _SessionReportsScreenState extends ConsumerState<SessionReportsScreen> {
  Future<AdminSessionReportPage>? _reports;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(adminRepositoryProvider);
    _reports ??= repository.sessionReports(const AdminPageRequest());
    return FutureBuilder<AdminSessionReportPage>(
      future: _reports,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Safeguarding queue unavailable'));
        }
        final page = snapshot.data!;
        if (page.items.isEmpty) {
          return const Center(child: Text('No safeguarding reports.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: page.items.length,
          itemBuilder: (context, index) {
            final report = page.items[index];
            return Card(
              child: ListTile(
                title: Text('${report.category} · ${report.status}'),
                subtitle: Text(
                  '${report.reporterEmail}\n'
                  '${report.description ?? 'No description'}',
                ),
                isThreeLine: true,
                trailing: report.status == 'resolved'
                    ? const Icon(Icons.check_circle_outline)
                    : PopupMenuButton<String>(
                        onSelected: (status) => _update(report, status),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'reviewing',
                            child: Text('Mark reviewing'),
                          ),
                          PopupMenuItem(
                            value: 'resolved',
                            child: Text('Resolve'),
                          ),
                          PopupMenuItem(
                            value: 'suspend',
                            child: Text('Resolve and suspend tutor'),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _update(AdminSessionReport report, String action) async {
    final suspend = action == 'suspend';
    final reason = suspend ? await _suspensionReason() : null;
    if (suspend && reason == null) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateSessionReport(
            report,
            status: action == 'reviewing' ? 'reviewing' : 'resolved',
            suspendTutor: suspend,
            suspensionReason: reason,
          );
      if (!mounted) return;
      setState(() {
        _reports = ref
            .read(adminRepositoryProvider)
            .sessionReports(const AdminPageRequest());
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update safeguarding report.'),
          ),
        );
      }
    }
  }

  Future<String?> _suspensionReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspension reason'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }
}
