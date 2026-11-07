import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass/features/notifications/presentation/providers/notification_providers.dart';

/// The notifications destination in the shell, with its unread badge.
///
/// Passed into `AuthenticatedShell` by the router rather than imported there, so
/// the shell stays a layout and does not reach into a sibling feature's
/// presentation layer. Watching the inbox here is also what makes the badge
/// exist: the provider loads as soon as the signed-in shell builds, without the
/// student having to open the tab.
///
/// A badge rather than a number on the icon: Material's [Badge] handles the
/// positioning and caps the width, and "9+" is more honest than a two-digit
/// number squeezed into a dot.
class NotificationTabIcon extends ConsumerWidget {
  const NotificationTabIcon({this.selected = false, super.key});

  /// Whether the destination is the current one.
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationUnreadCountProvider);
    final icon = Icon(
      selected ? Icons.notifications_rounded : Icons.notifications_outlined,
    );

    if (unread <= 0) return icon;

    return Badge(label: Text(unread > 9 ? '9+' : '$unread'), child: icon);
  }
}
