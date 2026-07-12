import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'create_transaction_input.dart';
import 'home_summary.dart';
import 'transaction_record.dart';
import 'transaction_repository.dart';
import 'transaction_source.dart';
import 'transaction_type.dart';
import 'update_transaction_input.dart';

class FirebaseTransactionRepository implements TransactionRepository {
  FirebaseTransactionRepository({FirebaseFirestore? firestore})
    : this._(firestore);

  FirebaseTransactionRepository._(this._firestore);

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createManualTransaction(CreateTransactionInput input) async {
    final note = input.note?.trim();
    final document = _db
        .collection('users')
        .doc(input.userId)
        .collection('transactions')
        .doc();

    final write = document.set({
      'user': input.userId,
      'amount': input.amount,
      'type': input.type.firestoreValue,
      'categoryId': input.categoryId,
      'categoryName': input.categoryName,
      'note': note == null || note.isEmpty ? null : note,
      'transactionDate': Timestamp.fromDate(input.transactionDate),
      'transactionDateText': input.transactionDateText,
      'source': input.source.firestoreValue,
      'slipFingerprint': input.slipFingerprint,
      'slipReference': input.slipReference,
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

    final write = document.update({
      'amount': input.amount,
      'type': input.type.firestoreValue,
      'categoryId': input.categoryId,
      'categoryName': input.categoryName,
      'note': note == null || note.isEmpty ? null : note,
      'transactionDate': Timestamp.fromDate(input.transactionDate),
      'transactionDateText': input.transactionDateText,
      'source': input.source.firestoreValue,
      'slipFingerprint': input.slipFingerprint,
      'slipReference': input.slipReference,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await write.timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
  }

  @override
  Future<void> deleteTransaction({
    required String userId,
    required String transactionId,
  }) {
    return _userTransactionsCollection(userId).doc(transactionId).delete();
  }

  @override
  Future<Set<String>> loadActiveSlipFingerprints(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .where(
          'source',
          isEqualTo: TransactionSource.gallerySlip.firestoreValue,
        )
        .get();

    return snapshot.docs
        .map((document) => document.data()['slipFingerprint'] as String?)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toSet();
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
        .map((snapshot) => _summaryFromSnapshot(snapshot, monthStart));
  }

  @override
  Stream<List<TransactionRecord>> watchRecentTransactions(
    String userId, {
    int limit = 5,
  }) {
    return _transactionsQuery(userId)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_recordFromDocument).toList());
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
    return limited.snapshots().map(
      (snapshot) => snapshot.docs.map(_recordFromDocument).toList(),
    );
  }

  @override
  Stream<List<TransactionRecord>> watchTransactions(String userId) {
    return _transactionsQuery(userId).snapshots().map(
      (snapshot) => snapshot.docs.map(_recordFromDocument).toList(),
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

  HomeSummary _summaryFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    DateTime monthStart,
  ) {
    var incomeTotal = 0.0;
    var expenseTotal = 0.0;
    var transactionCount = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
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

  TransactionRecord _recordFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['transactionDate'] as Timestamp?;

    return TransactionRecord(
      id: document.id,
      userId: data['user'] as String? ?? '',
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
    );
  }

  TransactionType _typeFromFirestore(String? value) {
    return switch (value) {
      'income' => TransactionType.income,
      'internalTransfer' || 'internal_transfer' =>
        TransactionType.internalTransfer,
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
