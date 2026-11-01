import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
    final storedAt = _box.get(_storedAtKey);
    final payload = _box.get(_payloadKey);
    if (storedAt == null || payload == null) return null;
    final timestamp = DateTime.tryParse(storedAt);
    if (timestamp == null ||
        DateTime.now().toUtc().difference(timestamp.toUtc()) > _maxAge) {
      await clear();
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
    await _box.put(_payloadKey, jsonEncode(sessions));
    await _box.put(_storedAtKey, DateTime.now().toUtc().toIso8601String());
  }

  Future<List<Map<String, dynamic>>?> readHelpRequests({
    required bool awaitingTutor,
  }) async {
    return await _readList(
      awaitingTutor ? _awaitingRequestsPayloadKey : _myRequestsPayloadKey,
      awaitingTutor ? _awaitingRequestsStoredAtKey : _myRequestsStoredAtKey,
    );
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
    await _box.put(payloadKey, jsonEncode(requests));
    await _box.put(storedAtKey, DateTime.now().toUtc().toIso8601String());
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

  Future<void> clear() => _box.clear();
}
