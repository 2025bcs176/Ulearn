import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/features/notifications/presentation/formatting.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);

  group('relativeTimeLabel', () {
    test('says just now for the first minute', () {
      expect(relativeTimeLabel(now, now: now), 'Just now');
      expect(
        relativeTimeLabel(now.subtract(const Duration(seconds: 59)), now: now),
        'Just now',
      );
    });

    test('a clock behind the server does not read as negative time', () {
      expect(
        relativeTimeLabel(now.add(const Duration(minutes: 2)), now: now),
        'Just now',
      );
    });

    test('counts minutes, then hours, then days', () {
      expect(
        relativeTimeLabel(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
      expect(
        relativeTimeLabel(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
      expect(
        relativeTimeLabel(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
    });

    test('switches to a date once a week has passed', () {
      // Local rather than UTC so the rendered day is the day the test names,
      // whatever timezone the machine running it is in.
      expect(relativeTimeLabel(DateTime(2026, 10, 20, 12), now: now), '20 Oct');
    });
  });
}
