import 'package:dio/dio.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/network/network_exceptions.dart';
import 'package:peerpass/features/notifications/data/datasources/remote_notifications_datasource.dart';
import 'package:peerpass/features/notifications/data/models/notification_model.dart';
import 'package:peerpass/features/notifications/data/repositories/notifications_repository.dart';

/// [NotificationsRepository] over the real API.
///
/// The only layer that knows both the wire format and the failure hierarchy. The
/// `_guard` helper below is the same shape as the one in
/// `remote_sessions_repository.dart`, duplicated rather than lifted into
/// `core/`: hoisting it means editing files this feature does not own, and the
/// note in `remote_incentives_repository.dart` already says lifting is overdue.
class RemoteNotificationsRepository implements NotificationsRepository {
  const RemoteNotificationsRepository(this._remote);

  final RemoteNotificationsDatasource _remote;

  @override
  Future<NotificationPage> inbox({int limit = 20, int offset = 0}) {
    // The whole body is inside the guard, including the parse. A malformed
    // response is a server fault, and a `fromJson` that ran after the guard
    // returned would throw past every translation here and reach the screen as a
    // bare `FormatException`.
    return _guard(
      () async => NotificationPage.fromJson(
        await _remote.inbox(limit: limit, offset: offset),
      ),
    );
  }

  @override
  Future<int> unreadCount() => _guard(_remote.unreadCount);

  @override
  Future<AppNotification> markRead(String notificationId) {
    return _guard(
      () async =>
          AppNotification.fromJson(await _remote.markRead(notificationId)),
    );
  }

  @override
  Future<int> markAllRead() => _guard(_remote.markAllRead);

  /// Runs a call and translates whatever comes back into a [Failure].
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  Failure _toFailure(Object error) {
    if (error is Failure) return error;
    if (error is FormatException) {
      // The API answered with something that is not the shape it documents.
      // Reported as a server fault rather than an unknown one, because that is
      // what it is, and a student cannot act on it either way.
      return const ServerFailure(
        'The server sent something we could not read.',
      );
    }
    if (error is DioException) return mapDioException(error);
    return const UnknownFailure();
  }
}
