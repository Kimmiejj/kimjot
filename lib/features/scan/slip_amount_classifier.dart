import 'dart:convert';
// math is needed for log10 calculation
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// Prediction result with chosen index and confidence (0..1)
class PredictResult {
  PredictResult(this.index, this.confidence);
  final int index;
  final double confidence;
}

/// A very small perceptron-style scorer for choosing the correct amount among
/// candidate numeric values extracted from OCR text.
///
/// It computes a small set of features for each candidate and learns a
/// weight vector via a simple perceptron update. We persist weights using
/// SharedPreferences so training is local to the device.
class AmountClassifier {
  AmountClassifier._();

  static final AmountClassifier instance = AmountClassifier._();

  // weight names used in features
  final List<String> _featureNames = [
    'bias',
    'hasBaht',
    'nearAmountKeyword',
    'positionScore',
    'logValue',
  ];

  final Map<String, double> _weights = {};

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('amount_classifier_weights');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final name in _featureNames) {
          final v = map[name];
          _weights[name] = (v is num) ? v.toDouble() : 0.0;
        }
      } catch (_) {
        for (final name in _featureNames) {
          _weights[name] = 0.0;
        }
      }
    } else {
      for (final name in _featureNames) {
        _weights[name] = 0.0;
      }
    }
    _loaded = true;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('amount_classifier_weights', jsonEncode(_weights));
  }

  Map<String, double> _featuresForCandidate({
    required String rawText,
    required List<String> lines,
    required double value,
    required int candidateIndex,
  }) {
    final lower = rawText.toLowerCase();

    // has currency word near candidate value? (baht, บาท, thb)
    final hasBaht = RegExp(r'บาท|baht|thb').hasMatch(lower) ? 1.0 : 0.0;

    // near keywords like 'amount', 'total', 'จำนวนเงิน', 'pay' etc.
    final nearAmountKeyword =
        RegExp(
          r'amount|total|จำนวนเงิน|ยอดเงิน|toTal|payment|จ่าย|ชำระ|จำนวนเงินที่ชำระ',
          caseSensitive: false,
        ).hasMatch(lower)
        ? 1.0
        : 0.0;

    // position score: attempt to estimate how near to bottom/top the value is by candidateIndex
    final posScore = 1.0 - (candidateIndex / (lines.length + 1));

    // magnitude feature (log10 scale)
    final logValue = value > 0
        ? (value <= 1 ? 0.0 : (math.log(value) / math.log(10)))
        : 0.0;

    return {
      'bias': 1.0,
      'hasBaht': hasBaht,
      'nearAmountKeyword': nearAmountKeyword,
      'positionScore': posScore,
      'logValue': logValue,
    };
  }

  double _dot(Map<String, double> features) {
    var s = 0.0;
    for (final e in features.entries) {
      s += (_weights[e.key] ?? 0.0) * e.value;
    }
    return s;
  }

  /// Predict the best candidate and return a confidence score (softmax probability).
  PredictResult predict({
    required String rawText,
    required List<String> lines,
    required List<double> candidates,
  }) {
    if (candidates.isEmpty) return PredictResult(-1, 0.0);
    final scores = <double>[];
    final featuresList = <Map<String, double>>[];
    for (var i = 0; i < candidates.length; i++) {
      final f = _featuresForCandidate(
        rawText: rawText,
        lines: lines,
        value: candidates[i],
        candidateIndex: i,
      );
      featuresList.add(f);
      scores.add(_dot(f));
    }

    // softmax
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final exps = scores.map((s) => math.exp(s - maxScore)).toList();
    final sumExp = exps.fold<double>(0.0, (p, e) => p + e);
    final probs = exps.map((e) => e / (sumExp == 0 ? 1 : sumExp)).toList();
    var best = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[best]) best = i;
    }
    return PredictResult(best, probs[best]);
  }

  /// Train using raw OCR text and the expected amount value. We find the
  /// candidate that best matches the expected amount (closest numeric) and
  /// run a perceptron-style update so the true candidate's features are
  /// reinforced and the predicted candidate's features are penalized.
  Future<void> trainOnLabeledText({
    required String rawText,
    required List<String> lines,
    required List<double> candidates,
    required double expectedAmount,
    double learningRate = 0.5,
  }) async {
    await load();
    if (candidates.isEmpty) return;

    // find index of candidate closest to expectedAmount
    var bestIdx = -1;
    var bestDiff = double.infinity;
    for (var i = 0; i < candidates.length; i++) {
      final d = (candidates[i] - expectedAmount).abs();
      if (d < bestDiff) {
        bestDiff = d;
        bestIdx = i;
      }
    }
    if (bestIdx < 0) return;

    // Build features and current probabilities for candidates
    final featuresList = <Map<String, double>>[];
    final scores = <double>[];
    for (var i = 0; i < candidates.length; i++) {
      final f = _featuresForCandidate(
        rawText: rawText,
        lines: lines,
        value: candidates[i],
        candidateIndex: i,
      );
      featuresList.add(f);
      scores.add(_dot(f));
    }

    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final exps = scores.map((s) => math.exp(s - maxScore)).toList();
    final sumExp = exps.fold<double>(0.0, (p, e) => p + e);
    final probs = exps.map((e) => e / (sumExp == 0 ? 1 : sumExp)).toList();

    // update weights with gradient of cross-entropy: w += lr * sum_i (y_i - p_i) * feat_i
    for (final name in _featureNames) {
      var grad = 0.0;
      for (var i = 0; i < featuresList.length; i++) {
        final y = (i == bestIdx) ? 1.0 : 0.0;
        final featVal = featuresList[i][name] ?? 0.0;
        grad += (y - probs[i]) * featVal;
      }
      _weights[name] = (_weights[name] ?? 0.0) + learningRate * grad;
    }

    await save();
  }

  /// Utility: create candidate features by scanning raw text for numeric tokens.
  /// This is a helper used by the parser; kept here to avoid duplication.
  List<double> extractCandidates(String rawText) {
    final matches = RegExp(r'(?<!\d)(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?')
        .allMatches(rawText)
        .map((m) => m.group(0))
        .whereType<String>()
        .map((s) => double.tryParse(s.replaceAll(',', '')))
        .whereType<double>()
        .where((v) => v > 0 && v < 10000000)
        .toList();
    return matches;
  }
}
