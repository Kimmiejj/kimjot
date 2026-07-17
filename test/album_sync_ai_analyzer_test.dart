import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/features/scan/album_sync_ai_analyzer.dart';
import 'package:kimjot/features/scan/external_ai_client.dart';
import 'package:kimjot/features/scan/slip_scan_result.dart';
import 'package:kimjot/features/transactions/transaction_type.dart';

void main() {
  test('does not wait for AI when local rules detect an internal transfer', () async {
    var aiCalls = 0;
    const scanned = SlipScanResult(
      rawText: 'SCB transfer amount 100.00',
      sender: 'Mr Somchai Jaidee',
      recipient: 'Somchai',
      amount: 100,
    );

    final resolution = await analyzeAlbumSyncSlip(
      result: scanned,
      imagePath: 'slip.jpg',
      analyzeWithAi: (result, imagePath) async {
        aiCalls++;
        return const ExternalSlipAnalysis(
          type: TransactionType.expense,
          categoryId: 'shopping',
          amount: 125,
          dateText: '16/07/2026',
          sender: 'Merchant Account',
          recipient: 'KFC',
          confidence: 0.95,
        );
      },
    );

    expect(aiCalls, 0);
    expect(resolution.usedAi, isFalse);
    expect(resolution.result.amount, 100);
    expect(resolution.result.dateText, isNull);
    expect(resolution.decision?.type, TransactionType.internalTransfer);
  });

  test('falls back to the local decision when AI is unavailable', () async {
    const scanned = SlipScanResult(
      rawText: 'SCB transfer amount 80.00',
      bankName: 'SCB',
      amount: 80,
      category: SlipCategory.expense,
    );

    final resolution = await analyzeAlbumSyncSlip(
      result: scanned,
      imagePath: 'slip.jpg',
      analyzeWithAi: (result, imagePath) async => null,
    );

    expect(resolution.usedAi, isFalse);
    expect(resolution.result.amount, 80);
    expect(resolution.decision, isNotNull);
  });
}
