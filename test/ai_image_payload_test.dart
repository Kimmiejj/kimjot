import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:kimjot/features/scan/ai_image_payload.dart';

void main() {
  test('compresses a large album image into an AI-safe JPEG payload', () async {
    final source = image.Image(width: 700, height: 700);
    final random = Random(42);
    for (final pixel in source) {
      pixel
        ..r = random.nextInt(256)
        ..g = random.nextInt(256)
        ..b = random.nextInt(256);
    }

    final directory = await Directory.systemTemp.createTemp('kimjod-ai-image-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}slip.png');
    await file.writeAsBytes(image.encodePng(source));
    expect(await file.length(), greaterThan(500000));

    final payload = await prepareAiImagePayload(file.path, maxBytes: 500000);

    expect(payload, isNotNull);
    expect(payload!.mimeType, 'image/jpeg');
    expect(payload.bytes.length, lessThanOrEqualTo(500000));
    expect(image.decodeJpg(payload.bytes), isNotNull);
  });
}
