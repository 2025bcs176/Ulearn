import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peerpass/app/router.dart';

class AuthenticatedShell extends StatelessWidget {
  const AuthenticatedShell({
    required this.child,
    required this.selectedIndex,
    this.notificationsIcon,
    this.notificationsSelectedIcon,
    super.key,
  });

  final Widget child;
  final int selectedIndex;

  /// The notifications destination's icons, supplied by the router.
  ///
  /// They arrive as widgets rather than the shell importing the notifications
  /// feature, because the shell is a layout in `home/` and a sibling feature's
  /// presentation layer is not theirs to import. It also lets the selected icon
  /// carry the unread badge without the shell knowing what a notification is.
  final Widget? notificationsIcon;
  final Widget? notificationsSelectedIcon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final destinations = [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: notificationsIcon ?? const Icon(Icons.notifications_outlined),
            selectedIcon:
                notificationsSelectedIcon ??
                const Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ];
        return Scaffold(
          body: Row(
            children: [
              if (wide) ...[
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => _navigate(context, index),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: destination.icon,
                        selectedIcon: destination.selectedIcon,
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(child: child),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => _navigate(context, index),
                  destinations: destinations,
                ),
        );
      },
    );
  }

  void _navigate(BuildContext context, int index) {
    final route = switch (index) {
      0 => AppRoutes.home,
      1 => AppRoutes.sessions,
      2 => AppRoutes.notifications,
      _ => AppRoutes.profile,
    };
    context.go(route);
  }
}
