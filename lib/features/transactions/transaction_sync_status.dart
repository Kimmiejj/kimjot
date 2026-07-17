class TransactionSyncStatus {
  const TransactionSyncStatus({
    required this.pendingWrites,
    required this.isFromCache,
  });

  const TransactionSyncStatus.synced() : pendingWrites = 0, isFromCache = false;

  final int pendingWrites;
  final bool isFromCache;

  bool get hasPendingWrites => pendingWrites > 0;
  bool get isOffline => isFromCache;
}
