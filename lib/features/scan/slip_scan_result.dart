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
}
