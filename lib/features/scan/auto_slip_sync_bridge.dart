import 'dart:async';

import 'package:flutter/services.dart';

class AutoSlipSyncBridge {
  AutoSlipSyncBridge._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'autoSyncOpenRequested') {
        _openRequests.add(null);
      }
    });
  }

  static final instance = AutoSlipSyncBridge._();
  static const _channel = MethodChannel('kimjod/gallery_permission');
  final _openRequests = StreamController<void>.broadcast();

  Stream<void> get openRequests => _openRequests.stream;

  Future<List<String>> scanNow() async {
    try {
      final paths = await _channel.invokeMethod<List<dynamic>>(
        'scanAutoSyncFolderNow',
      );
      return (paths ?? const []).whereType<String>().toList(growable: false);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<bool> takeOpenRequest() async {
    try {
      return await _channel.invokeMethod<bool>('takeAutoSyncOpenRequest') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> acknowledge(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('acknowledgeAutoSyncImages', {
        'paths': paths,
      });
    } on MissingPluginException {
      // Auto sync is Android-only.
    } on PlatformException {
      // Keep the background job; stale native paths will be cleaned later.
    }
  }
}
