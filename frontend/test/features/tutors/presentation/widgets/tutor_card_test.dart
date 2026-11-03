import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/models/tutor_standing.dart';
import 'package:peerpass/core/models/tutor_summary.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/core/widgets/app_pill.dart';
import 'package:peerpass/features/tutors/data/models/tutor_rail_entry.dart';
import 'package:peerpass/features/tutors/presentation/widgets/tutor_rail.dart';

TutorRailEntry _entry({
  String? bio,
  int? yearOfStudy,
  bool acceptingRequests = true,
}) {
  return TutorRailEntry(
    tutor: TutorSummary(
      userId: 'tutor-1',
      fullName: 'Sarah Kirabo',
      standing: TutorStanding.verified,
      standingWire: 'verified',
      averageRating: 4.6,
      completedSessions: 12,
      bio: bio,
      yearOfStudy: yearOfStudy,
      acceptingRequests: acceptingRequests,
    ),
    endorsedCourseUnitIds: const [],
    endorsementCount: 3,
  );
}

Future<void> _pump(WidgetTester tester, TutorRailEntry entry) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: 188,
            child: TutorCard(entry: entry, width: 200),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a rail card reads like a person', (tester) async {
    await _pump(
      tester,
      _entry(
        bio: 'Third-year CS. I make hard proofs feel obvious.',
        yearOfStudy: 3,
      ),
    );

    expect(find.text('Sarah Kirabo'), findsOneWidget);
    expect(find.text('SK'), findsOneWidget);
    expect(find.text('Year 3'), findsOneWidget);
    expect(find.textContaining('hard proofs'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppPill), matching: find.text('4.6')),
      findsOneWidget,
    );
  });

  testWidgets('a tutor with no bio shows their evidence instead', (
    tester,
  ) async {
    await _pump(tester, _entry());

    expect(find.text('12 sessions taught'), findsOneWidget);
    expect(find.text('Endorsed 3 times'), findsOneWidget);
    expect(find.text('Year 3'), findsNothing);
  });

  testWidgets('a paused tutor is marked as paused', (tester) async {
    await _pump(tester, _entry(acceptingRequests: false));

    expect(
      find.descendant(of: find.byType(AppPill), matching: find.text('Paused')),
      findsOneWidget,
    );
  });
}
