import 'transaction_type.dart';
import 'transaction_source.dart';

class CreateTransactionInput {
  const CreateTransactionInput({
    required this.userId,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.transactionDate,
    this.source = TransactionSource.manual,
    this.note,
    this.slipFingerprint,
    this.slipReference,
  });

  final String userId;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String categoryName;
  final DateTime transactionDate;
  final TransactionSource source;
  final String? note;
  final String? slipFingerprint;
  final String? slipReference;
}
