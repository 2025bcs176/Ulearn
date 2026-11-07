import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/features/notifications/data/models/notification_model.dart';
import 'package:peerpass/features/notifications/data/repositories/fake_notifications_repository.dart';
import 'package:peerpass/features/notifications/data/repositories/notifications_repository.dart';
import 'package:peerpass/features/notifications/presentation/providers/notification_providers.dart';

import '../../support.dart';

ProviderContainer _container(NotificationsRepository repository) {
  final container = ProviderContainer(
    overrides: [notificationsRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

/// A repository whose first inbox page is fine and whose later pages are not.
class _RefreshFailingRepository extends FakeNotificationsRepository {
  _RefreshFailingRepository({super.notifications});

  int inboxCalls = 0;

  @override
  Future<NotificationPage> inbox({int limit = 20, int offset = 0}) {
    inboxCalls++;
    if (inboxCalls > 1) throw const NetworkFailure();
    return super.inbox(limit: limit, offset: offset);
  }
}

/// A repository that cannot mark a row read.
class _ReadFailingRepository extends FakeNotificationsRepository {
  _ReadFailingRepository({super.notifications});

  @override
  Future<AppNotification> markRead(String notificationId) async {
    throw const NetworkFailure();
  }
}

/// A repository that refuses to load at all.
class _OfflineNotificationsRepository extends FakeNotificationsRepository {
  @override
  Future<NotificationPage> inbox({int limit = 20, int offset = 0}) async {
    throw const NetworkFailure();
  }
}

void main() {
  test('loads the first page and the API unread count', () async {
    final repository = FakeNotificationsRepository(
      notifications: [
        notification(id: 'one'),
        notification(id: 'two', type: AppNotificationType.promotion),
        notification(id: 'three', readAt: DateTime.utc(2026, 11, 2)),
      ],
    );
    final container = _container(repository);

    final state = await container.read(notificationInboxProvider.future);

    expect(state.items.map((item) => item.id), ['one', 'two', 'three']);
    expect(state.total, 3);
    expect(state.hasMore, isFalse);
    // Two unread rows, from three notifications. The count is the API's answer,
    // not `items.length`, which happens to be three.
    expect(state.unreadCount, 2);
    expect(repository.inboxOffsets, [0]);
    expect(container.read(notificationUnreadCountProvider), 2);
  });

  test('load more appends the next offset and stops at the end', () async {
    final repository = FakeNotificationsRepository(
      notifications: [
        for (var index = 0; index < 25; index++)
          notification(id: 'notification-$index'),
      ],
    );
    final container = _container(repository);
    final notifier = container.read(notificationInboxProvider.notifier);

    final first = await container.read(notificationInboxProvider.future);
    expect(first.items.length, NotificationInboxNotifier.pageSize);
    expect(first.hasMore, isTrue);

    await notifier.loadMore();
    final second = container.read(notificationInboxProvider).value!;

    expect(second.items.length, 25);
    expect(second.items.last.id, 'notification-24');
    expect(second.hasMore, isFalse);
    expect(repository.inboxOffsets, [0, 20]);

    // A second tap at the end is a no-op rather than a request for an empty page.
    await notifier.loadMore();
    expect(repository.inboxOffsets, [0, 20]);
  });

  test('reading one row clears it and decrements the badge once', () async {
    final repository = FakeNotificationsRepository(
      notifications: [
        notification(id: 'one'),
        notification(id: 'two'),
      ],
    );
    final container = _container(repository);
    final notifier = container.read(notificationInboxProvider.notifier);
    await container.read(notificationInboxProvider.future);

    await notifier.markRead('one');
    final after = container.read(notificationInboxProvider).value!;

    expect(repository.readIds, ['one']);
    expect(after.items.first.isUnread, isFalse);
    expect(after.items.last.isUnread, isTrue);
    expect(after.unreadCount, 1);

    // Opening an already-read row is ordinary and must not call the API again or
    // decrement the badge twice.
    await notifier.markRead('one');
    final again = container.read(notificationInboxProvider).value!;
    expect(repository.readIds, ['one']);
    expect(again.unreadCount, 1);
  });

  test('reading the whole inbox clears every loaded row', () async {
    final repository = FakeNotificationsRepository(
      notifications: [
        notification(id: 'one'),
        notification(id: 'two'),
        notification(id: 'three', readAt: DateTime.utc(2026, 11, 2)),
      ],
    );
    final container = _container(repository);
    final notifier = container.read(notificationInboxProvider.notifier);
    await container.read(notificationInboxProvider.future);

    await notifier.markAllRead();
    final state = container.read(notificationInboxProvider).value!;

    expect(repository.markAllReadCalls, 1);
    expect(state.unreadCount, 0);
    expect(state.items.every((item) => !item.isUnread), isTrue);
    expect(container.read(notificationUnreadCountProvider), 0);
  });

  test('a failed read keeps the inbox and says why', () async {
    final repository = _ReadFailingRepository(
      notifications: [notification(id: 'one')],
    );
    final container = _container(repository);
    final notifier = container.read(notificationInboxProvider.notifier);
    await container.read(notificationInboxProvider.future);

    await notifier.markRead('one');
    final state = container.read(notificationInboxProvider).value!;

    // The row is still there, still unread, and the failure is the banner --
    // not an AsyncError that would throw the whole list away.
    expect(state.items.single.isUnread, isTrue);
    expect(state.unreadCount, 1);
    expect(state.actionFailure, isA<NetworkFailure>());
    expect(
      container.read(notificationInboxProvider),
      isA<AsyncData<NotificationInboxState>>(),
    );
  });

  test('a failed refresh keeps what the student already had', () async {
    final repository = _RefreshFailingRepository(
      notifications: [notification(id: 'one')],
    );
    final container = _container(repository);
    final notifier = container.read(notificationInboxProvider.notifier);
    await container.read(notificationInboxProvider.future);

    await notifier.refresh();
    final state = container.read(notificationInboxProvider).value!;

    expect(state.items.single.id, 'one');
    expect(state.actionFailure, isA<NetworkFailure>());
  });

  test('a first load failure is the screen error state', () async {
    final container = _container(_OfflineNotificationsRepository());

    await expectLater(
      container.read(notificationInboxProvider.future),
      throwsA(isA<NetworkFailure>()),
    );
    expect(
      container.read(notificationInboxProvider),
      isA<AsyncError<NotificationInboxState>>(),
    );
  });
}
