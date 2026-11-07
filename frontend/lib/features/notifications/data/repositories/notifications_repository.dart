import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/features/notifications/data/models/notification_model.dart';

/// The inbox contract the screens depend on.
///
/// Every method throws a [Failure], never a transport exception and never a
/// `FormatException`. Translating `DioException`, problem documents, and
/// unparseable bodies into [Failure] happens in the implementation, so a screen
/// renders a message and never has to know whether the API answered with a
/// socket error, a 401, or a body that was not the shape it documents.
///
/// Deliberately narrow. Device registration is the API's but has no screen in
/// this release, because push is deferred and a registration call nothing sends
/// to would be a token stored for no reader.
abstract interface class NotificationsRepository {
  /// One page of the caller's inbox, newest first.
  ///
  /// There is no user parameter, and that is the contract rather than an
  /// omission: the API answers about the caller and nobody else. A method that
  /// could be handed somebody else's id would be a method whose safety depended
  /// on every caller.
  Future<NotificationPage> inbox({int limit, int offset});

  /// How many of the caller's notifications are unread.
  ///
  /// A separate call from [inbox] because the badge needs the number before the
  /// list is opened, and a page not yet fetched cannot provide it.
  Future<int> unreadCount();

  /// Marks one notification read and returns it as it now stands.
  ///
  /// Idempotent on the API side: reading a row that is already read succeeds
  /// with the original timestamp. That matters on a phone, where a double tap is
  /// ordinary and must not turn into an error banner.
  Future<AppNotification> markRead(String notificationId);

  /// Marks every unread notification read and returns how many changed.
  Future<int> markAllRead();
}

/// The inbox contract, as a live instance.
///
/// Declared in the contract file rather than beside the notifications screens,
/// for the same reason `sessionsRepositoryProvider` is: this is the handle by
/// which other features reach this feature, and a provider living in
/// `presentation/` could not be imported by a sibling feature without also
/// importing its screens.
///
/// Throwing rather than defaulting keeps a missing override loud. A silent fake
/// default would ship an inbox that always said "all caught up", and the
/// composition root in `main.dart` is what has to name the real implementation.
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => throw UnimplementedError(
    'notificationsRepositoryProvider must be overridden in ProviderScope.',
  ),
);
