import 'package:cloud_firestore/cloud_firestore.dart';

import 'create_transaction_input.dart';
import 'home_summary.dart';
import 'transaction_record.dart';
import 'transaction_repository.dart';
import 'transaction_source.dart';
import 'transaction_type.dart';

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

    await document.set({
      'amount': input.amount,
      'type': input.type.firestoreValue,
      'categoryId': input.categoryId,
      'categoryName': input.categoryName,
      'note': note == null || note.isEmpty ? null : note,
      'transactionDate': Timestamp.fromDate(input.transactionDate),
      'source': input.source.firestoreValue,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<HomeSummary> watchCurrentMonthSummary(String userId) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);

    return _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .where(
          'transactionDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .snapshots()
        .map((snapshot) {
          var incomeTotal = 0.0;
          var expenseTotal = 0.0;

          for (final document in snapshot.docs) {
            final data = document.data();
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
            transactionCount: snapshot.docs.length,
          );
        });
  }

  @override
  Stream<List<TransactionRecord>> watchRecentTransactions(
    String userId, {
    int limit = 5,
  }) {
    return _transactionsQuery(userId).limit(limit).snapshots().map(
      (snapshot) => snapshot.docs.map(_recordFromDocument).toList(),
    );
  }

  @override
  Stream<List<TransactionRecord>> watchTransactions(String userId) {
    return _transactionsQuery(userId).snapshots().map(
      (snapshot) => snapshot.docs.map(_recordFromDocument).toList(),
    );
  }

  Query<Map<String, dynamic>> _transactionsQuery(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('transactionDate', descending: true);
  }

  TransactionRecord _recordFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['transactionDate'] as Timestamp?;

    return TransactionRecord(
      id: document.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      type: _typeFromFirestore(data['type'] as String?),
      categoryId: data['categoryId'] as String? ?? 'other',
      categoryName: data['categoryName'] as String? ?? 'Other',
      transactionDate: timestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      source: _sourceFromFirestore(data['source'] as String?),
      note: data['note'] as String?,
      merchantName: data['merchantName'] as String?,
    );
  }

  TransactionType _typeFromFirestore(String? value) {
    return value == 'income' ? TransactionType.income : TransactionType.expense;
  }

  TransactionSource _sourceFromFirestore(String? value) {
    return switch (value) {
      'gallery_slip' => TransactionSource.gallerySlip,
      'qr_camera' => TransactionSource.qrCamera,
      _ => TransactionSource.manual,
    };
  }
}
