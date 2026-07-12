import 'slip_amount_classifier.dart';
import 'slip_scan_result.dart';

class SlipTextParser {
  SlipTextParser();

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

    for (final keyword in incomeKeywords) {
      if (lower.contains(keyword)) {
        return SlipCategory.income;
      }
    }

    for (final keyword in expenseKeywords) {
      if (lower.contains(keyword)) {
        return SlipCategory.expense;
      }
    }

    if (sender != null && recipient == null) {
      return SlipCategory.income;
    }

    if (recipient != null && sender == null) {
      return SlipCategory.expense;
    }

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
    final rawText = lines.join('\n');
    final contexts = AmountClassifier.instance.extractCandidateContexts(
      rawText,
      lines: lines,
    );
    if (contexts.isEmpty) {
      return null;
    }

    if (contexts.length == 1) {
      _lastAmountConfidence = 1.0;
      return contexts.first.value;
    }

    try {
      final prediction = AmountClassifier.instance.predictFromContexts(
        rawText: rawText,
        lines: lines,
        contexts: contexts,
      );
      if (prediction.index >= 0 && prediction.index < contexts.length) {
        _lastAmountConfidence = prediction.confidence;
        return contexts[prediction.index].value;
      }
    } catch (_) {
      // Ignore and use the first extracted amount as a fallback.
    }

    _lastAmountConfidence = 0.0;
    return contexts.first.value;
  }

  String? _detectDate(String text) {
    final patterns = [
      RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'),
      RegExp(r'\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}'),
      RegExp(r'\d{1,2}\s+[\u0E00-\u0E7F.]{2,20}\s+\d{2,4}'),
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
          .map((item) => item.group(0))
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
