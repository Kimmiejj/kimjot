enum TransactionType {
  expense,
  income,
  internalTransfer;

  String get firestoreValue => name;

  bool get isIncome => this == TransactionType.income;

  bool get isExpense => this == TransactionType.expense;

  bool get isInternalTransfer => this == TransactionType.internalTransfer;
}
