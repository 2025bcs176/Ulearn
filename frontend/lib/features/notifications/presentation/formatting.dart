import 'package:clock/clock.dart';
import 'package:intl/intl.dart';

/// When a notification arrived, as a student reads it.
///
/// Relative up to a week, then a date. "3d ago" is useful; "3 March" is what a
/// month-old row should say instead, because the exact day stops mattering and
/// the relative number stops being meaningful. A future timestamp -- a phone
/// whose clock is behind the server's -- reads as "Just now" rather than
/// "in -2 minutes".
///
/// [now] is injectable so a test can assert on a fixed clock instead of hoping
/// the second does not tick over mid-run. Production callers leave it out and
/// use the clock package, which the test binding controls.
String relativeTimeLabel(DateTime moment, {DateTime? now}) {
  final reference = now ?? clock.now();
  final elapsed = reference.difference(moment);

  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';

  return DateFormat('d MMM').format(moment.toLocal());
}
