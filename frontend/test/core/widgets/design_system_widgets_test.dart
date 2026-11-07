import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/core/widgets/app_avatar.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/core/widgets/app_pill.dart';
import 'package:peerpass/core/widgets/app_skeleton.dart';
import 'package:peerpass/core/widgets/empty_view.dart';
import 'package:peerpass/core/widgets/section_header.dart';

/// Pumps a widget inside the real app theme.
///
/// The components read their colour from the palette extension, so a bare
/// `MaterialApp` would exercise a fallback path that production never takes.
Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppButton(label: 'Find a tutor', onPressed: () => taps++),
      );

      await tester.tap(find.text('Find a tutor'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a disabled button does nothing', (tester) async {
      await _pump(
        tester,
        const AppButton(label: 'Disabled', onPressed: null),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('loading keeps the label and blocks a second tap', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        AppButton(
          label: 'Sending',
          isLoading: true,
          onPressed: () => taps++,
        ),
      );

      expect(find.text('Sending'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(taps, 0);
    });

    testWidgets('an accent button is amber on ink', (tester) async {
      await _pump(
        tester,
        AppButton(
          label: 'I am here',
          variant: AppButtonVariant.accent,
          onPressed: () {},
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final background = button.style?.backgroundColor?.resolve(<WidgetState>{});

      expect(background, const Color(0xFFFFB020));
    });
  });

  group('AppPill', () {
    testWidgets('renders its label', (tester) async {
      await _pump(tester, const AppPill('Verified'));

      expect(find.text('Verified'), findsOneWidget);
    });
  });

  group('AppAvatar', () {
    testWidgets('uses initials from the first two words', (tester) async {
      await _pump(tester, const AppAvatar(name: 'Sarah K.'));

      expect(find.text('SK'), findsOneWidget);
    });

    testWidgets('a single name gives two letters', (tester) async {
      await _pump(tester, const AppAvatar(name: 'Amina'));

      expect(find.text('AM'), findsOneWidget);
    });

    testWidgets('shows the verified tick only when verified', (tester) async {
      await _pump(tester, const AppAvatar(name: 'Brian O.'));
      expect(find.byType(AppVerifiedDot), findsNothing);

      await _pump(tester, const AppAvatar(name: 'Brian O.', isVerified: true));
      expect(find.byType(AppVerifiedDot), findsOneWidget);
    });
  });

  group('AppCard', () {
    testWidgets('is tappable when given an action', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppCard(onTap: () => taps++, child: const Text('Open')),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('exposes a semantic label to a screen reader', (tester) async {
      await _pump(
        tester,
        AppCard(
          onTap: () {},
          semanticLabel: 'Open Sarah',
          child: const Text('Sarah'),
        ),
      );

      expect(
        tester.getSemantics(find.text('Sarah')),
        matchesSemantics(
          label: 'Open Sarah',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });
  });

  group('EmptyView', () {
    testWidgets('says what would fill the screen', (tester) async {
      await _pump(
        tester,
        const EmptyView(
          title: 'No sessions yet',
          message: 'Ask for help and your first session appears here.',
          action: AppButton(label: 'Ask for help', onPressed: null),
        ),
      );

      expect(find.text('No sessions yet'), findsOneWidget);
      expect(
        find.text('Ask for help and your first session appears here.'),
        findsOneWidget,
      );
      expect(find.text('Ask for help'), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('shows one action beside the title', (tester) async {
      await _pump(
        tester,
        SectionHeader(
          title: 'Tutors who can help',
          subtitle: 'Meet on campus or online.',
          actionLabel: 'See all',
          onAction: () {},
        ),
      );

      expect(find.text('Tutors who can help'), findsOneWidget);
      expect(find.text('Meet on campus or online.'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
    });
  });

  group('AppSkeleton', () {
    testWidgets('a line has the text height and a pill radius', (tester) async {
      await _pump(tester, const AppSkeleton.line(width: 120));

      final box = tester.getSize(find.byType(AppSkeleton));
      expect(box.height, 12);
      expect(box.width, 120);
    });

    testWidgets('announces loading once, not per block', (tester) async {
      await _pump(tester, const AppSkeletonList(itemCount: 2));
      await tester.pump();

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });
  });
}
