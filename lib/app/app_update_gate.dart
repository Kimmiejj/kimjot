import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_language.dart';

abstract interface class AppUpdateService {
  Future<AppUpdateRequirement?> checkForRequiredUpdate();

  Future<bool> startRequiredUpdate(String? apkUrl, int targetVersionCode);
}

class FirebaseAndroidAppUpdateService implements AppUpdateService {
  FirebaseAndroidAppUpdateService({FirebaseFirestore? firestore})
    : this._(firestore);

  FirebaseAndroidAppUpdateService._(this._firestore);

  static const _channel = MethodChannel('kimjod/app_update');

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<AppUpdateRequirement?> checkForRequiredUpdate() async {
    try {
      final installed = await _channel.invokeMapMethod<String, Object?>(
        'getInstalledVersion',
      );
      final installedVersionCode = _asInt(installed?['versionCode']);
      if (installedVersionCode == null) return null;

      final snapshot = await _db.collection('app_config').doc('android').get();
      if (!snapshot.exists) return null;

      final requirement = AppUpdateRequirement.fromMap(
        snapshot.data()!,
        installedVersionCode: installedVersionCode,
        installedVersionName: installed?['versionName']?.toString() ?? '',
      );
      return requirement.isRequired ? requirement : null;
    } catch (_) {
      // A temporary config or Play service failure must not brick the app.
      return null;
    }
  }

  @override
  Future<bool> startRequiredUpdate(
    String? apkUrl,
    int targetVersionCode,
  ) async {
    try {
      return await _channel.invokeMethod<bool>('downloadAndInstallUpdate', {
            'apkUrl': apkUrl,
            'targetVersionCode': targetVersionCode,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

class AppUpdateRequirement {
  const AppUpdateRequirement({
    required this.minimumVersionCode,
    required this.installedVersionCode,
    required this.installedVersionName,
    required this.latestVersionName,
    required this.updateUrl,
    required this.messageTh,
    required this.messageEn,
  });

  factory AppUpdateRequirement.fromMap(
    Map<String, Object?> data, {
    required int installedVersionCode,
    required String installedVersionName,
  }) {
    return AppUpdateRequirement(
      minimumVersionCode: _asInt(data['minimumVersionCode']) ?? 0,
      installedVersionCode: installedVersionCode,
      installedVersionName: installedVersionName,
      latestVersionName: data['latestVersionName']?.toString() ?? '',
      updateUrl: _nonEmptyString(data['updateUrl']),
      messageTh: _nonEmptyString(data['messageTh']),
      messageEn: _nonEmptyString(data['messageEn']),
    );
  }

  final int minimumVersionCode;
  final int installedVersionCode;
  final String installedVersionName;
  final String latestVersionName;
  final String? updateUrl;
  final String? messageTh;
  final String? messageEn;

  bool get isRequired => installedVersionCode < minimumVersionCode;
}

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({required this.child, this.service, super.key});

  final Widget child;
  final AppUpdateService? service;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  static const _checkInterval = Duration(minutes: 1);

  late final AppUpdateService _service =
      widget.service ?? FirebaseAndroidAppUpdateService();

  Timer? _checkTimer;
  AppUpdateRequirement? _requirement;
  var _initializing = true;
  var _checking = false;
  var _automaticUpdateStarted = false;
  var _updating = false;
  var _updateStarted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdate();
    _checkTimer = Timer.periodic(_checkInterval, (_) => _checkForUpdate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForUpdate();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    _checking = true;
    final requirement = await _service.checkForRequiredUpdate();
    _checking = false;
    if (!mounted) return;
    setState(() {
      _initializing = false;
      // Once a required update is known, keep the app blocked through temporary
      // network failures. A successful installation restarts the process.
      if (requirement != null) _requirement = requirement;
    });
  }

  Future<void> _startUpdate(AppUpdateRequirement requirement) async {
    if (_updating) return;
    setState(() {
      _updating = true;
      _error = null;
    });
    final started = await _service.startRequiredUpdate(
      requirement.updateUrl,
      requirement.minimumVersionCode,
    );
    if (!mounted) return;
    setState(() {
      _updating = false;
      _updateStarted = started;
      if (!started) {
        _error = context.strings.isThai
            ? 'เริ่มดาวน์โหลดไม่ได้ กรุณาตรวจสอบว่า updateUrl เป็นลิงก์ HTTPS ไปยังไฟล์ APK โดยตรง'
            : 'Could not start the download. Check that updateUrl is a direct HTTPS APK link.';
      }
    });
  }

  void _retryCheck() {
    setState(() {
      _automaticUpdateStarted = false;
      _updateStarted = false;
      _error = null;
    });
    _checkForUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final requirement = _requirement;
    if (requirement == null) return widget.child;

    if (!_automaticUpdateStarted) {
      _automaticUpdateStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startUpdate(requirement);
      });
    }
    return _RequiredUpdateScreen(
      requirement: requirement,
      updating: _updating,
      updateStarted: _updateStarted,
      error: _error,
      onUpdate: () => _startUpdate(requirement),
      onRetryCheck: _retryCheck,
    );
  }
}

class _RequiredUpdateScreen extends StatelessWidget {
  const _RequiredUpdateScreen({
    required this.requirement,
    required this.updating,
    required this.updateStarted,
    required this.error,
    required this.onUpdate,
    required this.onRetryCheck,
  });

  final AppUpdateRequirement requirement;
  final bool updating;
  final bool updateStarted;
  final String? error;
  final VoidCallback onUpdate;
  final VoidCallback onRetryCheck;

  @override
  Widget build(BuildContext context) {
    final isThai = context.strings.isThai;
    final configuredMessage = isThai
        ? requirement.messageTh
        : requirement.messageEn;
    final latest = requirement.latestVersionName.isEmpty
        ? ''
        : (isThai
              ? 'เวอร์ชันล่าสุด ${requirement.latestVersionName}'
              : 'Latest version ${requirement.latestVersionName}');

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE7FFF4), Color(0xFFEAFBFF), Color(0xFFF7F4FF)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22305472),
                        blurRadius: 30,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.system_update_rounded,
                        size: 64,
                        color: Color(0xFF3268F6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isThai ? 'ต้องอัปเดตแอป' : 'App update required',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF10233F),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (updateStarted) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7F2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isThai
                                ? 'กำลังดาวน์โหลด APK เบื้องหลัง ดูความคืบหน้าได้จาก notification เมื่อโหลดเสร็จ Android จะเปิดหน้าติดตั้งให้ยืนยัน'
                                : 'The APK is downloading in the background. Follow progress in the notification; Android will ask you to confirm installation when it finishes.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF176B57),
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                      if (latest.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          latest,
                          style: const TextStyle(
                            color: Color(0xFF145CC8),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        configuredMessage ??
                            (isThai
                                ? 'มีเวอร์ชันใหม่ที่จำเป็นต่อการใช้งาน กรุณาอัปเดตก่อนเข้าแอป'
                                : 'A required version is available. Update before continuing.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF65748B),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: updating ? null : onUpdate,
                        icon: updating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(
                          updating
                              ? (isThai
                                    ? 'กำลังเริ่มดาวน์โหลด...'
                                    : 'Starting download...')
                              : updateStarted
                              ? (isThai
                                    ? 'ลองดาวน์โหลด/ติดตั้งอีกครั้ง'
                                    : 'Retry download/install')
                              : (isThai
                                    ? 'ดาวน์โหลดและอัปเดต'
                                    : 'Download and update'),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: const Color(0xFF3268F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: updating ? null : onRetryCheck,
                        child: Text(isThai ? 'ตรวจสอบอีกครั้ง' : 'Check again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _nonEmptyString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
