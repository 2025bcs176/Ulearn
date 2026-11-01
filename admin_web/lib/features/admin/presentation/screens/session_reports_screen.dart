import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass_admin/core/models/admin_page.dart';
import 'package:peerpass_admin/core/models/admin_session_report.dart';
import 'package:peerpass_admin/features/admin/presentation/providers/admin_repository_provider.dart';
import 'package:peerpass_admin/features/admin/presentation/widgets/admin_pagination_bar.dart';

class SessionReportsScreen extends ConsumerStatefulWidget {
  const SessionReportsScreen({super.key});

  @override
  ConsumerState<SessionReportsScreen> createState() =>
      _SessionReportsScreenState();
}

class _SessionReportsScreenState extends ConsumerState<SessionReportsScreen> {
  Future<AdminSessionReportPage>? _reports;
  AdminPageRequest _request = const AdminPageRequest();

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(adminRepositoryProvider);
    _reports ??= repository.sessionReports(_request);
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
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AdminPaginationBar<AdminSessionReport>(
                page: page,
                request: _request,
                onChanged: _changePage,
              ),
            ),
          ],
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
        _reports = ref.read(adminRepositoryProvider).sessionReports(_request);
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

  void _changePage(AdminPageRequest request) {
    setState(() {
      _request = request;
      _reports = ref.read(adminRepositoryProvider).sessionReports(request);
    });
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
