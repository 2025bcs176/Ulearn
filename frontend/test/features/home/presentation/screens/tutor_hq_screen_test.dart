import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/models/user_profile.dart';
import 'package:peerpass/core/models/user_role.dart';
import 'package:peerpass/core/state/session.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/core/widgets/app_avatar.dart';
import 'package:peerpass/features/home/presentation/screens/tutor_hq_screen.dart';

/// A tutor who has finished onboarding, so the router would let them stay here.
const UserProfile _tutor = UserProfile(
  publicId: 'user-1',
  email: 'tutor@must.ac.ug',
  fullName: 'Achieng Okello',
  roles: <UserRole>{UserRole.student, UserRole.tutor},
  universityId: 'university-1',
  facultyId: 'subject-1',
  yearOfStudy: 2,
);

/// The four sections arrive as widgets from three other features, so the tests
/// pass markers rather than the real ones. What is under test here is placement
/// and the greeting, not what a progress card decides to say.
const String _progress = 'Progress card';
const String _availability = 'Availability toggle';
const String _requests = 'Requests section';
const String _certificate = 'Certificate card';

ProviderContainer _container(UserProfile? profile) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (profile != null) {
    container.read(sessionControllerProvider.notifier).signedIn(profile);
  }
  return container;
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  UserProfile? profile,
  Future<void> Function()? onRefresh,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container(profile),
      child: MaterialApp(
        theme: AppTheme.light,
        home: TutorHqScreen(
          progressCard: const Text(_progress),
          availabilityToggle: const Text(_availability),
          requestsSection: const Text(_requests),
          certificateCard: const Text(_certificate),
          onRefresh: onRefresh,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names the screen and greets the tutor by first name', (
    tester,
  ) async {
    await _pumpScreen(tester, profile: _tutor);

    expect(find.text('Tutor HQ'), findsOneWidget);
    expect(find.text('Your tutor HQ'), findsOneWidget);
    expect(find.text('Good evening, Achieng.'), findsOneWidget);
    // The avatar is derived from the stored name rather than an upload: the
    // pilot stores no images.
    expect(
      find.descendant(of: find.byType(AppAvatar), matching: find.text('AO')),
      findsOneWidget,
    );
  });

  testWidgets('falls back to a greeting without a name', (tester) async {
    // A tutor with no stored name is not a state the router allows, but the
    // heading must not read "Good evening, ." if it ever happens.
    await _pumpScreen(tester);

    expect(find.text('Hello there.'), findsOneWidget);
    expect(find.text('Good evening, Achieng.'), findsNothing);
  });

  testWidgets('places the four sections in the order a tutor reads them', (
    tester,
  ) async {
    // Ordering is the composition this screen exists for, so it is asserted
    // rather than left to the order the widgets happen to be listed in. A
    // request waiting on an answer outranks the tutor's own certificate.
    await _pumpScreen(tester, profile: _tutor);

    final greeting = tester.getTopLeft(find.text('Your tutor HQ')).dy;
    final progress = tester.getTopLeft(find.text(_progress)).dy;
    final availability = tester.getTopLeft(find.text(_availability)).dy;
    final requests = tester.getTopLeft(find.text(_requests)).dy;
    final certificate = tester.getTopLeft(find.text(_certificate)).dy;

    expect(greeting, lessThan(progress));
    expect(progress, lessThan(availability));
    expect(availability, lessThan(requests));
    expect(requests, lessThan(certificate));
  });

  testWidgets('pull to refresh calls the callback the shell supplies', (
    tester,
  ) async {
    var refreshes = 0;
    await _pumpScreen(
      tester,
      profile: _tutor,
      onRefresh: () async {
        refreshes++;
      },
    );

    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshes, 1);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'without a refresh callback the screen still renders and scrolls',
    (tester) async {
      // Home's own tests pump the screen without a shell, so no callback is the
      // shape it must survive. No indicator means no drag-to-refresh promise.
      await _pumpScreen(tester, profile: _tutor);

      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.text(_progress), findsOneWidget);

      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_certificate), findsOneWidget);
    },
  );
}
