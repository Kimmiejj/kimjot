import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class UsageAnalytics {
  UsageAnalytics._();

  static final instance = UsageAnalytics._();

  static const _versionChannel = MethodChannel('kimjod/app_update');
  static const _heartbeatInterval = Duration(minutes: 30);
  static const _minimumActivityWriteInterval = Duration(minutes: 15);
  static const _allowedFeatures = <String>{
    'home',
    'scan',
    'analytics',
    'settings',
    'album_sync',
  };

  Timer? _heartbeatTimer;
  String? _userId;
  String _versionName = '';
  int _versionCode = 0;
  Future<void>? _ready;
  DateTime? _lastActivityWriteAt;
  final _trackedFeatures = <String>{};

  Future<void> startSession(String userId) {
    if (_userId == userId && _ready != null) return _ready!;
    stop();
    _userId = userId;
    _trackedFeatures.add('home');
    _ready = _initializeAndStart(userId);
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(heartbeat()),
    );
    return _ready!;
  }

  Future<void> _initializeAndStart(String userId) async {
    try {
      final version = await _versionChannel.invokeMapMethod<String, Object?>(
        'getInstalledVersion',
      );
      _versionName = version?['versionName']?.toString() ?? '';
      _versionCode = _asInt(version?['versionCode']) ?? 0;
      if (_userId != userId) return;
      await _writeDailyUsage(incrementSession: true, feature: 'home');
    } catch (_) {
      // Usage telemetry must never interrupt the core app experience.
    }
  }

  Future<void> trackFeature(String feature) async {
    if (!_allowedFeatures.contains(feature) ||
        _userId == null ||
        !_trackedFeatures.add(feature)) {
      return;
    }
    try {
      await _ready;
      await _writeDailyUsage(feature: feature);
    } catch (_) {
      // Best-effort telemetry only.
    }
  }

  Future<void> heartbeat() async {
    if (_userId == null) return;
    final lastWriteAt = _lastActivityWriteAt;
    if (lastWriteAt != null &&
        DateTime.now().difference(lastWriteAt) <
            _minimumActivityWriteInterval) {
      return;
    }
    try {
      await _ready;
      await _writeDailyUsage();
    } catch (_) {
      // Best-effort telemetry only.
    }
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _userId = null;
    _ready = null;
    _lastActivityWriteAt = null;
    _trackedFeatures.clear();
  }

  Future<void> _writeDailyUsage({
    bool incrementSession = false,
    String? feature,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    final now = DateTime.now();
    final day = _dateKey(now);
    final userRef = FirebaseFirestore.instance
        .collection('usage_users')
        .doc(userId);
    final dailyRef = FirebaseFirestore.instance
        .collection('usage_days')
        .doc(day)
        .collection('daily_users')
        .doc(userId);

    final daily = <String, Object?>{
      'uid': userId,
      'day': day,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'versionName': _versionName,
      'versionCode': _versionCode,
      'platform': 'android',
      if (incrementSession) 'sessions': FieldValue.increment(1),
      if (feature != null)
        'features': <String, Object?>{feature: FieldValue.increment(1)},
    };

    final batch = FirebaseFirestore.instance.batch();
    if (incrementSession) {
      batch.set(userRef, <String, Object?>{
        'uid': userId,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'versionName': _versionName,
        'versionCode': _versionCode,
        'platform': 'android',
      }, SetOptions(merge: true));
    }
    batch.set(dailyRef, daily, SetOptions(merge: true));
    await batch.commit();
    _lastActivityWriteAt = now;
  }
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
