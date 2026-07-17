import 'package:flutter/services.dart';

class DeviceAudioBridge {
  DeviceAudioBridge._();

  static final DeviceAudioBridge instance = DeviceAudioBridge._();

  static const _channel = MethodChannel('kimjod/device_audio');

  Future<bool> startRecording() async {
    try {
      return await _channel.invokeMethod<bool>('startRecording') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      return await _channel.invokeMethod<String>('stopRecording');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
