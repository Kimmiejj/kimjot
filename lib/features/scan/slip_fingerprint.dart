import 'dart:io';

import 'slip_scan_result.dart';

Future<String> buildSlipFingerprint({
  required String imagePath,
  required SlipScanResult result,
}) async {
  final reference = _normalized(result.reference);
  if (reference != null) {
    return 'ref:$reference';
  }

  final ocrParts =
      [
            result.bankName,
            result.amount?.toStringAsFixed(2),
            result.dateText,
            result.timeText,
            result.recipient,
            result.sender,
          ]
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty);
  final ocrKey = ocrParts.join('|');
  if (ocrKey.isNotEmpty) {
    return 'ocr:${_hashText(ocrKey.toLowerCase())}';
  }

  final file = File(imagePath);
  final stat = await file.stat();
  final fileName = imagePath.split(RegExp(r'[\\/]')).last.toLowerCase();
  return 'file:${_hashText('$fileName|${stat.size}')}';
}

String? _normalized(String? value) {
  final normalized = value
      ?.replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toUpperCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

String _hashText(String value) {
  var hash = 0x811C9DC5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  return hash.toRadixString(16).padLeft(8, '0');
}
