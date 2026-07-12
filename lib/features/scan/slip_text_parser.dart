import 'slip_scan_result.dart';
import 'slip_amount_classifier.dart';

class SlipTextParser {
  SlipTextParser();

  // Temporary storage for the last amount confidence computed during parse
  double? _lastAmountConfidence;

  SlipScanResult parse(
    String rawText, {
    double? suggestedAmount,
    double? suggestedConfidence,
  }) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final compact = lines.join('\n');

    final detectedAmount = _detectAmount(lines);
    final finalAmount = suggestedAmount ?? detectedAmount;
    final detectedRecipient = _detectNearbyValue(lines, [
      'to',
      'recipient',
      'receiver',
      'ผู้รับ',
      'ไปยัง',
      'ชื่อบัญชี',
    ]);
    final detectedSender = _detectNearbyValue(lines, [
      'from',
      'sender',
      'ผู้โอน',
      'จาก',
    ]);

    final result = SlipScanResult(
      rawText: rawText,
      bankName: _detectBank(compact),
      amount: finalAmount,
      dateText: _detectDate(compact),
      timeText: _detectTime(compact),
      recipient: detectedRecipient,
      sender: detectedSender,
      reference: _detectReference(lines),
      category: _detectCategory(
        rawText,
        lines,
        detectedAmount,
        detectedSender,
        detectedRecipient,
      ),
      amountConfidence: suggestedAmount != null
          ? suggestedConfidence
          : _lastAmountConfidence,
    );

    // clear temporary confidence after use
    _lastAmountConfidence = null;
    return result;
  }

  SlipCategory _detectCategory(
    String rawText,
    List<String> lines,
    double? amount,
    String? sender,
    String? recipient,
  ) {
    final lower = rawText.toLowerCase();

    // Income-like keywords
    final incomeKeywords = [
      'income',
      'credit',
      'credited',
      'deposit',
      'received',
      'receipt received',
      'receipt of',
      'payment received',
      'เงินเข้า',
      'รับเงิน',
      'เครดิต',
    ];

    // Expense-like keywords
    final expenseKeywords = [
      'payment',
      'paid',
      'purchase',
      'total',
      'amount',
      'withdrawal',
      'debit',
      'invoice',
      'receipt',
      'bill',
      'ค่าบริการ',
      'ซื้อ',
      'จ่าย',
      'ยอดเงิน',
    ];

    for (final k in incomeKeywords) {
      if (lower.contains(k)) {
        return SlipCategory.income;
      }
    }

    for (final k in expenseKeywords) {
      if (lower.contains(k)) {
        return SlipCategory.expense;
      }
    }

    // Heuristic: if we detect a sender (someone who sent money) and recipient is null -> likely income
    if (sender != null && recipient == null) {
      return SlipCategory.income;
    }

    // If recipient present but sender absent, likely expense (we are sender)
    if (recipient != null && sender == null) {
      return SlipCategory.expense;
    }

    // Fallback: if amount is present and text includes words like 'transfer' or 'to' close to amount, treat as expense
    if (amount != null) {
      final nearby = lines.join(' ');
      if (nearby.contains('to') || nearby.contains('ไปยัง')) {
        return SlipCategory.expense;
      }
    }

    return SlipCategory.unknown;
  }

  String? _detectBank(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('K PLUS') ||
        upper.contains('KPLUS') ||
        upper.contains('KASIKORN') ||
        text.contains('กสิกร')) {
      return 'K PLUS';
    }

    if (upper.contains('SCB EASY') ||
        upper.contains('SCB') ||
        upper.contains('SIAM COMMERCIAL') ||
        text.contains('ไทยพาณิชย์')) {
      return 'SCB EASY';
    }

    return null;
  }

  double? _detectAmount(List<String> lines) {
    final amountWords = RegExp(
      r'(amount|total|จำนวนเงิน|ยอดเงิน|บาท|baht|thb)',
      caseSensitive: false,
    );
    final candidates = <_AmountCandidate>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final nearby = [
        if (i > 0) lines[i - 1],
        line,
        if (i + 1 < lines.length) lines[i + 1],
      ].join(' ');

      final bahtValue = _moneyBeforeBaht(nearby);
      if (bahtValue != null) {
        candidates.add(_AmountCandidate(bahtValue, 120));
      }

      if (amountWords.hasMatch(line)) {
        final value = _bestMoneyValue(nearby);
        if (value != null) {
          candidates.add(_AmountCandidate(value, 100));
        }
      }

      final value = _bestMoneyValue(line);
      if (value != null) {
        candidates.add(_AmountCandidate(value, 10));
      }
    }

    candidates.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }

      return b.value.compareTo(a.value);
    });
    if (candidates.isEmpty) return null;

    final values = candidates.map((c) => c.value).toList();
    if (values.length == 1) return values.first;

    // Use local classifier to pick best candidate when multiple found.
    try {
      final pred = AmountClassifier.instance.predict(
        rawText: lines.join('\n'),
        lines: lines,
        candidates: values,
      );
      if (pred.index >= 0 && pred.index < values.length) {
        // store confidence somewhere? parser returns only amount here; we'll
        // set confidence via an additional field in SlipScanResult higher up.
        _lastAmountConfidence = pred.confidence;
        return values[pred.index];
      }
    } catch (_) {
      // ignore and fallback
    }

    _lastAmountConfidence = null;
    return candidates.first.value;
  }

  double? _moneyBeforeBaht(String text) {
    final match = RegExp(
      r'(?<!\d)(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?\s*(?:บาท|baht|thb)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(0)!.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  double? _bestMoneyValue(String text) {
    final matches = RegExp(r'(?<!\d)(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?')
        .allMatches(text)
        .map((match) => match.group(0))
        .whereType<String>()
        .map((value) => double.tryParse(value.replaceAll(',', '')))
        .whereType<double>()
        .where((value) => value > 0 && value < 1000000)
        .toList();

    if (matches.isEmpty) {
      return null;
    }

    matches.sort();
    return matches.last;
  }

  String? _detectDate(String text) {
    final patterns = [
      RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'),
      RegExp(r'\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}'),
      RegExp(r'\d{1,2}\s+[ก-๙.]{2,8}\s+\d{2,4}'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }

    return null;
  }

  String? _detectTime(String text) {
    return RegExp(r'\d{1,2}:\d{2}(?::\d{2})?').firstMatch(text)?.group(0);
  }

  String? _detectNearbyValue(List<String> lines, List<String> keys) {
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      final matched = keys.any((key) => lower.contains(key.toLowerCase()));
      if (!matched) {
        continue;
      }

      final afterColon = lines[i]
          .split(RegExp(r'[:：]'))
          .skip(1)
          .join(':')
          .trim();
      if (_looksLikeName(afterColon)) {
        return afterColon;
      }

      if (i + 1 < lines.length && _looksLikeName(lines[i + 1])) {
        return lines[i + 1];
      }
    }

    return null;
  }

  String? _detectReference(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      final hasKey =
          lower.contains('ref') ||
          lower.contains('reference') ||
          lower.contains('transaction') ||
          lower.contains('เลขที่') ||
          lower.contains('อ้างอิง');
      if (!hasKey) {
        continue;
      }

      final match = RegExp(r'[A-Z0-9]{6,}', caseSensitive: false)
          .allMatches(lines[i])
          .map((match) => match.group(0))
          .whereType<String>()
          .lastOrNull;
      if (match != null) {
        return match;
      }

      if (i + 1 < lines.length) {
        final next = RegExp(
          r'[A-Z0-9]{6,}',
          caseSensitive: false,
        ).firstMatch(lines[i + 1])?.group(0);
        if (next != null) {
          return next;
        }
      }
    }

    return null;
  }

  bool _looksLikeName(String value) {
    if (value.length < 3) {
      return false;
    }

    if (RegExp(r'^\d+[.,\d]*$').hasMatch(value)) {
      return false;
    }

    return true;
  }
}

class _AmountCandidate {
  const _AmountCandidate(this.value, this.score);

  final double value;
  final int score;
}
