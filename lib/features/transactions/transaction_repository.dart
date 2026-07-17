import 'create_transaction_input.dart';
import 'home_summary.dart';
import 'transaction_record.dart';
import 'transaction_sync_status.dart';
import 'update_transaction_input.dart';

abstract class TransactionRepository {
  Future<void> createManualTransaction(CreateTransactionInput input);

  Future<void> updateTransaction(UpdateTransactionInput input);

  Future<void> deleteTransaction({
    required String userId,
    required String transactionId,
  });

  Future<Set<String>> loadActiveSlipFingerprints(String userId);

  Stream<HomeSummary> watchCurrentMonthSummary(String userId);

  Stream<HomeSummary> watchMonthSummary(String userId, DateTime month);

  Stream<List<TransactionRecord>> watchRecentTransactions(
    String userId, {
    int limit = 5,
  });

  Stream<List<TransactionRecord>> watchMonthTransactions(
    String userId,
    DateTime month, {
    int? limit,
  });

  Stream<List<TransactionRecord>> watchTransactions(String userId);

  Stream<TransactionSyncStatus> watchSyncStatus(String userId);
}

class TransactionConflictException implements Exception {
  const TransactionConflictException(this.serverData);

  final Map<String, Object?> serverData;
}
