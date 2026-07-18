import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_language.dart';
import '../transactions/transaction_type.dart';
import 'album_sync_ai_analyzer.dart';
import 'slip_fingerprint.dart';
import 'slip_scan_result.dart';
import 'slip_text_recognizer.dart';
import 'slip_transaction_resolver.dart';

const _albumSyncJobKey = 'album_sync.background_job';
const _albumSyncFingerprintsKey = 'album_sync.active_fingerprints';
const _albumSyncOpenPayload = 'open_album_sync';
const _albumSyncProgressChannelId = 'kimjod_album_sync_progress';
const _albumSyncCompleteChannelId = 'kimjod_album_sync_complete';
const _albumSyncProgressNotificationId = 73030;
const _albumSyncCompleteNotificationId = 73031;

final _albumSyncOpenController = StreamController<void>.broadcast();
final _albumSyncJobController =
    StreamController<AlbumSyncJobSnapshot?>.broadcast();
bool _pendingAlbumSyncOpenRequest = false;
bool _isAlbumSyncJobRunning = false;
final _cancelledAlbumSyncJobIds = <String>{};
StreamSubscription<AlbumSyncJobSnapshot>? _albumSyncProgressSubscription;

class AlbumSyncBackgroundService {
  const AlbumSyncBackgroundService._();

  static Future<void>? _initialization;

  static Stream<void> get openRequests => _albumSyncOpenController.stream;

  static Stream<AlbumSyncJobSnapshot?> get watchJob =>
      _albumSyncJobController.stream;

  static Stream<AlbumSyncJobSnapshot> get jobUpdates {
    return FlutterBackgroundService().on('albumSyncProgress').asyncMap((
      event,
    ) async {
      final rawJob = event?['job'];
      if (rawJob is Map) {
        return AlbumSyncJobSnapshot.fromJson(Map<String, dynamic>.from(rawJob));
      }

      final snapshot = await loadJob();
      if (snapshot == null) {
        throw StateError('Missing album sync job snapshot.');
      }
      return snapshot;
    });
  }

  static Future<void> initialize() async {
    final pending = _initialization;
    if (pending != null) return pending;

    final initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  static Future<void> _initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    final strings = await _notificationStrings();
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_bg_service_small'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launchDetails = await notifications.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        response?.payload == _albumSyncOpenPayload) {
      _requestOpenAlbumSync();
    }

    final androidNotifications = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(
      AndroidNotificationChannel(
        _albumSyncProgressChannelId,
        strings.albumSyncProgressChannel,
        description: strings.albumSyncProgressDescription,
        importance: Importance.low,
      ),
    );
    await androidNotifications?.createNotificationChannel(
      AndroidNotificationChannel(
        _albumSyncCompleteChannelId,
        strings.albumSyncCompleteChannel,
        description: strings.albumSyncCompleteDescription,
        importance: Importance.high,
      ),
    );

    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onAlbumSyncServiceStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: _albumSyncProgressChannelId,
        initialNotificationTitle: strings.syncAlbumTitle,
        initialNotificationContent: strings.preparingSlipScan,
        foregroundServiceNotificationId: _albumSyncProgressNotificationId,
        foregroundServiceTypes: const [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onAlbumSyncServiceStart,
        onBackground: _onAlbumSyncIosBackground,
      ),
    );

    _albumSyncProgressSubscription ??= jobUpdates.listen(
      _albumSyncJobController.add,
      onError: (_) {},
    );
  }

  static bool consumeOpenRequest() {
    final hadRequest = _pendingAlbumSyncOpenRequest;
    _pendingAlbumSyncOpenRequest = false;
    return hadRequest;
  }

  static Future<AlbumSyncJobSnapshot?> loadJob() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_albumSyncJobKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    return AlbumSyncJobSnapshot.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  static Future<AlbumSyncJobSnapshot> requestStart({
    required String userId,
    required List<String> imagePaths,
    required Set<String> activeFingerprints,
  }) async {
    await initialize();
    final snapshot = AlbumSyncJobSnapshot(
      jobId: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: userId,
      imagePaths: imagePaths,
      state: AlbumSyncJobState.scanning,
      items: imagePaths
          .map(
            (path) => AlbumSyncItemSnapshot(
              path: path,
              status: AlbumSyncItemStatus.reading,
            ),
          )
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );

    await _saveJob(snapshot);
    _albumSyncJobController.add(snapshot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _albumSyncFingerprintsKey,
      activeFingerprints.toList(growable: false),
    );

    await _requestNotificationPermission();

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
    service.invoke('startAlbumSync');

    return snapshot;
  }

  static Future<AlbumSyncJobSnapshot?> requestCancel() async {
    final current = await loadJob();
    if (current == null || !current.isScanning) {
      return current;
    }

    final cancelled = current.copyWith(
      state: AlbumSyncJobState.cancelled,
      items: current.items
          .map(
            (item) => item.status == AlbumSyncItemStatus.reading
                ? item.copyWith(status: AlbumSyncItemStatus.cancelled)
                : item,
          )
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );
    await _saveJob(cancelled);
    _albumSyncJobController.add(cancelled);

    FlutterBackgroundService().invoke('cancelAlbumSync', {
      'jobId': cancelled.jobId,
    });
    await FlutterLocalNotificationsPlugin().cancel(
      id: _albumSyncProgressNotificationId,
    );
    return cancelled;
  }

  static Future<void> clearFinishedJob() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_albumSyncJobKey);
    await prefs.remove(_albumSyncFingerprintsKey);
    _albumSyncJobController.add(null);
    try {
      await FlutterLocalNotificationsPlugin()
          .cancel(id: _albumSyncCompleteNotificationId)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // The saved result is already cleared. Notification cleanup must never
      // keep the review route stuck on devices that detach the plugin briefly.
    }
  }
}

class AlbumSyncJobSnapshot {
  const AlbumSyncJobSnapshot({
    required this.jobId,
    required this.userId,
    required this.imagePaths,
    required this.state,
    required this.items,
    required this.updatedAt,
  });

  final String jobId;
  final String userId;
  final List<String> imagePaths;
  final AlbumSyncJobState state;
  final List<AlbumSyncItemSnapshot> items;
  final DateTime updatedAt;

  int get totalCount => items.length;

  int get completedCount =>
      items.where((item) => item.status != AlbumSyncItemStatus.reading).length;

  int get readyCount =>
      items.where((item) => item.status == AlbumSyncItemStatus.ready).length;

  int get duplicateCount => items
      .where((item) => item.status == AlbumSyncItemStatus.duplicate)
      .length;

  int get failedCount =>
      items.where((item) => item.status == AlbumSyncItemStatus.failed).length;

  int get cancelledCount => items
      .where((item) => item.status == AlbumSyncItemStatus.cancelled)
      .length;

  double get progress =>
      totalCount == 0 ? 0 : (completedCount / totalCount).clamp(0.0, 1.0);

  bool get isScanning => state == AlbumSyncJobState.scanning;

  AlbumSyncJobSnapshot copyWith({
    AlbumSyncJobState? state,
    List<AlbumSyncItemSnapshot>? items,
    DateTime? updatedAt,
  }) {
    return AlbumSyncJobSnapshot(
      jobId: jobId,
      userId: userId,
      imagePaths: imagePaths,
      state: state ?? this.state,
      items: items ?? this.items,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      'userId': userId,
      'imagePaths': imagePaths,
      'state': state.name,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AlbumSyncJobSnapshot.fromJson(Map<String, dynamic> json) {
    return AlbumSyncJobSnapshot(
      jobId: json['jobId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      state: _enumByName(
        AlbumSyncJobState.values,
        json['state'] as String?,
        AlbumSyncJobState.completed,
      ),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) {
            return AlbumSyncItemSnapshot.fromJson(
              Map<String, dynamic>.from(item),
            );
          })
          .toList(growable: false),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AlbumSyncItemSnapshot {
  const AlbumSyncItemSnapshot({
    required this.path,
    required this.status,
    this.result,
    this.fingerprint,
    this.amount,
    this.decision,
  });

  final String path;
  final AlbumSyncItemStatus status;
  final SlipScanResult? result;
  final String? fingerprint;
  final double? amount;
  final SlipTransactionDecision? decision;

  AlbumSyncItemSnapshot copyWith({
    AlbumSyncItemStatus? status,
    SlipScanResult? result,
    String? fingerprint,
    double? amount,
    SlipTransactionDecision? decision,
  }) {
    return AlbumSyncItemSnapshot(
      path: path,
      status: status ?? this.status,
      result: result ?? this.result,
      fingerprint: fingerprint ?? this.fingerprint,
      amount: amount ?? this.amount,
      decision: decision ?? this.decision,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'status': status.name,
      'result': result?.toAlbumSyncJson(),
      'fingerprint': fingerprint,
      'amount': amount,
      'decision': decision?.toAlbumSyncJson(),
    };
  }

  factory AlbumSyncItemSnapshot.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    final rawDecision = json['decision'];
    return AlbumSyncItemSnapshot(
      path: json['path'] as String? ?? '',
      status: _enumByName(
        AlbumSyncItemStatus.values,
        json['status'] as String?,
        AlbumSyncItemStatus.failed,
      ),
      result: rawResult is Map
          ? SlipScanResultAlbumSyncJson.fromJson(
              Map<String, dynamic>.from(rawResult),
            )
          : null,
      fingerprint: json['fingerprint'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      decision: rawDecision is Map
          ? SlipTransactionDecisionAlbumSyncJson.fromJson(
              Map<String, dynamic>.from(rawDecision),
            )
          : null,
    );
  }
}

enum AlbumSyncJobState { scanning, completed, failed, cancelled }

enum AlbumSyncItemStatus { reading, ready, duplicate, failed, cancelled }

extension SlipScanResultAlbumSyncJson on SlipScanResult {
  Map<String, dynamic> toAlbumSyncJson() {
    return {
      'rawText': rawText,
      'bankName': bankName,
      'amount': amount,
      'dateText': dateText,
      'timeText': timeText,
      'recipient': recipient,
      'sender': sender,
      'reference': reference,
      'category': category.name,
      'amountConfidence': amountConfidence,
    };
  }

  static SlipScanResult fromJson(Map<String, dynamic> json) {
    return SlipScanResult(
      rawText: json['rawText'] as String? ?? '',
      bankName: json['bankName'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      dateText: json['dateText'] as String?,
      timeText: json['timeText'] as String?,
      recipient: json['recipient'] as String?,
      sender: json['sender'] as String?,
      reference: json['reference'] as String?,
      category: _enumByName(
        SlipCategory.values,
        json['category'] as String?,
        SlipCategory.unknown,
      ),
      amountConfidence: (json['amountConfidence'] as num?)?.toDouble(),
    );
  }
}

extension SlipTransactionDecisionAlbumSyncJson on SlipTransactionDecision {
  Map<String, dynamic> toAlbumSyncJson() {
    return {
      'type': type.name,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'note': note,
    };
  }

  static SlipTransactionDecision fromJson(Map<String, dynamic> json) {
    return SlipTransactionDecision(
      type: _enumByName(
        TransactionType.values,
        json['type'] as String?,
        TransactionType.expense,
      ),
      categoryId: json['categoryId'] as String? ?? 'other',
      categoryName: json['categoryName'] as String? ?? 'Other',
      note: json['note'] as String?,
    );
  }
}

@pragma('vm:entry-point')
Future<bool> _onAlbumSyncIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void _onAlbumSyncServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await _initializeBackgroundNotifications();

  service.on('startAlbumSync').listen((_) {
    unawaited(_runPendingAlbumSyncJob(service));
  });

  service.on('cancelAlbumSync').listen((event) {
    final jobId = event?['jobId'] as String?;
    if (jobId != null && jobId.isNotEmpty) {
      _cancelledAlbumSyncJobIds.add(jobId);
    }
  });

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  await _runPendingAlbumSyncJob(service);
}

Future<void> _runPendingAlbumSyncJob(ServiceInstance service) async {
  if (_isAlbumSyncJobRunning) {
    return;
  }

  final pendingSnapshot = await AlbumSyncBackgroundService.loadJob();
  if (pendingSnapshot == null ||
      !pendingSnapshot.isScanning ||
      pendingSnapshot.items.isEmpty) {
    return;
  }

  _isAlbumSyncJobRunning = true;
  var snapshot = pendingSnapshot;
  final recognizer = SlipTextRecognizer();
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final activeFingerprints =
        (prefs.getStringList(_albumSyncFingerprintsKey) ?? const <String>[])
            .toSet();

    if (!await _publishProgress(service, snapshot)) {
      return;
    }

    for (var i = 0; i < snapshot.items.length; i++) {
      if (await _isAlbumSyncCancellationRequested(snapshot.jobId)) {
        return;
      }

      final item = snapshot.items[i];
      if (item.status != AlbumSyncItemStatus.reading) {
        continue;
      }

      await _showProgressNotification(snapshot);

      try {
        final scannedResult = await recognizer.scanImagePath(item.path);
        if (await _isAlbumSyncCancellationRequested(snapshot.jobId)) {
          return;
        }
        final analysis = await analyzeAlbumSyncSlip(
          result: scannedResult,
          imagePath: item.path,
        );
        if (await _isAlbumSyncCancellationRequested(snapshot.jobId)) {
          return;
        }
        final result = analysis.result;
        final fingerprint = await buildSlipFingerprint(
          imagePath: item.path,
          result: result,
        );
        if (await _isAlbumSyncCancellationRequested(snapshot.jobId)) {
          return;
        }
        final decision = analysis.decision;
        final amount = result.amount;

        var status = AlbumSyncItemStatus.ready;
        if (activeFingerprints.contains(fingerprint)) {
          status = AlbumSyncItemStatus.duplicate;
        } else if (amount == null || amount <= 0 || decision == null) {
          status = AlbumSyncItemStatus.failed;
        }

        final nextItems = snapshot.items.toList(growable: false);
        nextItems[i] = item.copyWith(
          status: status,
          result: result,
          fingerprint: fingerprint,
          amount: amount,
          decision: decision,
        );
        snapshot = snapshot.copyWith(
          items: nextItems,
          updatedAt: DateTime.now(),
        );
      } catch (_) {
        if (await _isAlbumSyncCancellationRequested(snapshot.jobId)) {
          return;
        }
        final nextItems = snapshot.items.toList(growable: false);
        nextItems[i] = item.copyWith(status: AlbumSyncItemStatus.failed);
        snapshot = snapshot.copyWith(
          items: nextItems,
          updatedAt: DateTime.now(),
        );
      }

      if (!await _publishProgress(service, snapshot)) {
        return;
      }
    }

    if (await _isAlbumSyncCancellationRequested(snapshot.jobId)) {
      return;
    }
    snapshot = snapshot.copyWith(
      state: AlbumSyncJobState.completed,
      updatedAt: DateTime.now(),
    );
    if (await _publishProgress(service, snapshot)) {
      await _showCompletedNotification(snapshot);
    }
  } catch (_) {
    if (await _isAlbumSyncCancellationRequested(snapshot.jobId)) {
      return;
    }
    snapshot = snapshot.copyWith(
      state: AlbumSyncJobState.failed,
      updatedAt: DateTime.now(),
    );
    if (await _publishProgress(service, snapshot)) {
      await _showFailedNotification(snapshot);
    }
  } finally {
    _isAlbumSyncJobRunning = false;
    _cancelledAlbumSyncJobIds.remove(snapshot.jobId);
    await recognizer.close();
    if (service is AndroidServiceInstance) {
      await FlutterLocalNotificationsPlugin().cancel(
        id: _albumSyncProgressNotificationId,
      );
    }
    service.stopSelf();
  }
}

Future<bool> _publishProgress(
  ServiceInstance service,
  AlbumSyncJobSnapshot snapshot,
) async {
  final current = await AlbumSyncBackgroundService.loadJob();
  if (current?.jobId != snapshot.jobId ||
      (current?.state == AlbumSyncJobState.cancelled &&
          snapshot.state != AlbumSyncJobState.cancelled)) {
    return false;
  }
  await _saveJob(snapshot);
  await _showProgressNotification(snapshot);
  service.invoke('albumSyncProgress', {'job': snapshot.toJson()});
  return true;
}

Future<bool> _isAlbumSyncCancellationRequested(String jobId) async {
  if (_cancelledAlbumSyncJobIds.contains(jobId)) {
    return true;
  }
  final current = await AlbumSyncBackgroundService.loadJob();
  return current?.jobId != jobId ||
      current?.state == AlbumSyncJobState.cancelled;
}

Future<void> _saveJob(AlbumSyncJobSnapshot snapshot) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_albumSyncJobKey, jsonEncode(snapshot.toJson()));
}

Future<void> _initializeBackgroundNotifications() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return;
  }

  await FlutterLocalNotificationsPlugin().initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_bg_service_small'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
}

Future<void> _requestNotificationPermission() async {
  if (!Platform.isAndroid) {
    return;
  }

  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
}

Future<void> _showProgressNotification(AlbumSyncJobSnapshot snapshot) async {
  if (!Platform.isAndroid) {
    return;
  }

  final strings = await _notificationStrings();
  await FlutterLocalNotificationsPlugin().show(
    id: _albumSyncProgressNotificationId,
    title: strings.syncAlbumTitle,
    body: strings.albumSyncProgressBody(
      completed: snapshot.completedCount,
      total: snapshot.totalCount,
    ),
    payload: _albumSyncOpenPayload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _albumSyncProgressChannelId,
        strings.albumSyncProgressChannel,
        channelDescription: strings.albumSyncProgressDescription,
        icon: 'ic_bg_service_small',
        ongoing: true,
        autoCancel: false,
        silent: true,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: snapshot.totalCount,
        progress: snapshot.completedCount,
        category: AndroidNotificationCategory.progress,
      ),
    ),
  );
}

Future<void> _showCompletedNotification(AlbumSyncJobSnapshot snapshot) async {
  if (!Platform.isAndroid) {
    return;
  }

  final strings = await _notificationStrings();
  await FlutterLocalNotificationsPlugin().show(
    id: _albumSyncCompleteNotificationId,
    title: strings.albumSyncCompleteChannel,
    body: strings.albumSyncCompleteBody(
      ready: snapshot.readyCount,
      skipped: snapshot.duplicateCount,
      unreadable: snapshot.failedCount,
    ),
    payload: _albumSyncOpenPayload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _albumSyncCompleteChannelId,
        strings.albumSyncCompleteChannel,
        channelDescription: strings.albumSyncCompleteDescription,
        icon: 'ic_bg_service_small',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        category: AndroidNotificationCategory.status,
      ),
    ),
  );
}

Future<void> _showFailedNotification(AlbumSyncJobSnapshot snapshot) async {
  if (!Platform.isAndroid) {
    return;
  }

  final strings = await _notificationStrings();
  await FlutterLocalNotificationsPlugin().show(
    id: _albumSyncCompleteNotificationId,
    title: strings.albumSyncStopped,
    body: strings.albumSyncStoppedBody(snapshot.totalCount),
    payload: _albumSyncOpenPayload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _albumSyncCompleteChannelId,
        strings.albumSyncCompleteChannel,
        channelDescription: strings.albumSyncCompleteDescription,
        icon: 'ic_bg_service_small',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        category: AndroidNotificationCategory.status,
      ),
    ),
  );
}

Future<AppStrings> _notificationStrings() async {
  return AppStrings(await AppLanguageController.loadSavedLanguage());
}

void _onNotificationResponse(NotificationResponse response) {
  if (response.payload == _albumSyncOpenPayload) {
    _requestOpenAlbumSync();
  }
}

void _requestOpenAlbumSync() {
  _pendingAlbumSyncOpenRequest = true;
  _albumSyncOpenController.add(null);
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}
