import 'package:peerpass/features/notifications/data/models/notification_model.dart';

/// A notification as the API would return it, with the fields a test does not
/// care about left at their neutral defaults.
///
/// Shared by the model, provider, screen, and shell tests. One builder keeps a
/// renamed field from being missed in three files that each kept their own copy.
AppNotification notification({
  String id = 'notification-1',
  AppNotificationType type = AppNotificationType.requestReceived,
  String title = 'New tutoring request',
  String body = 'A student needs help with CSC 121.',
  Map<String, String> data = const <String, String>{},
  DateTime? readAt,
  DateTime? createdAt,
}) {
  return AppNotification(
    id: id,
    typeWire: type.wireValue,
    title: title,
    body: body,
    data: data,
    readAt: readAt,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 3, 9),
  );
}
