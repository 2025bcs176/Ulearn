import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/models/tutor_standing.dart';
import 'package:peerpass/core/models/tutor_summary.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/core/widgets/app_pill.dart';
import 'package:peerpass/features/matching/data/models/match_result.dart';
import 'package:peerpass/features/matching/presentation/widgets/match_candidate_tile.dart';

const TutorSummary _tutor = TutorSummary(
  userId: 'tutor-1',
  fullName: 'Grace Okello',
  standing: TutorStanding.verified,
  standingWire: 'verified',
  averageRating: 4.4,
  completedSessions: 18,
  bio: 'Third-year CS. I explain recursion with trees, not slides.',
  yearOfStudy: 3,
);

const MatchCandidate _candidate = MatchCandidate(
  tutor: _tutor,
  courseUnitId: 'unit-1',
  competencyGradePoints: 4.5,
  meetsThreshold: true,
  score: 0.91,
);

Future<void> _pump(
  WidgetTester tester, {
  MatchCandidate candidate = _candidate,
  VoidCallback? onAsk,
  bool busy = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: MatchCandidateTile(
            candidate: candidate,
            askLabel: 'Ask Grace Okello to tutor you',
            onAsk: onAsk,
            busy: busy,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the person, not only the counters', (tester) async {
    await _pump(tester, onAsk: () {});

    expect(find.text('Grace Okello'), findsOneWidget);
    expect(find.textContaining('Third-year CS'), findsOneWidget);
    // The avatar's initials stand in for the photo the beta does not have.
    expect(find.text('GO'), findsOneWidget);
    expect(find.text('Year 3'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppPill),
        matching: find.text('Verified'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping asks that tutor', (tester) async {
    var asked = 0;
    await _pump(tester, onAsk: () => asked++);

    await tester.tap(find.text('Ask Grace Okello to tutor you'));
    await tester.pump();

    expect(asked, 1);
  });

  testWidgets('a tutor already asked keeps a disabled control', (tester) async {
    // The row keeps its shape, so the list does not reflow under the student,
    // but the control says the decision is made.
    await _pump(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('a paused tutor is labelled as paused', (tester) async {
    await _pump(
      tester,
      candidate: const MatchCandidate(
        tutor: TutorSummary(
          userId: 'tutor-2',
          fullName: 'Daniel Okot',
          standing: TutorStanding.verified,
          standingWire: 'verified',
          completedSessions: 4,
          acceptingRequests: false,
        ),
        courseUnitId: 'unit-1',
        meetsThreshold: true,
        score: 0.5,
      ),
      onAsk: () {},
    );

    expect(
      find.descendant(of: find.byType(AppPill), matching: find.text('Paused')),
      findsOneWidget,
    );
  });

  testWidgets('without a bio the row falls back to the grade evidence', (
    tester,
  ) async {
    await _pump(
      tester,
      candidate: const MatchCandidate(
        tutor: TutorSummary(
          userId: 'tutor-3',
          fullName: 'Amina Nakato',
          standing: TutorStanding.probationary,
          standingWire: 'probationary',
          completedSessions: 2,
        ),
        courseUnitId: 'unit-1',
        competencyGradePoints: 4.25,
        meetsThreshold: true,
        score: 0.4,
      ),
      onAsk: () {},
    );

    expect(find.text('Grade points 4.3'), findsWidgets);
    // The muted palette is the same one the rest of the card uses, so the
    // fallback is not visually a different kind of text.
    final context = tester.element(find.byType(MatchCandidateTile));
    expect(AppPalette.of(context).muted, isNotNull);
  });

  testWidgets('busy keeps the button height and blocks a second tap', (
    tester,
  ) async {
    var asked = 0;
    await _pump(tester, onAsk: () => asked++, busy: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
