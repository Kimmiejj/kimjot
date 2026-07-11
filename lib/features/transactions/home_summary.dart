class HomeSummary {
  const HomeSummary({
    required this.incomeTotal,
    required this.expenseTotal,
    required this.transactionCount,
  });

  const HomeSummary.empty()
    : incomeTotal = 0,
      expenseTotal = 0,
      transactionCount = 0;

  final double incomeTotal;
  final double expenseTotal;
  final int transactionCount;

  double get balance => incomeTotal - expenseTotal;
}
