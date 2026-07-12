import 'package:flutter_test/flutter_test.dart';
import 'package:kimjod/features/scan/slip_scan_result.dart';
import 'package:kimjod/features/scan/slip_transaction_resolver.dart';
import 'package:kimjod/features/transactions/transaction_type.dart';

void main() {
  test('treats contained sender/recipient names as internal transfer', () {
    final result = SlipScanResult(
      rawText: 'transfer success',
      sender: 'Mr Somchai Jaidee',
      recipient: 'Somchai',
      amount: 1200,
    );

    final decision = resolveLocalSlipDecision(result);

    expect(decision?.type, TransactionType.internalTransfer);
    expect(decision?.categoryId, 'internal_transfer');
  });

  test('treats overlapping Thai sender/recipient tokens as internal transfer', () {
    final result = SlipScanResult(
      rawText: 'โอนสำเร็จ',
      sender: 'นาย สมชาย ใจดี',
      recipient: 'สมชาย ใจดี',
      amount: 500,
    );

    final decision = resolveLocalSlipDecision(result);

    expect(decision?.type, TransactionType.internalTransfer);
  });
}
