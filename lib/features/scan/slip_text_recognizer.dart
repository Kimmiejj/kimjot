import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'slip_scan_result.dart';
import 'slip_text_parser.dart';
import 'slip_amount_classifier.dart';
import 'external_ai_client.dart';

class SlipTextRecognizer {
  SlipTextRecognizer({TextRecognizer? recognizer, SlipTextParser? parser})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin),
      _parser = parser ?? SlipTextParser();

  final TextRecognizer _recognizer;
  final SlipTextParser _parser;

  Future<SlipScanResult> scanImagePath(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);
    // Ensure classifier weights are loaded before parsing so prediction is available.
    await AmountClassifier.instance.load();

    // Extract numeric candidates and try external AI if configured
    final candidates = AmountClassifier.instance.extractCandidates(
      recognizedText.text,
    );
    ExternalPrediction? ext;
    if (candidates.isNotEmpty) {
      ext = await ExternalAiClient.instance.analyzeAmounts(
        rawText: recognizedText.text,
        candidates: candidates,
      );
    }

    // If external AI returned a chosenAmount, pass it as suggestion to parser.
    if (ext != null && ext.chosenAmount != null) {
      return _parser.parse(
        recognizedText.text,
        suggestedAmount: ext.chosenAmount,
        suggestedConfidence: ext.confidence,
      );
    }

    return _parser.parse(recognizedText.text);
  }

  Future<void> close() {
    return _recognizer.close();
  }
}
