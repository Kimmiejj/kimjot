import 'package:flutter_test/flutter_test.dart';
import 'package:kimjod/features/scan/slip_scan_result.dart';
import 'package:kimjod/features/scan/slip_transaction_resolver.dart';
import 'package:kimjod/features/transactions/transaction_type.dart';

void main() {
  test('treats contained sender and recipient names as internal transfer', () {
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

  test(
    'treats overlapping Thai sender and recipient tokens as internal transfer',
    () {
      final result = SlipScanResult(
        rawText: 'โอนสำเร็จ',
        sender: 'นาย สมชาย ใจดี',
        recipient: 'สมชาย สุขใจ',
        amount: 500,
      );

      final decision = resolveLocalSlipDecision(result);

      expect(decision?.type, TransactionType.internalTransfer);
    },
  );

  test('treats matching Thai honorific names as internal transfer', () {
    final result = SlipScanResult(
      rawText: 'internal transfer',
      sender: 'นาย ชิษณุชา',
      recipient: 'นาย ชิษณุชา',
      amount: 900,
    );

    final decision = resolveLocalSlipDecision(result);

    expect(decision?.type, TransactionType.internalTransfer);
    expect(decision?.categoryId, 'internal_transfer');
  });

  test(
    'treats matching short Thai names after honorific removal as internal transfer',
    () {
      final result = SlipScanResult(
        rawText: 'internal transfer',
        sender: 'นาย การ',
        recipient: 'นาย การ',
        amount: 900,
      );

      final decision = resolveLocalSlipDecision(result);

      expect(decision?.type, TransactionType.internalTransfer);
      expect(decision?.categoryId, 'internal_transfer');
    },
  );

  test(
    'treats OCR Thai vowel variants of the same real name as internal transfer',
    () {
      final result = SlipScanResult(
        rawText: 'SCB โอนเงินสำเร็จ จำนวนเงิน 26000.00',
        bankName: 'SCB EASY',
        sender: 'นาย ชีษณุชา ส.',
        recipient: 'นาย ชิษณุชา สมบูรณ์วรรณะ',
        amount: 26000,
        category: SlipCategory.detail,
      );

      final decision = resolveLocalSlipDecision(result);

      expect(decision?.type, TransactionType.internalTransfer);
      expect(decision?.categoryId, 'internal_transfer');
    },
  );

  test('does not treat biller recipient as internal transfer', () {
    final result = SlipScanResult(
      rawText: 'SCB จ่ายบิลสำเร็จ FOOD PATIO รหัสอ้างอิง 20260711',
      bankName: 'SCB EASY',
      sender: 'นาย ชิษณุชา ส.',
      recipient: 'FOOD PATIO',
      amount: 15,
      reference: '202607114IR0MVVXVGOK00BJI',
      category: SlipCategory.expense,
    );

    final decision = resolveLocalSlipDecision(result);

    expect(decision?.type, TransactionType.expense);
    expect(decision?.categoryId, 'food');
  });

  test('never classifies scanned slip text as income', () {
    final result = SlipScanResult(
      rawText: 'SCB credit deposit income received',
      bankName: 'SCB EASY',
      amount: 1200,
      category: SlipCategory.income,
    );

    final decision = resolveBestEffortSlipDecision(result);

    expect(decision?.type, TransactionType.expense);
    expect(decision?.categoryId, 'transfer');
  });

  test('uses merchant or bank transfer notes instead of person names', () {
    final merchantResult = SlipScanResult(
      rawText: 'SCB payment success PTT station reference 123456',
      bankName: 'SCB EASY',
      sender: 'Mr Somchai Jaidee',
      recipient: 'PTT',
      amount: 700,
      category: SlipCategory.expense,
    );
    final personResult = SlipScanResult(
      rawText: 'SCB transfer success',
      bankName: 'SCB EASY',
      sender: 'Mr Somchai Jaidee',
      recipient: 'Mr Somsak Dee',
      amount: 700,
      category: SlipCategory.expense,
    );

    expect(buildSlipNote(merchantResult), 'PTT');
    expect(buildSlipNote(personResult), 'SCB transfer');
  });
}
