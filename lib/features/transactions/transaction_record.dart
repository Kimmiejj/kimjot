import 'transaction_source.dart';
import 'transaction_type.dart';

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.transactionDate,
    required this.source,
    this.note,
    this.merchantName,
  });

  final String id;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String categoryName;
  final DateTime transactionDate;
  final TransactionSource source;
  final String? note;
  final String? merchantName;

  bool get isIncome => type == TransactionType.income;

  String get displayTitle {
    final trimmedMerchant = merchantName?.trim();
    if (trimmedMerchant != null && trimmedMerchant.isNotEmpty) {
      return trimmedMerchant;
    }

    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      return trimmedNote;
    }

    return categoryName;
  }
}
