import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../security/transaction_encryption_manager.dart';
import '../security/transaction_payload_cipher.dart';
import 'create_transaction_input.dart';
import 'home_summary.dart';
import 'transaction_record.dart';
import 'transaction_repository.dart';
import 'transaction_source.dart';
import 'transaction_sync_status.dart';
import 'transaction_type.dart';
import 'update_transaction_input.dart';

class FirebaseTransactionRepository
    implements TransactionRepository, TransactionEncryptionController {
  FirebaseTransactionRepository({
    FirebaseFirestore? firestore,
    TransactionEncryptionManager? encryptionManager,
  }) : this._(
         firestore,
         encryptionManager ??
             TransactionEncryptionManager(firestore: firestore),
       );

  FirebaseTransactionRepository._(this._firestore, this._encryption);

  final FirebaseFirestore? _firestore;
  final TransactionEncryptionManager _encryption;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createManualTransaction(CreateTransactionInput input) async {
    final note = input.note?.trim();
    final document = _db
        .collection('users')
        .doc(input.userId)
        .collection('transactions')
        .doc();
    final payload = await _encryption.encryptPayload(
      userId: input.userId,
      documentId: document.id,
      transactionDate: input.transactionDate,
      payload: <String, Object?>{
        'amount': input.amount,
        'type': input.type.firestoreValue,
        'categoryId': input.categoryId,
        'categoryName': input.categoryName,
        'transactionDateText': input.transactionDateText,
        'source': input.source.firestoreValue,
        'note': note == null || note.isEmpty ? null : note,
        'slipFingerprint': input.slipFingerprint,
        'slipReference': input.slipReference,
      },
    );

    final write = document.set({
      'transactionDate': Timestamp.fromDate(input.transactionDate),
      'encryptionVersion': 1,
      'payload': payload,
      'clientUpdatedAt': Timestamp.fromDate(DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await write.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        // Firestore keeps the local write queued offline. Return control to UI
        // so saving a transaction never looks frozen while the network is gone.
      },
    );
  }

  @override
  Future<void> updateTransaction(UpdateTransactionInput input) async {
    final note = input.note?.trim();
    final document = _userTransactionsCollection(
      input.userId,
    ).doc(input.transactionId);
    final payload = await _encryption.encryptPayload(
      userId: input.userId,
      documentId: input.transactionId,
      transactionDate: input.transactionDate,
      payload: <String, Object?>{
        'amount': input.amount,
        'type': input.type.firestoreValue,
        'categoryId': input.categoryId,
        'categoryName': input.categoryName,
        'transactionDateText': input.transactionDateText,
        'source': input.source.firestoreValue,
        'note': note == null || note.isEmpty ? null : note,
        'slipFingerprint': input.slipFingerprint,
        'slipReference': input.slipReference,
      },
    );
    final data = <String, Object?>{
      'transactionDate': Timestamp.fromDate(input.transactionDate),
      'encryptionVersion': 1,
      'payload': payload,
      'clientUpdatedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': FieldValue.serverTimestamp(),
      ..._legacyFieldDeletes,
    };

    if (input.baseUpdatedAt != null && !input.forceOverwrite) {
      try {
        await _db
            .runTransaction((transaction) async {
              final current = await transaction.get(document);
              final serverData = current.data();
              final serverUpdatedAt = (serverData?['updatedAt'] as Timestamp?)
                  ?.toDate();
              if (serverUpdatedAt != null &&
                  serverUpdatedAt.millisecondsSinceEpoch !=
                      input.baseUpdatedAt!.millisecondsSinceEpoch) {
                final clearServerData = await _clearDocumentData(
                  userId: input.userId,
                  documentId: input.transactionId,
                  data: serverData!,
                );
                throw TransactionConflictException(
                  clearServerData.map(
                    (key, value) => MapEntry<String, Object?>(key, value),
                  ),
                );
              }
              transaction.update(document, data);
            })
            .timeout(const Duration(seconds: 4));
        return;
      } on TransactionConflictException {
        rethrow;
      } on TransactionEncryptionException {
        rethrow;
      } catch (_) {
        // Transactions need a server round-trip. Fall back to Firestore's
        // durable local queue when the device is offline.
      }
    }

    final write = document.update(data);

    await write.timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  @override
  Future<void> deleteTransaction({
    required String userId,
    required String transactionId,
  }) async {
    final write = _userTransactionsCollection(
      userId,
    ).doc(transactionId).delete();
    await write.timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  @override
  Future<Set<String>> loadActiveSlipFingerprints(String userId) async {
    final query = _userTransactionsCollection(userId);
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get().timeout(const Duration(seconds: 3));
    } catch (_) {
      snapshot = await query.get(const GetOptions(source: Source.cache));
    }

    final fingerprints = <String>{};
    for (final document in snapshot.docs) {
      final clear = await _clearDocumentData(
        userId: userId,
        documentId: document.id,
        data: document.data(),
      );
      if (clear['source'] != TransactionSource.gallerySlip.firestoreValue) {
        continue;
      }
      final fingerprint = clear['slipFingerprint'] as String?;
      if (fingerprint != null && fingerprint.trim().isNotEmpty) {
        fingerprints.add(fingerprint);
      }
    }
    return fingerprints;
  }

  @override
  Stream<HomeSummary> watchCurrentMonthSummary(String userId) {
    return watchMonthSummary(userId, DateTime.now());
  }

  @override
  Stream<HomeSummary> watchMonthSummary(String userId, DateTime month) {
    final monthStart = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);

    return _userTransactionsCollection(userId)
        .where(
          'transactionDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where('transactionDate', isLessThan: Timestamp.fromDate(nextMonth))
        .orderBy('transactionDate')
        .snapshots()
        .asyncMap(
          (snapshot) => _summaryFromSnapshot(
            snapshot,
            userId: userId,
            monthStart: monthStart,
          ),
        );
  }

  @override
  Stream<List<TransactionRecord>> watchRecentTransactions(
    String userId, {
    int limit = 5,
  }) {
    return _transactionsQuery(userId)
        .limit(limit)
        .snapshots()
        .asyncMap(
          (snapshot) => Future.wait(
            snapshot.docs.map(
              (document) => _recordFromDocument(document, userId),
            ),
          ),
        );
  }

  @override
  Stream<List<TransactionRecord>> watchMonthTransactions(
    String userId,
    DateTime month, {
    int? limit,
  }) {
    final monthStart = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    var query = _userTransactionsCollection(userId)
        .where(
          'transactionDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where('transactionDate', isLessThan: Timestamp.fromDate(nextMonth))
        .orderBy('transactionDate', descending: true);

    final limited = limit == null ? query : query.limit(limit);
    return limited.snapshots().asyncMap(
      (snapshot) => Future.wait(
        snapshot.docs.map((document) => _recordFromDocument(document, userId)),
      ),
    );
  }

  @override
  Stream<List<TransactionRecord>> watchTransactions(String userId) {
    return _transactionsQuery(userId).snapshots().asyncMap(
      (snapshot) => Future.wait(
        snapshot.docs.map((document) => _recordFromDocument(document, userId)),
      ),
    );
  }

  @override
  Stream<TransactionSyncStatus> watchSyncStatus(String userId) {
    return _userTransactionsCollection(userId)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => TransactionSyncStatus(
            pendingWrites: snapshot.docs
                .where((document) => document.metadata.hasPendingWrites)
                .length,
            isFromCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  CollectionReference<Map<String, dynamic>> _userTransactionsCollection(
    String userId,
  ) {
    return _db.collection('users').doc(userId).collection('transactions');
  }

  Query<Map<String, dynamic>> _transactionsQuery(String userId) {
    return _userTransactionsCollection(
      userId,
    ).orderBy('transactionDate', descending: true);
  }

  Future<HomeSummary> _summaryFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required String userId,
    required DateTime monthStart,
  }) async {
    var incomeTotal = 0.0;
    var expenseTotal = 0.0;
    var transactionCount = 0;

    for (final document in snapshot.docs) {
      final data = await _clearDocumentData(
        userId: userId,
        documentId: document.id,
        data: document.data(),
      );
      if (!_matchesCurrentMonth(data, monthStart)) {
        continue;
      }

      transactionCount++;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final type = data['type'] as String?;

      if (type == 'income') {
        incomeTotal += amount;
      } else if (type == 'expense') {
        expenseTotal += amount;
      }
    }

    return HomeSummary(
      incomeTotal: incomeTotal,
      expenseTotal: expenseTotal,
      transactionCount: transactionCount,
    );
  }

  bool _matchesCurrentMonth(Map<String, dynamic> data, DateTime monthStart) {
    final transactionDate = (data['transactionDate'] as Timestamp?)?.toDate();
    return transactionDate != null && !transactionDate.isBefore(monthStart);
  }

  Future<TransactionRecord> _recordFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String userId,
  ) async {
    final data = await _clearDocumentData(
      userId: userId,
      documentId: document.id,
      data: document.data(),
    );
    final timestamp = data['transactionDate'] as Timestamp?;

    return TransactionRecord(
      id: document.id,
      userId: userId,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      type: _typeFromFirestore(data['type'] as String?),
      categoryId: data['categoryId'] as String? ?? 'other',
      categoryName: data['categoryName'] as String? ?? 'Other',
      transactionDate:
          timestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      source: _sourceFromFirestore(data['source'] as String?),
      note: data['note'] as String?,
      merchantName: data['merchantName'] as String?,
      slipFingerprint: data['slipFingerprint'] as String?,
      slipReference: data['slipReference'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<Map<String, dynamic>> _clearDocumentData({
    required String userId,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final envelope = data['payload'];
    if (envelope is! Map) {
      return data;
    }
    final transactionDate = (data['transactionDate'] as Timestamp?)?.toDate();
    if (transactionDate == null) {
      throw const TransactionEncryptionException(
        'Encrypted transaction is missing its date metadata.',
      );
    }
    final payload = await _encryption.decryptPayload(
      userId: userId,
      documentId: documentId,
      transactionDate: transactionDate,
      envelope: Map<String, dynamic>.from(envelope),
    );
    return <String, dynamic>{...data, ...payload};
  }

  @override
  Future<TransactionEncryptionAccess> prepareEncryption(String userId) async {
    final access = await _encryption.prepareEncryption(userId);
    if (access == TransactionEncryptionAccess.unlocked) {
      try {
        await _migrateLegacyTransactions(userId);
      } catch (_) {
        // Retry on the next launch; all new writes are encrypted immediately.
      }
    }
    return access;
  }

  @override
  Future<String> createRecoveryKey(String userId, {String? recoveryKey}) async {
    final createdRecoveryKey = await _encryption.createRecoveryKey(
      userId,
      recoveryKey: recoveryKey,
    );
    try {
      await _migrateLegacyTransactions(userId);
    } catch (_) {
      // The recovery key must still be shown even if an offline migration waits.
    }
    return createdRecoveryKey;
  }

  @override
  Future<bool> unlockWithRecoveryKey(String userId, String recoveryKey) async {
    final unlocked = await _encryption.unlockWithRecoveryKey(
      userId,
      recoveryKey,
    );
    if (unlocked) {
      try {
        await _migrateLegacyTransactions(userId);
      } catch (_) {
        // Retry on the next launch.
      }
    }
    return unlocked;
  }

  @override
  Future<bool> changeRecoveryKey({
    required String userId,
    required String currentRecoveryKey,
    required String newRecoveryKey,
  }) {
    return _encryption.changeRecoveryKey(
      userId: userId,
      currentRecoveryKey: currentRecoveryKey,
      newRecoveryKey: newRecoveryKey,
    );
  }

  @override
  Future<String> sendRecoveryKeyEmail(String userId) {
    return _encryption.sendRecoveryKeyEmail(userId);
  }

  @override
  void clearEncryptionKey() => _encryption.clearEncryptionKey();

  Future<void> _migrateLegacyTransactions(String userId) async {
    final snapshot = await _userTransactionsCollection(userId).get();
    var batch = _db.batch();
    var batchSize = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      if (data['payload'] is Map) {
        continue;
      }
      final transactionDate = (data['transactionDate'] as Timestamp?)?.toDate();
      if (transactionDate == null) {
        continue;
      }
      final payload = await _encryption.encryptPayload(
        userId: userId,
        documentId: document.id,
        transactionDate: transactionDate,
        payload: _legacyPayload(data),
      );
      batch.update(document.reference, <String, Object?>{
        'encryptionVersion': 1,
        'payload': payload,
        'clientUpdatedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': FieldValue.serverTimestamp(),
        ..._legacyFieldDeletes,
      });
      batchSize++;

      if (batchSize == 400) {
        await batch.commit();
        batch = _db.batch();
        batchSize = 0;
      }
    }

    if (batchSize > 0) {
      await batch.commit();
    }
  }

  Map<String, Object?> _legacyPayload(Map<String, dynamic> data) {
    return <String, Object?>{
      'amount': data['amount'],
      'type': data['type'],
      'categoryId': data['categoryId'],
      'categoryName': data['categoryName'],
      'transactionDateText': data['transactionDateText'],
      'source': data['source'],
      'note': data['note'],
      'merchantName': data['merchantName'],
      'slipFingerprint': data['slipFingerprint'],
      'slipReference': data['slipReference'],
    };
  }

  Map<String, Object?> get _legacyFieldDeletes => <String, Object?>{
    'user': FieldValue.delete(),
    'amount': FieldValue.delete(),
    'type': FieldValue.delete(),
    'categoryId': FieldValue.delete(),
    'categoryName': FieldValue.delete(),
    'transactionDateText': FieldValue.delete(),
    'source': FieldValue.delete(),
    'note': FieldValue.delete(),
    'merchantName': FieldValue.delete(),
    'slipFingerprint': FieldValue.delete(),
    'slipReference': FieldValue.delete(),
  };

  TransactionType _typeFromFirestore(String? value) {
    return switch (value) {
      'income' => TransactionType.income,
      'internalTransfer' ||
      'internal_transfer' => TransactionType.internalTransfer,
      _ => TransactionType.expense,
    };
  }

  TransactionSource _sourceFromFirestore(String? value) {
    return switch (value) {
      'gallery_slip' => TransactionSource.gallerySlip,
      _ => TransactionSource.manual,
    };
  }
}
