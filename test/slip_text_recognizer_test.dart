import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/features/scan/slip_text_recognizer.dart';
import 'package:kimjot/features/scan/slip_transaction_resolver.dart';
import 'package:kimjot/features/transactions/transaction_type.dart';

void main() {
  test(
    'merges OCR text so same-name transfer survives best amount result',
    () async {
      final recognizer = SlipTextRecognizer();

      final result = await recognizer.parseRawTexts(const [
        '''
SCB
โอนเงินสำเร็จ
25 มิ.ย. 2569 - 06:09
รหัสอ้างอิง: 202606250UKVQD6yqY9olW8kK
จำนวนเงิน
26,000.00
''',
        '''
จาก
นาย ชิษณุชา ส.
xxx-xxx899-2
ไปยัง
นาย ชิษณุชา สมบูรณ์วรรณะ
x-4365
''',
      ]);

      final decision = resolveBestEffortSlipDecision(result);

      expect(result.amount, 26000);
      expect(result.rawText, contains('ชิษณุชา'));
      expect(decision?.type, TransactionType.internalTransfer);
      expect(decision?.categoryId, 'internal_transfer');
    },
  );

  test('merges an OCR-misread Thai title from the sender crop', () async {
    final recognizer = SlipTextRecognizer();

    final result = await recognizer.parseRawTexts(const [
      '\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08\n'
          '\u0E08\u0E32\u0E01 @ uw dune.\n'
          '\u0E44\u0E1B\u0E22\u0E31\u0E07 \u0E19\u0E32\u0E22 \u0E0A\u0E34\u0E29\u0E13\u0E38\u0E0A\u0E32 '
          '\u0E2A\u0E21\u0E1A\u0E39\u0E23\u0E13\u0E4C\u0E27\u0E23\u0E23\u0E13\u0E30\n'
          '\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19 26,000.00',
      '@ \u0E07\u0E32\u0E22\u0E0A\u0E34\u0E29\u0E13\u0E38\u0E0A\u0E32 \u0E2A.\nXXX-XXX899-2',
    ]);

    final decision = resolveBestEffortSlipDecision(result);

    expect(result.amount, 26000);
    expect(decision?.type, TransactionType.internalTransfer);
    expect(decision?.categoryId, 'internal_transfer');
  });
}
