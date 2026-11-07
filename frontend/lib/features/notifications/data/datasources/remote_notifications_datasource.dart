import 'package:dio/dio.dart';

/// Talks to the `/v1/notifications` endpoints the inbox uses.
///
/// Throws [DioException], not a `Failure`. Classification belongs to
/// `core/network/network_exceptions.dart` and happens once, in the repository, so
/// a socket error and an RFC 9457 problem document are translated by the same
/// code whichever endpoint produced them. Bodies come back as raw JSON on
/// purpose: the repository is where the wire shape becomes a model, so there is
/// one place to look when the two disagree.
class RemoteNotificationsDatasource {
  const RemoteNotificationsDatasource(this._dio);

  final Dio _dio;

  /// One page of the caller's inbox, newest first.
  ///
  /// `limit` and `offset` are the API's own paging parameters. The screen asks
  /// for a second page by moving the offset, never by keeping a page number that
  /// could disagree with the API's envelope.
  Future<Map<String, dynamic>> inbox({
    required int limit,
    required int offset,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/notifications',
      queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
    );
    return response.data!;
  }

  /// The number behind the bell.
  Future<int> unreadCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/notifications/unread-count',
    );
    final count = response.data!['count'];
    if (count is! int) {
      throw const FormatException('An unread count is malformed.');
    }
    return count;
  }

  /// Marks one row read and returns it as it now stands.
  Future<Map<String, dynamic>> markRead(String notificationId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/notifications/$notificationId/read',
    );
    return response.data!;
  }

  /// Marks every unread row read and returns how many changed.
  Future<int> markAllRead() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/notifications/read-all',
    );
    final marked = response.data!['marked'];
    if (marked is! int) {
      throw const FormatException('A read-all response is malformed.');
    }
    return marked;
  }
}
