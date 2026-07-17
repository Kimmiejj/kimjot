import 'transaction_source.dart';
import 'transaction_type.dart';

class UpdateTransactionInput {
  const UpdateTransactionInput({
    required this.transactionId,
    required this.userId,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.transactionDate,
    this.transactionDateText,
    required this.source,
    this.note,
    this.slipFingerprint,
    this.slipReference,
    this.baseUpdatedAt,
    this.forceOverwrite = false,
  });

  final String transactionId;
  final String userId;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String categoryName;
  final DateTime transactionDate;
  final String? transactionDateText;
  final TransactionSource source;
  final String? note;
  final String? slipFingerprint;
  final String? slipReference;
  final DateTime? baseUpdatedAt;
  final bool forceOverwrite;
}
