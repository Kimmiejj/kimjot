import 'dart:convert';

import 'slip_amount_classifier.dart';
import 'slip_scan_result.dart';

class SlipTextParser {
  double? _lastAmountConfidence;

  SlipScanResult parse(
    String rawText, {
    double? suggestedAmount,
    double? suggestedConfidence,
  }) {
    final text = repairThaiMojibake(rawText);
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final parties = _detectParties(lines);
    final amount = suggestedAmount ?? _detectAmount(lines);
    final result = SlipScanResult(
      rawText: text,
      bankName: _detectBank(lines.join('\n')),
      amount: amount,
      dateText: _detectDate(text),
      timeText: RegExp(r'\d{1,2}:\d{2}(?::\d{2})?').firstMatch(text)?.group(0),
      sender: parties?.sender,
      recipient: parties?.recipient,
      reference: _detectReference(lines),
      category: _detectCategory(text, amount, parties),
      amountConfidence: suggestedAmount == null
          ? _lastAmountConfidence
          : suggestedConfidence,
    );
    _lastAmountConfidence = null;
    return result;
  }

  static String repairThaiMojibake(String text) {
    final candidates = <String>{
      text,
      _decodeLatin1Utf8(text),
      _decodeLatin1Utf8(_decodeLatin1Utf8(text)),
      _decodeWindows1252Utf8(text),
      _decodeWindows1252Utf8(_decodeWindows1252Utf8(text)),
      _decodeTis620(text),
    }..removeWhere((value) => value.isEmpty);
    if (candidates.isEmpty) return '';
    return candidates.reduce(
      (best, current) =>
          _textScore(current) > _textScore(best) ? current : best,
    );
  }

  static bool looksUnreadable(String text) {
    final repaired = repairThaiMojibake(text).trim();
    if (repaired.isEmpty) return true;
    final hasThai = RegExp(r'[\u0E00-\u0E7F]').hasMatch(repaired);
    final hasAsciiWord = RegExp(r'[A-Za-z]{2,}').hasMatch(repaired);
    final suspiciousLatin = RegExp(r'[\u00C0-\u00FF]').hasMatch(repaired);
    return suspiciousLatin && !hasThai && !hasAsciiWord;
  }

  static String _decodeLatin1Utf8(String text) {
    try {
      return utf8.decode(latin1.encode(text), allowMalformed: true);
    } catch (_) {
      return text;
    }
  }

  static String _decodeWindows1252Utf8(String text) {
    try {
      return utf8.decode(_windows1252Encode(text), allowMalformed: true);
    } catch (_) {
      return text;
    }
  }

  static List<int> _windows1252Encode(String text) {
    return text.runes.map((unit) {
      if (unit <= 0xFF) return unit;
      return _windows1252ExtraBytes[unit] ?? unit;
    }).toList();
  }

  static const _windows1252ExtraBytes = <int, int>{
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  static String _decodeTis620(String text) {
    final units = text.codeUnits;
    if (units.any((unit) => unit > 0xFF)) return text;
    final buffer = StringBuffer();
    for (final unit in units) {
      if (unit < 0x80) {
        buffer.writeCharCode(unit);
      } else if (unit >= 0xA1 && unit <= 0xDA) {
        buffer.writeCharCode(0x0E01 + (unit - 0xA1));
      } else if (unit == 0xDF) {
        buffer.writeCharCode(0x0E3F);
      } else if (unit >= 0xE0 && unit <= 0xFB) {
        buffer.writeCharCode(0x0E40 + (unit - 0xE0));
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  static int _textScore(String text) {
    var score = 0;
    for (final unit in text.codeUnits) {
      if (unit >= 0x0E00 && unit <= 0x0E7F) {
        score += 5;
      } else if ((unit >= 0x30 && unit <= 0x39) ||
          (unit >= 0x41 && unit <= 0x5A) ||
          (unit >= 0x61 && unit <= 0x7A)) {
        score += 1;
      } else if (unit == 0x20 ||
          unit == 0x2D ||
          unit == 0x2E ||
          unit == 0x2F ||
          unit == 0x3A) {
        score += 1;
      } else if (unit >= 0xC0 && unit <= 0xFF) {
        score -= 3;
      } else if (unit == 0xFFFD) {
        score -= 5;
      }
    }
    return score;
  }

  double? _detectAmount(List<String> lines) {
    final explicitAmount = _detectAmountFromExplicitAmountText(lines);
    if (explicitAmount != null) {
      _lastAmountConfidence = 1;
      return explicitAmount;
    }

    final labeledAmount = _detectAmountNearLabel(lines);
    if (labeledAmount != null) {
      _lastAmountConfidence = 1;
      return labeledAmount;
    }

    final contexts = AmountClassifier.instance.extractCandidateContexts(
      lines.join('\n'),
      lines: lines,
    );
    if (contexts.isEmpty) return null;
    if (contexts.length == 1) {
      _lastAmountConfidence = 1;
      return contexts.first.value;
    }
    try {
      final prediction = AmountClassifier.instance.predictFromContexts(
        rawText: lines.join('\n'),
        lines: lines,
        contexts: contexts,
      );
      if (prediction.index >= 0 && prediction.index < contexts.length) {
        _lastAmountConfidence = prediction.confidence;
        return contexts[prediction.index].value;
      }
    } catch (_) {}
    _lastAmountConfidence = 0;
    return contexts.first.value;
  }

  double? _detectAmountFromExplicitAmountText(List<String> lines) {
    final candidates = <({double value, int score})>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!_hasStrictAmountLabel(line) && !_hasStrictCurrencyHint(line)) {
        continue;
      }

      final start = _hasStrictAmountLabel(line) || i == 0 ? i : i - 1;
      final rawEnd = _hasStrictAmountLabel(line) ? i + 4 : i + 1;
      final end = rawEnd >= lines.length ? lines.length - 1 : rawEnd;

      for (var j = start; j <= end; j++) {
        if (j != i && _isStrictNonAmountMetadata(lines[j])) continue;
        for (final candidate in _strictAmountCandidatesFromLine(lines[j])) {
          candidates.add((
            value: candidate.value,
            score: _strictAmountScore(
              line: lines[j],
              previousLine: j > 0 ? lines[j - 1] : null,
              nextLine: j + 1 < lines.length ? lines[j + 1] : null,
              anchorLine: line,
              token: candidate.token,
              value: candidate.value,
              lineDistance: (j - i).abs(),
            ),
          ));
        }
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.value;
  }

  List<({String token, double value})> _strictAmountCandidatesFromLine(
    String line,
  ) {
    final numberPattern = RegExp(
      r'(?<![\dA-Za-z])(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?(?![A-Za-z])',
    );
    final candidates = <({String token, double value})>[];
    for (final match in numberPattern.allMatches(line)) {
      final token = match.group(0);
      if (token == null || _looksLikeDateToken(token)) continue;
      final value = double.tryParse(token.replaceAll(',', ''));
      if (value == null || value <= 0 || value >= 10000000) continue;
      candidates.add((token: token, value: value));
    }
    return candidates;
  }

  int _strictAmountScore({
    required String line,
    required String? previousLine,
    required String? nextLine,
    required String anchorLine,
    required String token,
    required double value,
    required int lineDistance,
  }) {
    var score = 0;
    if (_hasStrictAmountLabel(line)) score += 40;
    if (_hasStrictAmountLabel(anchorLine)) score += 30;
    if (_hasStrictCurrencyHint(line)) score += 40;
    if (nextLine != null && _hasStrictCurrencyHint(nextLine)) score += 24;
    if (previousLine != null && _hasStrictCurrencyHint(previousLine)) {
      score += 16;
    }
    if (_hasStrictFeeLabel(line)) score -= 160;
    if (previousLine != null && _hasStrictFeeLabel(previousLine)) {
      score -= 90;
    }
    if (nextLine != null && _hasStrictFeeLabel(nextLine)) score -= 24;
    if (token.contains('.')) score += 12;
    if (_strictLineLooksLikeAmountValue(line)) score += 8;
    if (value >= 10) score += 4;
    if (value >= 100) score += 2;
    if (_isStrictNonAmountMetadata(line)) score -= 120;
    score -= lineDistance * 6;
    return score;
  }

  bool _hasStrictAmountLabel(String value) {
    return RegExp(
      r'amount|total|paid|payment|'
      r'\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19|'
      r'\u0E08\u0E33\u0E19\u0E27\u0E19|'
      r'\u0E22\u0E2D\u0E14\u0E40\u0E07\u0E34\u0E19|'
      r'à¸ˆà¸³à¸™à¸§à¸™à¹€à¸‡à¸´à¸™|'
      r'à¸ˆà¸³à¸™à¸§à¸™|'
      r'à¸¢à¸­à¸”à¹€à¸‡à¸´à¸™',
      caseSensitive: false,
    ).hasMatch(value);
  }

  bool _hasStrictCurrencyHint(String value) {
    return RegExp(
      r'\u0E3F|\u0E1A\u0E32\u0E17|baht|thb|'
      r'à¸¿|à¸šà¸²à¸—|Ã Â¸Å¡Ã Â¸Â²Ã Â¸â€”',
      caseSensitive: false,
    ).hasMatch(value);
  }

  bool _hasStrictFeeLabel(String value) {
    final repaired = repairThaiMojibake(value);
    return RegExp(
      r'fee|fees|charge|commission|'
      r'\u0E04\u0E48\u0E32\u0E18\u0E23\u0E23\u0E21\u0E40\u0E19\u0E35\u0E22\u0E21',
      caseSensitive: false,
    ).hasMatch(repaired);
  }

  bool _strictLineLooksLikeAmountValue(String line) {
    final stripped = line
        .replaceAll(
          RegExp(
            r'amount|total|paid|payment|'
            r'\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19|'
            r'\u0E08\u0E33\u0E19\u0E27\u0E19|'
            r'\u0E22\u0E2D\u0E14\u0E40\u0E07\u0E34\u0E19|'
            r'\u0E3F|\u0E1A\u0E32\u0E17|baht|thb|'
            r'à¸¿|à¸šà¸²à¸—|Ã Â¸Å¡Ã Â¸Â²Ã Â¸â€”|[0-9.,\s:-]',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return stripped.length <= 3;
  }

  bool _isStrictNonAmountMetadata(String value) {
    final rawLower = value.toLowerCase();
    final repairedLower = repairThaiMojibake(value).toLowerCase();
    final lower = '$rawLower\n$repairedLower';
    if (_hasStrictAmountLabel(value)) {
      return false;
    }
    if (_hasStrictFeeLabel(value)) return true;
    if (_hasStrictCurrencyHint(value)) return false;
    return lower.contains('reference') ||
        lower.contains('transaction') ||
        lower.contains('ref') ||
        lower.contains('account') ||
        lower.contains('customer') ||
        lower.contains('biller') ||
        lower.contains('merchant') ||
        lower.contains('\u0E2B\u0E21\u0E32\u0E22\u0E40\u0E25\u0E02') ||
        lower.contains(
          '\u0E2B\u0E21\u0E32\u0E22\u0E40\u0E25\u0E02\u0E25\u0E39\u0E01\u0E04\u0E49\u0E32',
        ) ||
        lower.contains(
          '\u0E2B\u0E21\u0E32\u0E22\u0E40\u0E25\u0E02\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07',
        ) ||
        lower.contains(
          '\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48\u0E23\u0E32\u0E22\u0E01\u0E32\u0E23',
        ) ||
        lower.contains('\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48') ||
        lower.contains('\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07') ||
        lower.contains('\u0E1A\u0E31\u0E0D\u0E0A\u0E35') ||
        RegExp(r'\d{1,2}:\d{2}').hasMatch(lower) ||
        RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(lower) ||
        RegExp(r'\d{1,2}\s+[a-z]{3,9}\s+\d{2,4}').hasMatch(lower) ||
        RegExp(r'\d{1,2}\s+[\u0E00-\u0E7F.]{2,20}\s+\d{2,4}').hasMatch(lower) ||
        _isBankOrAccount(value);
  }

  double? _detectAmountNearLabel(List<String> lines) {
    final amountLabel = RegExp(
      r'amount|total|paid|payment|'
      r'\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19|'
      r'\u0E08\u0E33\u0E19\u0E27\u0E19|'
      r'\u0E22\u0E2D\u0E14\u0E40\u0E07\u0E34\u0E19',
      caseSensitive: false,
    );
    final numberPattern = RegExp(
      r'(?<!\d)(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?',
    );

    for (var i = 0; i < lines.length; i++) {
      if (!amountLabel.hasMatch(lines[i])) continue;
      final candidates = <({double value, int score})>[];
      for (var j = i; j < lines.length && j <= i + 3; j++) {
        if (_isMetadata(lines[j]) && j != i) continue;
        for (final match in numberPattern.allMatches(lines[j])) {
          final token = match.group(0);
          if (token == null || _looksLikeDateToken(token)) continue;
          final value = double.tryParse(token.replaceAll(',', ''));
          if (value == null || value <= 0 || value >= 10000000) continue;
          if (_looksLikeBareSmallNoise(lines[j], token, value)) continue;
          candidates.add((
            value: value,
            score: _amountCandidateScore(
              line: lines[j],
              token: token,
              value: value,
              lineDistance: j - i,
            ),
          ));
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.score.compareTo(a.score));
        return candidates.first.value;
      }
    }
    return null;
  }

  int _amountCandidateScore({
    required String line,
    required String token,
    required double value,
    required int lineDistance,
  }) {
    var score = 0;
    if (token.contains('.')) score += 6;
    if (_hasCurrencyHint(line)) score += 6;
    if (_lineLooksLikeAmountValue(line)) score += 4;
    if (value >= 10) score += 3;
    if (value >= 100) score += 1;
    score -= lineDistance;
    return score;
  }

  bool _looksLikeBareSmallNoise(String line, String token, double value) {
    if (value >= 10 || token.contains('.')) return false;
    return !_hasCurrencyHint(line);
  }

  bool _hasCurrencyHint(String value) {
    return RegExp(
      r'฿|baht|thb|บาท|à¸šà¸²à¸—',
      caseSensitive: false,
    ).hasMatch(value);
  }

  bool _lineLooksLikeAmountValue(String line) {
    final stripped = line
        .replaceAll(
          RegExp(
            r'amount|total|paid|payment|'
            r'\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19|'
            r'\u0E08\u0E33\u0E19\u0E27\u0E19|'
            r'\u0E22\u0E2D\u0E14\u0E40\u0E07\u0E34\u0E19|'
            r'฿|บาท|baht|thb|à¸šà¸²à¸—|[0-9.,\s:-]',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return stripped.length <= 3;
  }

  String? _detectBank(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('K PLUS') ||
        upper.contains('KPLUS') ||
        upper.contains('KASIKORN') ||
        upper.contains('K+')) {
      return 'K PLUS';
    }
    if (upper.contains('SCB') || upper.contains('SIAM COMMERCIAL')) {
      return 'SCB EASY';
    }
    return null;
  }

  String? _detectDate(String text) {
    for (final pattern in <RegExp>[
      RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'),
      RegExp(r'\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}'),
      RegExp(r'\d{1,2}\s+[\u0E00-\u0E7F.]{2,20}\s+\d{2,4}'),
    ]) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(0);
    }
    return null;
  }

  String? _detectReference(List<String> lines) {
    final key = RegExp(
      r'^(?:\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48\u0E23\u0E32\u0E22\u0E01\u0E32\u0E23|\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48|\u0E23\u0E2B\u0E31\u0E2A\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07|reference|ref|transaction)',
      caseSensitive: false,
    );
    for (var i = 0; i < lines.length; i++) {
      if (!key.hasMatch(lines[i])) continue;
      final inline = lines[i]
          .replaceFirst(key, '')
          .replaceFirst(RegExp(r'^[:\uFF1A\s]+'), '');
      final matcher = RegExp(r'[A-Z0-9][A-Z0-9\-]{5,}', caseSensitive: false);
      final match =
          matcher.firstMatch(inline) ??
          (i + 1 < lines.length ? matcher.firstMatch(lines[i + 1]) : null);
      if (match != null) return match.group(0);
    }
    return null;
  }

  _Parties? _detectParties(List<String> lines) {
    String? sender;
    String? recipient;

    for (var i = 0; i < lines.length; i++) {
      if (_hasLabel(lines[i], const ['\u0E08\u0E32\u0E01', 'from', 'sender'])) {
        sender ??= _valueAfter(lines, i, const [
          '\u0E08\u0E32\u0E01',
          'from',
          'sender',
        ]);
      }
      if (_hasLabel(lines[i], const [
        '\u0E44\u0E1B\u0E22\u0E31\u0E07',
        'to',
        'recipient',
        'receiver',
      ])) {
        recipient ??= _valueAfter(lines, i, const [
          '\u0E44\u0E1B\u0E22\u0E31\u0E07',
          'to',
          'recipient',
          'receiver',
        ]);
      }
    }

    if (sender != null && recipient != null) {
      return _Parties(sender, recipient);
    }

    final candidates = <String>[];
    for (var i = 0; i + 1 < lines.length; i++) {
      final looksLikeStackedParty =
          _looksLikeName(lines[i]) &&
          (_isBankOrAccount(lines[i + 1]) ||
              (i + 2 < lines.length && _isBankOrAccount(lines[i + 2])));
      if (looksLikeStackedParty) {
        candidates.add(lines[i]);
      }
    }

    sender ??= candidates.isNotEmpty ? candidates.first : null;
    recipient ??= candidates.length > 1 ? candidates[1] : null;
    return sender == null && recipient == null
        ? null
        : _Parties(sender, recipient);
  }

  bool _hasLabel(String line, List<String> labels) {
    final lower = line.toLowerCase();
    return labels.any(
      (label) =>
          lower == label ||
          lower.startsWith('$label:') ||
          lower.startsWith('$label '),
    );
  }

  String? _valueAfter(List<String> lines, int index, List<String> labels) {
    final line = lines[index];
    for (final label in labels) {
      final at = line.toLowerCase().indexOf(label.toLowerCase());
      if (at < 0) continue;
      final value = line
          .substring(at + label.length)
          .replaceFirst(RegExp(r'^[:\uFF1A\s\-]+'), '')
          .trim();
      if (_looksLikeName(value)) return value;
    }
    for (var j = index + 1; j < lines.length && j <= index + 3; j++) {
      if (_looksLikeName(lines[j]) && !_isBankOrAccount(lines[j])) {
        return lines[j];
      }
    }
    return null;
  }

  bool _looksLikeName(String value) {
    final repaired = repairThaiMojibake(value).trim();
    if (repaired.length < 2 || looksUnreadable(repaired)) return false;
    if (RegExp(r'^\d+[.,\d]*$').hasMatch(repaired)) return false;
    if (_isBankOrAccount(repaired) || _isMetadata(repaired)) return false;
    return RegExp(r'[A-Za-z\u0E00-\u0E7F]').allMatches(repaired).length >= 2;
  }

  bool _isBankOrAccount(String value) {
    final repaired = repairThaiMojibake(value);
    final lower = repaired.toLowerCase();
    final compact = repaired.replaceAll(' ', '');
    return lower.contains('bank') ||
        lower.contains('wallet') ||
        lower.contains('k plus') ||
        lower.contains('scb') ||
        lower.contains('kasikorn') ||
        lower.contains('siam commercial') ||
        repaired.contains('\u0E18.') ||
        repaired.contains('\u0E18\u0E19\u0E32\u0E04\u0E32\u0E23') ||
        repaired.contains('\u0E01\u0E2A\u0E34\u0E01\u0E23') ||
        repaired.contains(
          '\u0E44\u0E17\u0E22\u0E1E\u0E32\u0E13\u0E34\u0E0A\u0E22\u0E4C',
        ) ||
        compact.isNotEmpty && RegExp(r'^[xX*\u2022\-\d]+$').hasMatch(compact) ||
        RegExp(
          r'^(?=.*\d)[A-Z0-9\-]{8,}$',
          caseSensitive: false,
        ).hasMatch(compact);
  }

  bool _isMetadata(String value) {
    final lower = value.toLowerCase();
    return lower.contains('reference') ||
        lower.contains('transaction') ||
        lower.contains('amount') ||
        lower.contains('fee') ||
        lower.contains('\u0E08\u0E33\u0E19\u0E27\u0E19') ||
        lower.contains('\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48') ||
        lower.contains(
          '\u0E04\u0E48\u0E32\u0E18\u0E23\u0E23\u0E21\u0E40\u0E19\u0E35\u0E22\u0E21',
        ) ||
        RegExp(r'\d{1,2}:\d{2}').hasMatch(lower) ||
        RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(lower) ||
        RegExp(r'\d{1,2}\s+[a-z]{3,9}\s+\d{2,4}').hasMatch(lower) ||
        RegExp(r'\d{1,2}\s+[\u0E00-\u0E7F.]{2,20}\s+\d{2,4}').hasMatch(lower);
  }

  bool _looksLikeDateToken(String token) {
    if (token.length != 4) return false;
    final year = int.tryParse(token);
    return year != null && year >= 1900 && year <= 2600;
  }

  SlipCategory _detectCategory(String text, double? amount, _Parties? parties) {
    if (parties?.sender != null && parties?.recipient != null) {
      return SlipCategory.detail;
    }
    final lower = text.toLowerCase();
    if ([
      'income',
      'credit',
      'deposit',
      '\u0E40\u0E07\u0E34\u0E19\u0E40\u0E02\u0E49\u0E32',
      '\u0E23\u0E31\u0E1A\u0E40\u0E07\u0E34\u0E19',
      '\u0E40\u0E15\u0E34\u0E21\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08',
    ].any(lower.contains)) {
      return SlipCategory.income;
    }
    if ([
      'payment',
      'paid',
      'purchase',
      'withdrawal',
      'debit',
      '\u0E08\u0E48\u0E32\u0E22',
      '\u0E0A\u0E33\u0E23\u0E30',
      '\u0E0B\u0E37\u0E49\u0E2D',
      '\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08',
    ].any(lower.contains)) {
      return SlipCategory.expense;
    }
    if (parties?.sender != null && parties?.recipient == null) {
      return SlipCategory.income;
    }
    if (parties?.recipient != null && parties?.sender == null) {
      return SlipCategory.expense;
    }
    return amount == null ? SlipCategory.unknown : SlipCategory.expense;
  }
}

class _Parties {
  const _Parties(this.sender, this.recipient);

  final String? sender;
  final String? recipient;
}
