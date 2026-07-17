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
      r'จำนวนเงิน|ยอดเงิน|จ่ายบิล|จำนวน|จ่าย|ชำระ|รวม|บาท';
  static const _referenceKeywordPattern =
      r'ref|reference|transaction|account|biller|merchant|invoice|order|'
      r'id|เลขที่|อ้างอิง|บัญชี|ร้านค้า|ธุรกรรม|biller id|merchant id';
  static const _feeKeywordPattern = r'fee|service charge|ค่าธรรมเนียม';
  static const _thaiAmountKeywordPattern =
      r'\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19|'
      r'\u0E22\u0E2D\u0E14\u0E40\u0E07\u0E34\u0E19|'
      r'\u0E08\u0E48\u0E32\u0E22\u0E1A\u0E34\u0E25|'
      r'\u0E08\u0E33\u0E19\u0E27\u0E19|'
      r'\u0E08\u0E48\u0E32\u0E22|'
      r'\u0E0A\u0E33\u0E23\u0E30|'
      r'\u0E23\u0E27\u0E21|'
      r'\u0E1A\u0E32\u0E17';
  static const _thaiReferenceKeywordPattern =
      r'\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48|'
      r'\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07|'
      r'\u0E1A\u0E31\u0E0D\u0E0A\u0E35|'
      r'\u0E23\u0E49\u0E32\u0E19\u0E04\u0E49\u0E32|'
      r'\u0E18\u0E38\u0E23\u0E01\u0E23\u0E23\u0E21';
  static const _thaiFeeKeywordPattern =
      r'\u0E04\u0E48\u0E32\u0E18\u0E23\u0E23\u0E21\u0E40\u0E19\u0E35\u0E22\u0E21';
  static const _dateTimePattern =
      r'(\d{1,2}:\d{2})|(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})|(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4})|(\d{1,2}\s+[\u0E00-\u0E7F.]{2,20}\s+\d{2,4})';

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

        if (_shouldSkipCandidate(
          line: line,
          previousLine: lineIndex > 0 ? normalizedLines[lineIndex - 1] : null,
          nextLine: lineIndex + 1 < normalizedLines.length
              ? normalizedLines[lineIndex + 1]
              : null,
          match: match,
          token: token,
          value: value,
        )) {
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

  bool _shouldSkipCandidate({
    required String line,
    required String? previousLine,
    required String? nextLine,
    required RegExpMatch match,
    required String token,
    required double value,
  }) {
    final lower = line.toLowerCase();
    final previousLower = previousLine?.toLowerCase();
    final nextLower = nextLine?.toLowerCase();
    final hasAmountHint = _hasAmountHint(lower);

    if (_looksLikeBareSmallNoise(line: lower, token: token, value: value)) {
      return true;
    }
    if (_hasNegativeSignBefore(line, match.start) ||
        _hasAdjustmentHint(lower) ||
        (previousLower != null && _hasAdjustmentHint(previousLower))) {
      return true;
    }
    if (_hasFeeHint(lower) ||
        (previousLower != null && _hasFeeHint(previousLower))) {
      return true;
    }
    if (!hasAmountHint && _looksLikeDateToken(token)) {
      return true;
    }
    if (_isEmbeddedInIdentifier(line, match.start, match.end) ||
        _isMaskedAccountToken(line, match.start, match.end)) {
      return true;
    }
    if (!hasAmountHint &&
        _looksLikeAccountSuffixContext(
          line: line,
          token: token,
          previousLine: previousLower,
          nextLine: nextLower,
        )) {
      return true;
    }
    if (!hasAmountHint && _looksLikeNonAmountMixedText(line, token)) {
      return true;
    }
    if (!hasAmountHint &&
        RegExp(_dateTimePattern, caseSensitive: false).hasMatch(lower)) {
      return true;
    }
    if (!hasAmountHint && _lineLooksLikeReferenceOrAccount(lower)) {
      return true;
    }
    return false;
  }

  bool _looksLikeBareSmallNoise({
    required String line,
    required String token,
    required double value,
  }) {
    if (value >= 10 || token.contains('.')) {
      return false;
    }
    return !_hasCurrencyHint(line);
  }

  bool _hasFeeHint(String lowerLine) {
    return RegExp(
      '$_feeKeywordPattern|$_thaiFeeKeywordPattern',
      caseSensitive: false,
    ).hasMatch(lowerLine);
  }

  bool _hasAdjustmentHint(String lowerLine) {
    return RegExp(
      r'discount|subsidy|benefit|privilege|coupon|cashback|rebate|'
      r'\u0E2A\u0E48\u0E27\u0E19\u0E25\u0E14|'
      r'\u0E2A\u0E34\u0E17\u0E18\u0E34|'
      r'\u0E04\u0E39\u0E1B\u0E2D\u0E07|'
      r'\u0E40\u0E07\u0E34\u0E19\u0E04\u0E37\u0E19|'
      r'\u0E23\u0E32\u0E22\u0E01\u0E32\u0E23\u0E1F\u0E23\u0E35',
      caseSensitive: false,
    ).hasMatch(lowerLine);
  }

  bool _hasNegativeSignBefore(String line, int start) {
    if (start <= 0) return false;
    return RegExp(
      r'[\-\u2212\u2013\u2014]\s*$',
    ).hasMatch(line.substring(0, start));
  }

  bool _hasCurrencyHint(String lowerLine) {
    return RegExp(
      r'฿|baht|thb|à¸šà¸²à¸—|\u0E1A\u0E32\u0E17',
      caseSensitive: false,
    ).hasMatch(lowerLine);
  }

  bool _hasAmountHint(String lowerLine) {
    final normalized = _normalizedKeywordText(lowerLine);
    if (RegExp(
      r'amount|total|paid|payment|baht|thb|'
      '$_thaiAmountKeywordPattern',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return true;
    }
    return RegExp(
      r'amount|total|paid|payment|baht|thb|'
      '$_thaiAmountKeywordPattern',
      caseSensitive: false,
    ).hasMatch(lowerLine);
  }

  String _normalizedKeywordText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\u200B]+'), '')
        .replaceAll('\u0E4D\u0E32', '\u0E33');
  }

  bool _lineLooksLikeReferenceOrAccount(String lowerLine) {
    if (RegExp(
      '$_referenceKeywordPattern|$_thaiReferenceKeywordPattern',
      caseSensitive: false,
    ).hasMatch(lowerLine)) {
      return true;
    }
    if (lowerLine.contains('\u0E2B\u0E21\u0E32\u0E22\u0E40\u0E25\u0E02') ||
        lowerLine.contains('\u0E25\u0E39\u0E01\u0E04\u0E49\u0E32')) {
      return true;
    }

    final compact = lowerLine.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) {
      return false;
    }

    return RegExp(r'^(?:x+|\*+|[\u2022]+)?[-x*\u2022\d]+$').hasMatch(compact) ||
        RegExp(
          r'(?:x{1,3}|\*)[-x*\d]{2,}',
          caseSensitive: false,
        ).hasMatch(compact) ||
        RegExp(r'^(?=.*[a-z])(?=.*\d)[a-z0-9\-]{8,}$').hasMatch(compact);
  }

  bool _looksLikeNonAmountMixedText(String line, String token) {
    if (token.contains('.') || _hasCurrencyHint(line.toLowerCase())) {
      return false;
    }
    if (_lineLooksLikeAmount(line)) return false;
    final letters = RegExp(r'[A-Za-z\u0E00-\u0E7F]').allMatches(line).length;
    return letters >= 2;
  }

  bool _looksLikeAccountSuffixContext({
    required String line,
    required String token,
    required String? previousLine,
    required String? nextLine,
  }) {
    if (token.contains('.') || token.length < 4 || token.length > 6) {
      return false;
    }
    if (!_lineLooksLikeReferenceOrAccount(line.toLowerCase())) return false;
    if (previousLine != null && _hasAmountHint(previousLine)) return false;
    final previousLooksLikeParty =
        previousLine != null &&
        RegExp(r'[A-Za-z\u0E00-\u0E7F]').hasMatch(previousLine) &&
        !_hasAmountHint(previousLine);
    final nextIsAmountLabel = nextLine != null && _hasAmountHint(nextLine);
    return previousLooksLikeParty || nextIsAmountLabel;
  }

  bool _isEmbeddedInIdentifier(String line, int start, int end) {
    if (_hasTouchingCurrencyHint(line, start, end)) {
      return false;
    }
    final before = start > 0 ? line.codeUnitAt(start - 1) : null;
    final after = end < line.length ? line.codeUnitAt(end) : null;
    return _isIdentifierLetter(before) || _isIdentifierLetter(after);
  }

  bool _hasTouchingCurrencyHint(String line, int start, int end) {
    final beforeStart = start - 4 < 0 ? 0 : start - 4;
    final afterEnd = end + 4 > line.length ? line.length : end + 4;
    final before = line.substring(beforeStart, start).toLowerCase();
    final after = line.substring(end, afterEnd).toLowerCase();
    return before.endsWith('thb') ||
        after.startsWith('thb') ||
        after.startsWith('\u0E1A\u0E32\u0E17');
  }

  bool _isIdentifierLetter(int? codeUnit) {
    if (codeUnit == null) {
      return false;
    }
    return codeUnit >= 0x41 && codeUnit <= 0x5A ||
        codeUnit >= 0x61 && codeUnit <= 0x7A ||
        codeUnit >= 0x0E00 && codeUnit <= 0x0E7F;
  }

  bool _isMaskedAccountToken(String line, int start, int end) {
    final leftStart = start - 8 < 0 ? 0 : start - 8;
    final rightEnd = end + 4 > line.length ? line.length : end + 4;
    final left = line.substring(leftStart, start);
    final right = line.substring(end, rightEnd);
    return RegExp(r'[xX*\u2022]\s*[-\s]*$').hasMatch(left) ||
        RegExp(r'^[-\s]*[xX*\u2022]').hasMatch(right);
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
        RegExp(r'บาท|baht|thb', caseSensitive: false).hasMatch(lineLower)
        ? 1.0
        : 0.0;
    final keywordOnLine =
        RegExp(
          '$_amountKeywordPattern|$_thaiAmountKeywordPattern',
          caseSensitive: false,
        ).hasMatch(lineLower)
        ? 1.0
        : 0.0;
    final keywordNearby =
        RegExp(
          '$_amountKeywordPattern|$_thaiAmountKeywordPattern',
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
          '$_referenceKeywordPattern|$_thaiReferenceKeywordPattern',
          caseSensitive: false,
        ).hasMatch(lineLower)
        ? 1.0
        : 0.0;
    final penaltyFeeLine =
        RegExp(
          '$_feeKeywordPattern|$_thaiFeeKeywordPattern',
          caseSensitive: false,
        ).hasMatch(lineLower)
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
    var stripped = normalized.replaceAll(
      RegExp(
        '$_amountKeywordPattern|บาท|baht|thb|[0-9.,\\s:-]',
        caseSensitive: false,
      ),
      '',
    );
    stripped = stripped.replaceAll(
      RegExp(_thaiAmountKeywordPattern, caseSensitive: false),
      '',
    );
    stripped = _normalizedKeywordText(
      stripped,
    ).replaceAll(RegExp(_thaiAmountKeywordPattern, caseSensitive: false), '');
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
