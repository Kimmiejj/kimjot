import 'create_transaction_input.dart';
import 'home_summary.dart';
import 'transaction_record.dart';

abstract class TransactionRepository {
  Future<void> createManualTransaction(CreateTransactionInput input);

  Stream<HomeSummary> watchCurrentMonthSummary(String userId);

  Stream<List<TransactionRecord>> watchRecentTransactions(
    String userId, {
    int limit = 5,
  });

  Stream<List<TransactionRecord>> watchTransactions(String userId);
}
