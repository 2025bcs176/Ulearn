import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/features/notifications/data/models/notification_model.dart';
import 'package:peerpass/features/notifications/data/repositories/notifications_repository.dart';

/// The inbox as the screen and the tab badge see it.
///
/// A state object rather than a bare `List`, because the screen has more than one
/// thing to say: what arrived, whether an older page is loading, and why the
/// *last action* failed. A failed "mark all read" has to appear while the list
/// stays on screen, so the two cannot share one [AsyncValue] -- an [AsyncError]
/// would throw the list away to report a rejected tap.
@immutable
class NotificationInboxState {
  const NotificationInboxState({
    required this.items,
    required this.total,
    required this.limit,
    required this.hasMore,
    required this.unreadCount,
    this.isLoadingMore = false,
    this.actionFailure,
  });

  /// The rows loaded so far, newest first.
  final List<AppNotification> items;

  /// How many rows the server holds in total, loaded or not.
  final int total;

  /// The page size the first request used. Later pages reuse it so the offset
  /// arithmetic cannot drift from the page the server actually sent.
  final int limit;

  /// Whether the server holds rows beyond [items].
  final bool hasMore;

  /// The badge number reported by the API, not a count of [items].
  ///
  /// Deliberately separate: a page of 20 can sit under a hundred unread rows,
  /// and counting what happens to be loaded would show "3" on a bell that should
  /// say "12" until the user scrolled.
  final int unreadCount;

  final bool isLoadingMore;

  /// The failure from the last read/load-more action, if it failed.
  final Failure? actionFailure;

  bool get isEmpty => items.isEmpty;

  NotificationInboxState copyWith({
    List<AppNotification>? items,
    int? total,
    int? limit,
    bool? hasMore,
    int? unreadCount,
    bool? isLoadingMore,
    Failure? actionFailure,
    bool resetActionFailure = false,
  }) {
    return NotificationInboxState(
      items: items ?? this.items,
      total: total ?? this.total,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      // Null is a real value here ("nothing failed"), so it cannot also mean
      // "leave it alone". The flag is how a successful action clears the banner.
      actionFailure: resetActionFailure
          ? null
          : actionFailure ?? this.actionFailure,
    );
  }
}

/// The signed-in user's inbox.
///
/// An [AsyncNotifier] for the same reason the session list is one: [AsyncValue]
/// already carries loading, the data, and the reason there is none. Riverpod's
/// automatic retry is switched off, because a screen that says "no connection,
/// try again" should not quietly re-request underneath the student's finger. The
/// button and the pull-to-refresh are the retry.
final notificationInboxProvider =
    AsyncNotifierProvider<NotificationInboxNotifier, NotificationInboxState>(
      NotificationInboxNotifier.new,
      retry: (retryCount, error) => null,
    );

/// The number the tab badge shows.
///
/// Derived from the inbox rather than fetched again, so reading one row clears
/// the badge without a second request. It still uses the API's `unread_count`
/// (carried on the state) rather than counting loaded rows, because a page of 20
/// is not the whole inbox.
final notificationUnreadCountProvider = Provider<int>(
  (ref) => ref.watch(notificationInboxProvider).value?.unreadCount ?? 0,
);

class NotificationInboxNotifier extends AsyncNotifier<NotificationInboxState> {
  /// One page. Matches the API's default and keeps the first paint small.
  static const int pageSize = 20;

  @override
  Future<NotificationInboxState> build() => _load();

  /// Re-reads the first page and the badge.
  ///
  /// Keeps the loaded list on screen when this is a pull-to-refresh that failed;
  /// a student who already has their inbox should not lose it because the train
  /// went into a tunnel. The first load has nothing to keep, so it surfaces as
  /// the screen's error state.
  Future<void> refresh() async {
    final current = state.value;
    try {
      state = AsyncValue.data(await _load());
    } on Object catch (error, stack) {
      if (current == null) {
        state = AsyncValue.error(error, stack);
      } else {
        state = AsyncValue.data(
          current.copyWith(actionFailure: failureFor(error)),
        );
      }
    }
  }

  /// Fetches the next page and appends it.
  ///
  /// Idempotent against a double tap through [NotificationInboxState.isLoadingMore].
  /// Rows are deduplicated by id because a new notification arriving between two
  /// pages shifts every offset by one, and appending a duplicate would make the
  /// list disagree with its own keys.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(
      current.copyWith(isLoadingMore: true, resetActionFailure: true),
    );

    final repository = ref.read(notificationsRepositoryProvider);
    try {
      final page = await repository.inbox(
        limit: current.limit,
        offset: current.items.length,
      );
      final known = {for (final item in current.items) item.id};
      final merged = <AppNotification>[
        ...current.items,
        ...page.items.where((item) => !known.contains(item.id)),
      ];
      final latest = state.value ?? current;
      state = AsyncValue.data(
        latest.copyWith(
          items: List<AppNotification>.unmodifiable(merged),
          total: page.total,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } on Object catch (error) {
      final latest = state.value ?? current;
      state = AsyncValue.data(
        latest.copyWith(isLoadingMore: false, actionFailure: failureFor(error)),
      );
    }
  }

  /// Marks one row read and clears it from the badge.
  ///
  /// A row that is already read is a no-op: the API is idempotent, and so is
  /// this, because opening a notification twice is what a person does.
  Future<void> markRead(String notificationId) async {
    final current = state.value;
    if (current == null) return;

    final index = current.items.indexWhere((item) => item.id == notificationId);
    if (index == -1 || !current.items[index].isUnread) return;

    final repository = ref.read(notificationsRepositoryProvider);
    try {
      final updated = await repository.markRead(notificationId);
      final latest = state.value ?? current;
      final wasStillUnread = latest.items.any(
        (item) => item.id == notificationId && item.isUnread,
      );
      final items = <AppNotification>[
        for (final item in latest.items)
          if (item.id == notificationId) updated else item,
      ];

      state = AsyncValue.data(
        latest.copyWith(
          items: List<AppNotification>.unmodifiable(items),
          unreadCount: wasStillUnread && latest.unreadCount > 0
              ? latest.unreadCount - 1
              : latest.unreadCount,
          resetActionFailure: true,
        ),
      );
    } on Object catch (error) {
      final latest = state.value ?? current;
      state = AsyncValue.data(
        latest.copyWith(actionFailure: failureFor(error)),
      );
    }
  }

  /// Clears the badge in one tap.
  ///
  /// The rows loaded so far are updated locally from the server's answer; the
  /// API owns the rows not yet loaded. The state's count goes to zero because
  /// that is what the API just reported, not because every row is on screen.
  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null || current.unreadCount == 0) return;

    final repository = ref.read(notificationsRepositoryProvider);
    try {
      await repository.markAllRead();
      final latest = state.value ?? current;
      final now = clock.now();
      final items = <AppNotification>[
        for (final item in latest.items)
          if (item.isUnread) item.markedRead(now) else item,
      ];
      state = AsyncValue.data(
        latest.copyWith(
          items: List<AppNotification>.unmodifiable(items),
          unreadCount: 0,
          resetActionFailure: true,
        ),
      );
    } on Object catch (error) {
      final latest = state.value ?? current;
      state = AsyncValue.data(
        latest.copyWith(actionFailure: failureFor(error)),
      );
    }
  }

  Future<NotificationInboxState> _load() async {
    final repository = ref.read(notificationsRepositoryProvider);
    final page = await repository.inbox(limit: pageSize);
    final unread = await repository.unreadCount();
    return NotificationInboxState(
      items: page.items,
      total: page.total,
      limit: page.limit,
      hasMore: page.hasMore,
      unreadCount: unread,
    );
  }
}
