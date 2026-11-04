import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/features/notifications/data/datasources/remote_notifications_datasource.dart';
import 'package:peerpass/features/notifications/data/models/notification_model.dart';
import 'package:peerpass/features/notifications/data/repositories/remote_notifications_repository.dart';

/// A recorded request, so a test can assert on what the client actually sent.
class _Call {
  _Call(this.method, this.path, this.query, this.body);

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Object? body;

  @override
  String toString() => '$method $path $query $body';
}

/// Answers requests from a script, and records what it was asked.
///
/// Copied in shape from the sessions repository's server: the thing under test
/// here is the wire -- which path, which query, which body -- and a mock at the
/// datasource boundary would let a renamed field pass.
class _FakeServer implements HttpClientAdapter {
  final List<_Call> calls = [];
  final List<Object?> _replies = [];

  void reply(int status, Object? body) => _replies.add(_Reply(status, body));

  void fail(DioException error) => _replies.add(error);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(
      _Call(
        options.method,
        options.path,
        Map<String, dynamic>.of(options.queryParameters),
        _decode(options.data),
      ),
    );

    final reply = _replies.removeAt(0);
    if (reply is DioException) throw reply;

    final r = reply! as _Reply;
    return ResponseBody.fromString(
      r.body == null ? '' : jsonEncode(r.body),
      r.status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Object? _decode(Object? data) {
  if (data is! String) return data;
  try {
    return jsonDecode(data);
  } on FormatException {
    return data;
  }
}

class _Reply {
  _Reply(this.status, this.body);

  final int status;
  final Object? body;
}

Map<String, dynamic> _row({
  String id = 'notification-1',
  String type = 'request_received',
  String? readAt,
}) {
  return {
    'id': id,
    'type': type,
    'title': 'New tutoring request',
    'body': 'A student needs help with graphs in CSC 121.',
    'data': {'kind': 'help_request', 'request_id': 'request-1'},
    'read_at': readAt,
    'created_at': '2026-11-03T09:00:00Z',
  };
}

Map<String, dynamic> _problem({
  int status = 404,
  String detail = 'Not found.',
}) {
  return {
    'type': 'https://peerpass.app/problems/not-found',
    'title': 'Not found',
    'status': status,
    'detail': detail,
  };
}

void main() {
  late _FakeServer server;
  late RemoteNotificationsRepository repository;

  setUp(() {
    server = _FakeServer();
    // validateStatus matches the production client, so a 4xx throws here exactly
    // as it would against the real API. A test client that returned error
    // statuses as values would never exercise the failure mapping.
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.peerpass.test',
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    )..httpClientAdapter = server;

    repository = RemoteNotificationsRepository(
      RemoteNotificationsDatasource(dio),
    );
  });

  group('the inbox', () {
    test('asks for the caller page at the offset it was given', () async {
      server.reply(200, {
        'items': [_row()],
        'total': 25,
        'limit': 20,
        'offset': 20,
        'has_more': true,
      });

      final page = await repository.inbox(offset: 20);

      expect(server.calls.single.method, 'GET');
      expect(server.calls.single.path, '/v1/notifications');
      expect(server.calls.single.query, {'limit': 20, 'offset': 20});
      expect(page.items.single.id, 'notification-1');
      expect(page.total, 25);
      expect(page.hasMore, isTrue);
    });

    test('an unknown type is tolerated rather than dropped', () async {
      server.reply(200, {
        'items': [_row(type: 'certificate_earned')],
        'total': 1,
        'limit': 20,
        'offset': 0,
        'has_more': false,
      });

      final page = await repository.inbox();

      expect(page.items.single.type, AppNotificationType.unknown);
      expect(page.items.single.typeWire, 'certificate_earned');
    });

    test(
      'a body the client cannot read is a server fault, not a raw throw',
      () async {
        server.reply(200, {'items': 'not a list'});

        await expectLater(
          repository.inbox(),
          throwsA(
            isA<ServerFailure>().having(
              (failure) => failure.message,
              'message',
              contains('could not read'),
            ),
          ),
        );
      },
    );

    test('a dropped connection is a network failure', () async {
      server.fail(
        DioException(
          requestOptions: RequestOptions(path: '/v1/notifications'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(repository.inbox(), throwsA(isA<NetworkFailure>()));
    });
  });

  test('the unread count is the API number, not a list length', () async {
    server.reply(200, {'count': 12});

    final count = await repository.unreadCount();

    expect(server.calls.single.path, '/v1/notifications/unread-count');
    expect(count, 12);
  });

  test(
    'marking one row read posts to that row and adopts the answer',
    () async {
      server.reply(200, _row(readAt: '2026-11-03T10:00:00Z'));

      final notification = await repository.markRead('notification-1');

      expect(server.calls.single.method, 'POST');
      expect(server.calls.single.path, '/v1/notifications/notification-1/read');
      expect(notification.isUnread, isFalse);
      expect(notification.readAt, DateTime.utc(2026, 11, 3, 10));
    },
  );

  test('a row belonging to someone else is a not-found failure', () async {
    // 404, not 403: the API deliberately will not confirm that an id exists.
    server.reply(404, _problem());

    await expectLater(
      repository.markRead('someone-elses-row'),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('read-all reports how many rows actually changed', () async {
    server.reply(200, {'marked': 4});

    final marked = await repository.markAllRead();

    expect(server.calls.single.path, '/v1/notifications/read-all');
    expect(server.calls.single.method, 'POST');
    expect(marked, 4);
  });
}
