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
        final layoutAmount = _detectAmountFromMlKitLayout(recognizedText);
        rawTexts.add(
          layoutAmount == null
              ? recognizedText.text
              : '${recognizedText.text}\n\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19\n${layoutAmount.toStringAsFixed(2)}',
        );
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

  double? _detectAmountFromMlKitLayout(RecognizedText recognizedText) {
    final lines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      lines.addAll(block.lines.where((line) => line.text.trim().isNotEmpty));
    }
    if (lines.isEmpty) return null;

    for (final labelLine in lines) {
      if (!_looksLikeAmountLabel(labelLine.text)) continue;

      final candidates = <({double amount, int score})>[];
      for (final line in lines) {
        final amount = _amountFromTextLine(line.text);
        if (amount == null) continue;

        final sameBand =
            (line.boundingBox.center.dy - labelLine.boundingBox.center.dy)
                .abs() <=
            48;
        final nearBelow =
            line.boundingBox.top >= labelLine.boundingBox.top &&
            line.boundingBox.top <= labelLine.boundingBox.bottom + 96;
        if (!sameBand && !nearBelow) continue;

        var score = 0;
        if (sameBand) score += 40;
        if (line.boundingBox.left >= labelLine.boundingBox.right - 16) {
          score += 32;
        }
        if (line.text.contains('.')) score += 16;
        score -= (line.boundingBox.center.dy - labelLine.boundingBox.center.dy)
            .abs()
            .round();
        candidates.add((amount: amount, score: score));
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.score.compareTo(a.score));
        return candidates.first.amount;
      }
    }
    return null;
  }

  bool _looksLikeAmountLabel(String text) {
    final normalized = SlipTextParser.repairThaiMojibake(text)
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\u200B]+'), '')
        .replaceAll('\u0E4D\u0E32', '\u0E33');
    return RegExp(
      r'amount|total|paid|payment|'
      r'\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19|'
      r'\u0E08\u0E33\u0E19\u0E27\u0E19|'
      r'\u0E22\u0E2D\u0E14\u0E40\u0E07\u0E34\u0E19',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  double? _amountFromTextLine(String text) {
    if (_looksLikeAccountOrMetadataLine(text)) return null;
    final match = RegExp(
      r'(?<![\dA-Za-z])(\d{1,3}(?:,\d{3})+|\d+)\.(\d{2})(?![\dA-Za-z])',
    ).firstMatch(text);
    if (match == null) return null;
    final amount = double.tryParse(match.group(0)!.replaceAll(',', ''));
    if (amount == null || amount <= 0 || amount >= 10000000) return null;
    return amount;
  }

  bool _looksLikeAccountOrMetadataLine(String text) {
    final repaired = SlipTextParser.repairThaiMojibake(text).toLowerCase();
    final compact = repaired.replaceAll(RegExp(r'\s+'), '');
    return repaired.contains('reference') ||
        repaired.contains('transaction') ||
        repaired.contains('account') ||
        repaired.contains('biller') ||
        repaired.contains('merchant') ||
        repaired.contains('id') ||
        repaired.contains('\u0E1A\u0E31\u0E0D\u0E0A\u0E35') ||
        repaired.contains('\u0E23\u0E2B\u0E31\u0E2A') ||
        RegExp(r'^(?:x+|\*+|[\u2022]+)?[-x*\u2022\d]+$').hasMatch(compact);
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
      r'(?<![\dA-Za-zxX*\u2022-])(?:' +
          RegExp.escape(fixed) +
          r'|' +
          RegExp.escape(whole) +
          r')(?![\dA-Za-zxX*\u2022-])',
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
    if (result.amount != null &&
        _externalAmountLooksSafe(result.rawText, result.amount!)) {
      score += 60;
    }
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
