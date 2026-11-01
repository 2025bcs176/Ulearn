import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

final sessionCacheProvider = Provider<SessionCache?>((ref) => null);

/// Encrypted, bounded cache for read-only session history.
class SessionCache {
  SessionCache({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _boxName = 'peerpass_sessions';
  static const _keyName = 'peerpass_hive_key';
  static const _payloadKey = 'payload';
  static const _storedAtKey = 'stored_at';
  static const _myRequestsPayloadKey = 'my_requests_payload';
  static const _myRequestsStoredAtKey = 'my_requests_stored_at';
  static const _awaitingRequestsPayloadKey = 'awaiting_requests_payload';
  static const _awaitingRequestsStoredAtKey = 'awaiting_requests_stored_at';
  static const _maxAge = Duration(hours: 24);

  final FlutterSecureStorage _secureStorage;
  late final Box<String> _box;
  String? _accountId;

  String? get accountId => _accountId;

  /// Switches the cache namespace before authenticated reads begin.
  ///
  /// A namespace is captured at the start of each operation, so a response
  /// finishing after sign-out cannot write into the next account's cache.
  void activateAccount(String accountId) {
    if (accountId.isEmpty || accountId == _accountId) return;
    _accountId = accountId;
  }

  void deactivateAccount() {
    _accountId = null;
  }

  Future<void> open() async {
    await Hive.initFlutter();
    final existing = await _secureStorage.read(key: _keyName);
    final key = existing == null
        ? Hive.generateSecureKey()
        : base64Url.decode(existing);
    if (existing == null) {
      await _secureStorage.write(key: _keyName, value: base64UrlEncode(key));
    }
    _box = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: HiveAesCipher(key),
    );
  }

  Future<List<Map<String, dynamic>>?> readSessions() async {
    final keys = _keys(_payloadKey, _storedAtKey);
    if (keys == null) return null;
    final storedAt = _box.get(keys.$2);
    final payload = _box.get(keys.$1);
    if (storedAt == null || payload == null) return null;
    final timestamp = DateTime.tryParse(storedAt);
    if (timestamp == null ||
        DateTime.now().toUtc().difference(timestamp.toUtc()) > _maxAge) {
      await _box.delete(keys.$1);
      await _box.delete(keys.$2);
      return null;
    }
    final decoded = jsonDecode(payload);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Future<void> writeSessions(List<Map<String, dynamic>> sessions) async {
    final keys = _keys(_payloadKey, _storedAtKey);
    if (keys == null) return;
    await _box.put(keys.$1, jsonEncode(sessions));
    await _box.put(keys.$2, DateTime.now().toUtc().toIso8601String());
  }

  Future<List<Map<String, dynamic>>?> readHelpRequests({
    required bool awaitingTutor,
  }) async {
    final payloadKey = awaitingTutor
        ? _awaitingRequestsPayloadKey
        : _myRequestsPayloadKey;
    final storedAtKey = awaitingTutor
        ? _awaitingRequestsStoredAtKey
        : _myRequestsStoredAtKey;
    final keys = _keys(payloadKey, storedAtKey);
    if (keys == null) return null;
    return await _readList(keys.$1, keys.$2);
  }

  Future<void> writeHelpRequests(
    List<Map<String, dynamic>> requests, {
    required bool awaitingTutor,
  }) async {
    final payloadKey = awaitingTutor
        ? _awaitingRequestsPayloadKey
        : _myRequestsPayloadKey;
    final storedAtKey = awaitingTutor
        ? _awaitingRequestsStoredAtKey
        : _myRequestsStoredAtKey;
    final keys = _keys(payloadKey, storedAtKey);
    if (keys == null) return;
    await _box.put(keys.$1, jsonEncode(requests));
    await _box.put(keys.$2, DateTime.now().toUtc().toIso8601String());
  }

  Future<List<Map<String, dynamic>>?> _readList(
    String payloadKey,
    String storedAtKey,
  ) async {
    final storedAt = _box.get(storedAtKey);
    final payload = _box.get(payloadKey);
    if (storedAt == null || payload == null) return null;
    final timestamp = DateTime.tryParse(storedAt);
    if (timestamp == null ||
        DateTime.now().toUtc().difference(timestamp.toUtc()) > _maxAge) {
      await _box.delete(payloadKey);
      await _box.delete(storedAtKey);
      return null;
    }
    final decoded = jsonDecode(payload);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Future<void> clear() async {
    final account = _accountId;
    if (account == null) return;
    for (final key in [
      _payloadKey,
      _storedAtKey,
      _myRequestsPayloadKey,
      _myRequestsStoredAtKey,
      _awaitingRequestsPayloadKey,
      _awaitingRequestsStoredAtKey,
    ]) {
      await _box.delete(_scopedKey(account, key));
    }
  }

  (String, String)? _keys(String payloadKey, String storedAtKey) {
    final account = _accountId;
    if (account == null) return null;
    return (_scopedKey(account, payloadKey), _scopedKey(account, storedAtKey));
  }

  String _scopedKey(String account, String key) => '$account::$key';
}
