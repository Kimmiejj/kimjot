enum SlipCategory { detail, income, expense, unknown }

class SlipScanResult {
  const SlipScanResult({
    required this.rawText,
    this.bankName,
    this.amount,
    this.dateText,
    this.timeText,
    this.recipient,
    this.sender,
    this.reference,
    this.category = SlipCategory.unknown,
    this.amountConfidence,
  });

  final String rawText;
  final String? bankName;
  final double? amount;
  final String? dateText;
  final String? timeText;
  final String? recipient;
  final String? sender;
  final String? reference;
  final SlipCategory category;
  final double? amountConfidence;

  bool get hasUsefulData {
    return bankName != null ||
        amount != null ||
        recipient != null ||
        reference != null;
  }

  String get bankDisplayName => bankName ?? 'Unknown bank';

  SlipScanResult copyWith({
    String? rawText,
    String? bankName,
    double? amount,
    String? dateText,
    String? timeText,
    String? recipient,
    String? sender,
    String? reference,
    SlipCategory? category,
    double? amountConfidence,
  }) {
    return SlipScanResult(
      rawText: rawText ?? this.rawText,
      bankName: bankName ?? this.bankName,
      amount: amount ?? this.amount,
      dateText: dateText ?? this.dateText,
      timeText: timeText ?? this.timeText,
      recipient: recipient ?? this.recipient,
      sender: sender ?? this.sender,
      reference: reference ?? this.reference,
      category: category ?? this.category,
      amountConfidence: amountConfidence ?? this.amountConfidence,
    );
  }
}
