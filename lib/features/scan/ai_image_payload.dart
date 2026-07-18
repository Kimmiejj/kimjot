import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const int _defaultMaxAiImageBytes = 2800 * 1024;

class AiImagePayload {
  const AiImagePayload({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

Future<AiImagePayload?> prepareAiImagePayload(
  String path, {
  int maxBytes = _defaultMaxAiImageBytes,
}) async {
  try {
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) return null;

    final mimeType = _detectImageMimeType(bytes);
    if (bytes.length <= maxBytes && mimeType != null) {
      return AiImagePayload(bytes: bytes, mimeType: mimeType);
    }

    return Isolate.run(() => _compressForAi(bytes, maxBytes));
  } catch (_) {
    return null;
  }
}

AiImagePayload? _compressForAi(Uint8List bytes, int maxBytes) {
  final source = image.decodeImage(bytes);
  if (source == null) return null;

  var decoded = image.bakeOrientation(source);
  const initialMaxDimension = 2400;
  final longestSide = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longestSide > initialMaxDimension) {
    decoded = decoded.width >= decoded.height
        ? image.copyResize(
            decoded,
            width: initialMaxDimension,
            interpolation: image.Interpolation.linear,
          )
        : image.copyResize(
            decoded,
            height: initialMaxDimension,
            interpolation: image.Interpolation.linear,
          );
  }

  Uint8List? smallest;
  for (final quality in const [88, 80, 72, 64]) {
    final encoded = image.encodeJpg(decoded, quality: quality);
    smallest = encoded;
    if (encoded.length <= maxBytes) {
      return AiImagePayload(bytes: encoded, mimeType: 'image/jpeg');
    }
  }

  while ((smallest?.length ?? maxBytes + 1) > maxBytes &&
      (decoded.width > 480 || decoded.height > 480)) {
    decoded = image.copyResize(
      decoded,
      width: (decoded.width * 0.8).round(),
      height: (decoded.height * 0.8).round(),
      interpolation: image.Interpolation.linear,
    );
    final encoded = image.encodeJpg(decoded, quality: 72);
    smallest = encoded;
    if (encoded.length <= maxBytes) {
      return AiImagePayload(bytes: encoded, mimeType: 'image/jpeg');
    }
  }

  if (smallest != null && smallest.length <= maxBytes) {
    return AiImagePayload(bytes: smallest, mimeType: 'image/jpeg');
  }
  return null;
}

String? _detectImageMimeType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
    final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
    if (brand.startsWith('hei') || brand.startsWith('mif')) {
      return 'image/heic';
    }
  }
  return null;
}
