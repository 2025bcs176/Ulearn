import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass_admin/features/admin/presentation/providers/admin_repository_provider.dart';

class TopicHeatmapScreen extends ConsumerWidget {
  const TopicHeatmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(adminRepositoryProvider);
    return FutureBuilder(
      future: repository.topicHeatmap(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Analytics unavailable'));
        }
        final heatmap = snapshot.data!;
        if (heatmap.entries.isEmpty) {
          return const Center(
            child: Text('No topic cohort has reached five requests.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: heatmap.entries.length,
          itemBuilder: (context, index) {
            final entry = heatmap.entries[index];
            return ListTile(
              title: Text(entry.topic),
              subtitle: Text(
                '${entry.courseUnitCode} · ${entry.courseUnitName}',
              ),
              trailing: Text('${entry.requestCount} requests'),
            );
          },
        );
      },
    );
  }
}
