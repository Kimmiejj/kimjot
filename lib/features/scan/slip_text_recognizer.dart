import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import 'external_ai_client.dart';
import 'slip_amount_classifier.dart';
import 'slip_scan_result.dart';
import 'slip_text_parser.dart';
import 'slip_transaction_resolver.dart';

class SlipTextRecognizer {
  SlipTextRecognizer({TextRecognizer? recognizer, SlipTextParser? parser})
    : _mlKitRecognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin),
      _parser = parser ?? SlipTextParser();

  static const OCRConfig _thaiOcrConfig = OCRConfig(language: 'tha+eng');

  final TextRecognizer _mlKitRecognizer;
  final SlipTextParser _parser;

  Future<SlipScanResult> scanImagePath(String imagePath) async {
    await AmountClassifier.instance.load();

    final rawTexts = <String>{};
    Object? firstError;

    try {
      final text = await TesseractOcr.extractText(
        imagePath,
        config: _thaiOcrConfig,
      );
      if (text.trim().isNotEmpty) {
        rawTexts.add(text);
      }
    } catch (error) {
      firstError ??= error;
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _mlKitRecognizer.processImage(inputImage);
      if (recognizedText.text.trim().isNotEmpty) {
        rawTexts.add(recognizedText.text);
      }
    } catch (error) {
      firstError ??= error;
    }

    if (rawTexts.isEmpty) {
      if (firstError != null) throw firstError;
      return _parser.parse('');
    }

    SlipScanResult? bestResult;
    var bestScore = -1;
    for (final rawText in rawTexts) {
      final result = await _parseWithSuggestions(rawText);
      final score = _scoreResult(result);
      if (score > bestScore) {
        bestScore = score;
        bestResult = result;
      }
    }

    return bestResult ?? _parser.parse(rawTexts.first);
  }

  Future<SlipScanResult> _parseWithSuggestions(String rawText) async {
    final localResult = _parser.parse(rawText);
    if (localResult.amount != null && localResult.amount! > 0) {
      return localResult;
    }

    final candidates = AmountClassifier.instance.extractCandidates(rawText);
    ExternalPrediction? ext;
    if (candidates.isNotEmpty) {
      ext = await ExternalAiClient.instance.analyzeAmounts(
        rawText: rawText,
        candidates: candidates,
      );
    }

    final chosenAmount = ext?.chosenAmount;
    final chosenConfidence = ext?.confidence;
    if (chosenAmount != null &&
        candidates.any((amount) => (amount - chosenAmount).abs() < 0.01) &&
        _externalAmountLooksSafe(rawText, chosenAmount)) {
      return _parser.parse(
        rawText,
        suggestedAmount: chosenAmount,
        suggestedConfidence: chosenConfidence,
      );
    }

    return _parser.parse(rawText);
  }

  bool _externalAmountLooksSafe(String rawText, double chosenAmount) {
    final text = SlipTextParser.repairThaiMojibake(rawText);
    final amountText = _amountTokenPattern(chosenAmount);
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    for (var i = 0; i < lines.length; i++) {
      if (!amountText.hasMatch(lines[i])) continue;
      final nearby = [
        if (i > 0) lines[i - 1],
        lines[i],
        if (i + 1 < lines.length) lines[i + 1],
      ].join(' ').toLowerCase();
      if (_hasAmountContext(nearby)) return true;
    }
    return false;
  }

  RegExp _amountTokenPattern(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final whole = amount.truncate().toString();
    return RegExp(
      r'(?<!\d)(?:' +
          RegExp.escape(fixed) +
          r'|' +
          RegExp.escape(whole) +
          r')(?!\d)',
    );
  }

  bool _hasAmountContext(String value) {
    return RegExp(
      r'amount|total|paid|payment|baht|thb|\u0E1A\u0E32\u0E17|'
      r'\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19|'
      r'\u0E08\u0E33\u0E19\u0E27\u0E19|'
      r'\u0E22\u0E2D\u0E14\u0E40\u0E07\u0E34\u0E19',
      caseSensitive: false,
    ).hasMatch(value);
  }

  int _scoreResult(SlipScanResult result) {
    final decision = resolveBestEffortSlipDecision(result);
    var score = 0;
    if (decision != null) score += 100;
    if (result.amount != null && result.amount! > 0) score += 40;
    if (result.reference?.isNotEmpty == true) score += 25;
    if (result.bankName?.isNotEmpty == true) score += 20;
    if (result.sender?.isNotEmpty == true) score += 15;
    if (result.recipient?.isNotEmpty == true) score += 15;
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(result.rawText)) score += 10;
    score += result.rawText.trim().length > 120 ? 5 : 0;
    return score;
  }

  Future<void> close() {
    return _mlKitRecognizer.close();
  }
}
