import 'package:flutter_test/flutter_test.dart';
import 'package:kimjod/features/scan/slip_text_recognizer.dart';
import 'package:kimjod/features/scan/slip_transaction_resolver.dart';
import 'package:kimjod/features/transactions/transaction_type.dart';

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
}
