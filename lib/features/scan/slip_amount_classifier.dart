import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class PredictResult {
  PredictResult(this.index, this.confidence);

  final int index;
  final double confidence;
}

class AmountCandidateContext {
  const AmountCandidateContext({
    required this.value,
    required this.lineIndex,
    required this.lineText,
    required this.tokenText,
  });

  final double value;
  final int lineIndex;
  final String lineText;
  final String tokenText;
}

class AmountClassifier {
  AmountClassifier._();

  static final AmountClassifier instance = AmountClassifier._();

  static const _amountKeywordPattern =
      r'amount|total|paid|payment|bill|transfer|promptpay|qr|'
      r'à¸ˆà¸³à¸™à¸§à¸™à¹€à¸‡à¸´à¸™|à¸¢à¸­à¸”à¹€à¸‡à¸´à¸™|à¸ˆà¹ˆà¸²à¸¢à¸šà¸´à¸¥|'
      r'à¸ˆà¹ˆà¸²à¸¢|à¸Šà¸³à¸£à¸°|à¸£à¸§à¸¡';
  static const _referenceKeywordPattern =
      r'ref|reference|transaction|account|biller|merchant|invoice|order|'
      r'id|à¹€à¸¥à¸‚à¸—à¸µà¹ˆ|à¸­à¹‰à¸²à¸‡à¸­à¸´à¸‡|à¸šà¸±à¸à¸Šà¸µ|à¸£à¹‰à¸²à¸™à¸„à¹‰à¸²|à¸˜à¸¸à¸£à¸à¸£à¸£à¸¡';
  static const _feeKeywordPattern =
      r'fee|service charge|à¸„à¹ˆà¸²à¸˜à¸£à¸£à¸¡à¹€à¸™à¸µà¸¢à¸¡';
  static const _dateTimePattern =
      r'(\d{1,2}:\d{2})|(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})|(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4})';

  final List<String> _featureNames = [
    'bias',
    'hasBahtOnLine',
    'keywordOnLine',
    'keywordNearby',
    'lineLooksLikeAmount',
    'hasDecimals',
    'positionScore',
    'logValue',
    'penaltyReferenceLine',
    'penaltyFeeLine',
    'penaltyDateTimeLine',
  ];

  final Map<String, double> _weights = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('amount_classifier_weights');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final name in _featureNames) {
          final value = map[name];
          _weights[name] = (value is num)
              ? value.toDouble()
              : _defaultWeightFor(name);
        }
      } catch (_) {
        _resetWeightsToDefaults();
      }
    } else {
      _resetWeightsToDefaults();
    }

    _loaded = true;
  }

  void _resetWeightsToDefaults() {
    for (final name in _featureNames) {
      _weights[name] = _defaultWeightFor(name);
    }
  }

  double _defaultWeightFor(String name) {
    return switch (name) {
      'bias' => 0.0,
      'hasBahtOnLine' => 2.8,
      'keywordOnLine' => 4.2,
      'keywordNearby' => 2.1,
      'lineLooksLikeAmount' => 3.4,
      'hasDecimals' => 0.8,
      'positionScore' => 0.5,
      'logValue' => 0.15,
      'penaltyReferenceLine' => -5.2,
      'penaltyFeeLine' => -4.0,
      'penaltyDateTimeLine' => -6.0,
      _ => 0.0,
    };
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('amount_classifier_weights', jsonEncode(_weights));
  }

  List<AmountCandidateContext> extractCandidateContexts(
    String rawText, {
    List<String>? lines,
  }) {
    final normalizedLines =
        lines ??
        rawText
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    final contexts = <AmountCandidateContext>[];
    final numberPattern = RegExp(
      r'(?<!\d)(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?',
    );

    for (var lineIndex = 0; lineIndex < normalizedLines.length; lineIndex++) {
      final line = normalizedLines[lineIndex];
      for (final match in numberPattern.allMatches(line)) {
        final token = match.group(0);
        if (token == null) {
          continue;
        }

        final value = double.tryParse(token.replaceAll(',', ''));
        if (value == null || value <= 0 || value >= 10000000) {
          continue;
        }

        contexts.add(
          AmountCandidateContext(
            value: value,
            lineIndex: lineIndex,
            lineText: line,
            tokenText: token,
          ),
        );
      }
    }

    return contexts;
  }

  Map<String, double> _featuresForCandidate({
    required String rawText,
    required List<String> lines,
    required AmountCandidateContext context,
  }) {
    final lineLower = context.lineText.toLowerCase();
    final nearbyLower = [
      if (context.lineIndex > 0) lines[context.lineIndex - 1],
      context.lineText,
      if (context.lineIndex + 1 < lines.length) lines[context.lineIndex + 1],
    ].join(' ').toLowerCase();

    final hasBahtOnLine =
        RegExp(r'à¸šà¸²à¸—|baht|thb', caseSensitive: false).hasMatch(lineLower)
        ? 1.0
        : 0.0;
    final keywordOnLine =
        RegExp(_amountKeywordPattern, caseSensitive: false).hasMatch(lineLower)
        ? 1.0
        : 0.0;
    final keywordNearby =
        RegExp(
          _amountKeywordPattern,
          caseSensitive: false,
        ).hasMatch(nearbyLower)
        ? 1.0
        : 0.0;
    final lineLooksLikeAmount = _lineLooksLikeAmount(context.lineText)
        ? 1.0
        : 0.0;
    final hasDecimals = context.tokenText.contains('.') ? 1.0 : 0.0;
    final positionScore = lines.length <= 1
        ? 1.0
        : 1.0 - (context.lineIndex / (lines.length - 1));
    final logValue = context.value <= 1
        ? 0.0
        : math.log(context.value) / math.log(10);
    final penaltyReferenceLine =
        RegExp(
          _referenceKeywordPattern,
          caseSensitive: false,
        ).hasMatch(lineLower)
        ? 1.0
        : 0.0;
    final penaltyFeeLine =
        RegExp(_feeKeywordPattern, caseSensitive: false).hasMatch(lineLower)
        ? 1.0
        : 0.0;
    final penaltyDateTimeLine =
        RegExp(_dateTimePattern, caseSensitive: false).hasMatch(lineLower) ||
            _looksLikeDateToken(context.tokenText)
        ? 1.0
        : 0.0;

    return {
      'bias': 1.0,
      'hasBahtOnLine': hasBahtOnLine,
      'keywordOnLine': keywordOnLine,
      'keywordNearby': keywordNearby,
      'lineLooksLikeAmount': lineLooksLikeAmount,
      'hasDecimals': hasDecimals,
      'positionScore': positionScore,
      'logValue': logValue,
      'penaltyReferenceLine': penaltyReferenceLine,
      'penaltyFeeLine': penaltyFeeLine,
      'penaltyDateTimeLine': penaltyDateTimeLine,
    };
  }

  bool _lineLooksLikeAmount(String line) {
    final normalized = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    final stripped = normalized.replaceAll(
      RegExp(
        '$_amountKeywordPattern|à¸šà¸²à¸—|baht|thb|[0-9.,\\s:-]',
        caseSensitive: false,
      ),
      '',
    );
    return normalized.isNotEmpty && stripped.length <= 3;
  }

  bool _looksLikeDateToken(String token) {
    if (token.length != 4) {
      return false;
    }

    final year = int.tryParse(token);
    return year != null && year >= 1900 && year <= 2600;
  }

  double _dot(Map<String, double> features) {
    var score = 0.0;
    for (final entry in features.entries) {
      score += (_weights[entry.key] ?? 0.0) * entry.value;
    }
    return score;
  }

  PredictResult predict({
    required String rawText,
    required List<String> lines,
    required List<double> candidates,
  }) {
    final contexts = extractCandidateContexts(
      rawText,
      lines: lines,
    ).where((context) => candidates.contains(context.value)).toList();
    return predictFromContexts(
      rawText: rawText,
      lines: lines,
      contexts: contexts,
    );
  }

  PredictResult predictFromContexts({
    required String rawText,
    required List<String> lines,
    required List<AmountCandidateContext> contexts,
  }) {
    if (contexts.isEmpty) {
      return PredictResult(-1, 0.0);
    }

    final scores = <double>[];
    final featuresList = <Map<String, double>>[];
    for (final context in contexts) {
      final features = _featuresForCandidate(
        rawText: rawText,
        lines: lines,
        context: context,
      );
      featuresList.add(features);
      scores.add(_dot(features));
    }

    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final exps = scores.map((score) => math.exp(score - maxScore)).toList();
    final sumExp = exps.fold<double>(0.0, (sum, value) => sum + value);
    final probs = exps
        .map((value) => value / (sumExp == 0 ? 1.0 : sumExp))
        .toList();

    var bestIndex = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[bestIndex]) {
        bestIndex = i;
      }
    }

    return PredictResult(bestIndex, probs[bestIndex]);
  }

  Future<void> trainOnLabeledText({
    required String rawText,
    required List<String> lines,
    required List<double> candidates,
    required double expectedAmount,
    double learningRate = 0.5,
  }) async {
    final contexts = extractCandidateContexts(
      rawText,
      lines: lines,
    ).where((context) => candidates.contains(context.value)).toList();
    await trainOnLabeledContexts(
      rawText: rawText,
      lines: lines,
      contexts: contexts,
      expectedAmount: expectedAmount,
      learningRate: learningRate,
    );
  }

  Future<void> trainOnLabeledContexts({
    required String rawText,
    required List<String> lines,
    required List<AmountCandidateContext> contexts,
    required double expectedAmount,
    double learningRate = 0.5,
  }) async {
    await load();
    if (contexts.isEmpty) {
      return;
    }

    var bestIndex = -1;
    var bestDiff = double.infinity;
    for (var i = 0; i < contexts.length; i++) {
      final diff = (contexts[i].value - expectedAmount).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }
    if (bestIndex < 0) {
      return;
    }

    final featuresList = <Map<String, double>>[];
    final scores = <double>[];
    for (final context in contexts) {
      final features = _featuresForCandidate(
        rawText: rawText,
        lines: lines,
        context: context,
      );
      featuresList.add(features);
      scores.add(_dot(features));
    }

    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final exps = scores.map((score) => math.exp(score - maxScore)).toList();
    final sumExp = exps.fold<double>(0.0, (sum, value) => sum + value);
    final probs = exps
        .map((value) => value / (sumExp == 0 ? 1.0 : sumExp))
        .toList();

    for (final name in _featureNames) {
      var gradient = 0.0;
      for (var i = 0; i < featuresList.length; i++) {
        final expected = i == bestIndex ? 1.0 : 0.0;
        final featureValue = featuresList[i][name] ?? 0.0;
        gradient += (expected - probs[i]) * featureValue;
      }
      _weights[name] = (_weights[name] ?? 0.0) + learningRate * gradient;
    }

    await save();
  }

  List<double> extractCandidates(String rawText) {
    return extractCandidateContexts(
      rawText,
    ).map((context) => context.value).toList();
  }
}
