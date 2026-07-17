import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/features/scan/slip_amount_classifier.dart';
import 'package:kimjot/features/scan/slip_text_parser.dart';
import 'package:kimjot/features/scan/slip_transaction_resolver.dart';
import 'package:kimjot/features/transactions/transaction_type.dart';

void main() {
  final parser = SlipTextParser();

  test('uses the number followed by baht as the slip amount', () {
    final result = parser.parse('''
K PLUS
เลขที่รายการ 20260111123456789
โอนเงินสำเร็จ
200 บาท
''');

    expect(result.amount, 200);
  });

  test('reads the new K PLUS top-up slips without choosing ids or fees', () {
    const cases = <(String, String, String, double)>[
      ('15 มี.ค. 69', '016074131303121885', '5,000.00', 5000),
      ('17 มี.ค. 69', '016076061753532455', '3,000.00', 3000),
      ('18 มี.ค. 69', '016077062242122112', '1,500.00', 1500),
      ('19 มี.ค. 69', '016078055253919954', '4,000.00', 4000),
    ];

    for (final item in cases) {
      final result = parser.parse('''
K+
เติมเงินสำเร็จ
${item.$1} 13:13 น.
นาย ชิษณุชา ส
ธ.กสิกรไทย
xxx-x-x0253-x
YouTrip Powered by KBank
66927755452
KT19949455
เลขที่รายการ:
${item.$2}
จำนวน:
${item.$3} บาท
ค่าธรรมเนียม:
0.00 บาท
''');

      expect(result.bankName, 'K PLUS', reason: item.$2);
      expect(result.amount, item.$4, reason: item.$2);
      expect(result.dateText, item.$1, reason: item.$2);
      expect(result.reference, item.$2, reason: item.$2);
    }
  });

  test('reads the new K PLUS TrueMoney top-up amount', () {
    final result = parser.parse('''
K+
เติมเงินสำเร็จ
18 มิ.ย. 69 22:49 น.
นาย ชิษณุชา ส
ธ.กสิกรไทย
xxx-x-x0253-x
TrueMoney Wallet
0927755452
เลขที่รายการ:
016169224906APM14938
จำนวน:
100.00 บาท
ค่าธรรมเนียม:
0.00 บาท
''');

    expect(result.bankName, 'K PLUS');
    expect(result.amount, 100);
    expect(result.dateText, '18 มิ.ย. 69');
    expect(result.reference, '016169224906APM14938');
  });

  test('reads the new K PLUS bill amount instead of biller numbers', () {
    final result = parser.parse('''
K+
จ่ายบิลสำเร็จ
23 พ.ค. 69 11:18 น.
นาย ชิษณุชา ส
ธ.กสิกรไทย
xxx-x-x0253-x
องค์การขนส่งมวลชนกรุงเทพ
00561210000000004-12
00567052000000040040
เลขที่รายการ:
016143111803BPM12044
จำนวน:
8.00 บาท
ค่าธรรมเนียม:
0.00 บาท
''');

    final decision = resolveLocalSlipDecision(result);

    expect(result.bankName, 'K PLUS');
    expect(result.amount, 8);
    expect(result.dateText, '23 พ.ค. 69');
    expect(result.reference, '016143111803BPM12044');
    expect(decision?.type, isNot(TransactionType.internalTransfer));
  });

  test('uses the number near amount label as the slip amount', () {
    final result = parser.parse('''
SCB EASY
Transaction ID 123456789012
จำนวนเงิน
200.00
บาท
''');

    expect(result.amount, 200);
  });

  test('detects Thai slip dates like SCB receipt headers', () {
    final result = parser.parse('''
SCB
11 ก.ค. 2569 - 14:39
รหัสอ้างอิง: 2026071114
''');

    expect(result.dateText, '11 ก.ค. 2569');
    expect(result.timeText, '14:39');
  });

  test('detects ISO dates without treating the year suffix as the day', () {
    final result = parser.parse('''
Dime!
Date 2026-07-16 18:57
Transfer 1,578.25 THB
''');

    expect(result.dateText, '2026-07-16');
    expect(result.timeText, '18:57');
  });

  test('uses PaoTang paid amount after subsidy instead of the deduction', () {
    final rawText = '''
เป๋าตัง
16 ก.ค. 2569 12:22 น.
ค่าสินค้า/บริการ
50 บาท
สิทธิไทยช่วยไทยพลัส
-30 บาท
จำนวนเงินที่ชำระ
20 บาท
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 20);
    expect(candidates, [50, 20]);
  });

  test('uses PaoTang paid amount when OCR drops the subsidy minus sign', () {
    final result = parser.parse('''
เป๋าตัง
ค่าสินค้า/บริการ 50 บาท
สิทธิไทยช่วยไทยพลัส
30 บาท
จำนวนเงินที่ชำระ
20 บาท
''');

    expect(result.amount, 20);
  });

  test('uses Dime transfer amount instead of its zero fee', () {
    final result = parser.parse('''
Dime!
โอนเงิน
1,578.25 บาท
ค่าธรรมเนียม 0.00 บาท
วันที่ 16 ก.ค. 2569 - 18:57 น.
เลขที่สลิป DM260716115756000bybzjo
''');

    expect(result.amount, 1578.25);
    expect(result.dateText, '16 ก.ค. 2569');
    expect(result.bankName, 'Dime!');
  });

  test('uses the THB side of a Dime currency exchange', () {
    final result = parser.parse('''
Dime!
แลกเปลี่ยน
60.61 USD
เป็น
1,990.43 THB
อัตราแลกเปลี่ยน 1 USD = 32.84 THB
วันที่ส่งคำสั่ง 10 มิ.ย. 69 - 20:20 น.
เลขที่คำสั่ง FX202606101320415835069
''');

    expect(result.amount, 1990.43);
    expect(result.dateText, '10 มิ.ย. 69');
  });

  test('uses Dime stock order total instead of commission and coupon', () {
    final result = parser.parse('''
Dime!
ซื้อ IVV
59,999.83 THB
มูลค่าหุ้น 59,999.83 THB
ค่าคอมมิชชัน 90.10 THB
คูปองส่วนลด
รายการฟรีของเดือน -90.10 THB
ภาษีมูลค่าเพิ่ม 7% (VAT) 0.00 THB
อัตราแลกเปลี่ยน 1 USD = 32.68 THB
จำนวนเงิน (USD) 1,835.98 USD
วันที่ส่งคำสั่ง 27 พ.ค. 69 - 09:46 น.
''');

    expect(result.amount, 59999.83);
    expect(result.dateText, '27 พ.ค. 69');
  });

  test(
    'extracts sender and recipient names from SCB style from and to blocks',
    () {
      final result = parser.parse('''
SCB
โอนเงินสำเร็จ
25 มิ.ย. 2569 - 06:09
รหัสอ้างอิง: 202606250UKVQD6yqY9oIW8kK
จาก
นาย ชิษณุชา ส.
xxx-xxx899-2
ไปยัง
นาย ชิษณุชา สมบูรณ์วรรณะ
x-4365
จำนวนเงิน
26,000.00
''');

      expect(result.sender, 'นาย ชิษณุชา ส.');
      expect(result.recipient, 'นาย ชิษณุชา สมบูรณ์วรรณะ');
      expect(result.amount, 26000);
    },
  );

  test('uses SCB amount row instead of reference or account digits', () {
    final rawText = '''
SCB
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
25 \u0E21\u0E34.\u0E22. 2569 - 06:09
\u0E23\u0E2B\u0E31\u0E2A\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07: 202606250UKVQD6yqY9oIW8kK
\u0E08\u0E32\u0E01
\u0E19\u0E32\u0E22 \u0E0A\u0E34\u0E29\u0E13\u0E38\u0E0A\u0E32 \u0E2A.
xxx-xxx899-2
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E19\u0E32\u0E22 \u0E0A\u0E34\u0E29\u0E13\u0E38\u0E0A\u0E32 \u0E2A\u0E21\u0E1A\u0E39\u0E23\u0E13\u0E4C\u0E27\u0E23\u0E23\u0E13\u0E30
x-4365
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
26,000.00
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 26000);
    expect(result.reference, '202606250UKVQD6yqY9oIW8kK');
    expect(candidates, [26000]);
  });

  test('ignores stray one-digit OCR noise near amount labels', () {
    final rawText = '''
K+
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
10 \u0E1E.\u0E04. 69 10:05 \u0E19.
\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48\u0E23\u0E32\u0E22\u0E01\u0E32\u0E23:
016130100551AOR01646
\u0E08\u0E33\u0E19\u0E27\u0E19:
2
100.00 \u0E1A\u0E32\u0E17
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 100);
    expect(candidates, [100]);
  });

  test('uses SCB bill payment amount row instead of customer numbers', () {
    final rawText = '''
SCB
\u0E08\u0E48\u0E32\u0E22\u0E1A\u0E34\u0E25\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
14 \u0E21\u0E34.\u0E22. 2569 - 20:12
\u0E23\u0E2B\u0E31\u0E2A\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07: 202606142I2Xi0FRo7NnnxPMf
\u0E44\u0E1B\u0E22\u0E31\u0E07
MOL Payment2
\u0E1A\u0E31\u0E0D\u0E0A\u0E35\u0E23\u0E31\u0E1A\u0E0A\u0E33\u0E23\u0E30 : xxx-xxx879-0
\u0E2B\u0E21\u0E32\u0E22\u0E40\u0E25\u0E02\u0E25\u0E39\u0E01\u0E04\u0E49\u0E32 : 6180547
\u0E2B\u0E21\u0E32\u0E22\u0E40\u0E25\u0E02\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07 : 3782350248
\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48\u0E23\u0E32\u0E22\u0E01\u0E32\u0E23 :
L260614201233A6STB45
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
100.00
\u0E04\u0E48\u0E32\u0E18\u0E23\u0E23\u0E21\u0E40\u0E19\u0E35\u0E22\u0E21
10.00
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 100);
    expect(candidates, [100]);
  });

  test('uses SCB transfer amount instead of recipient masked account', () {
    final rawText = '''
SCB
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
11 \u0E21\u0E34.\u0E22. 2569 - 19:03
\u0E23\u0E2B\u0E31\u0E2A\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07: 202606118MZiuiJUAqwCtQy26
\u0E08\u0E32\u0E01
\u0E19\u0E32\u0E22 \u0E0A\u0E35\u0E29\u0E13\u0E38\u0E0A\u0E32 \u0E2A.
xxx-xxx899-2
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E19\u0E32\u0E22\u0E01\u0E21\u0E25 \u0E1E\u0E27\u0E07\u0E1A\u0E38\u0E1B\u0E1C\u0E32
x-5899
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
50.00
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 50);
    expect(candidates, [50]);
  });

  test(
    'uses same-line SCB amount label instead of recipient account suffix',
    () {
      final rawText = '''
SCB
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E19\u0E32\u0E22\u0E01\u0E21\u0E25 \u0E1E\u0E27\u0E07\u0E1A\u0E38\u0E1B\u0E1C\u0E32
x-5899
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19     50.00
''';

      final result = parser.parse(rawText);
      final candidates = AmountClassifier.instance
          .extractCandidateContexts(rawText)
          .map((context) => context.value)
          .toList();

      expect(result.amount, 50);
      expect(candidates, [50]);
    },
  );

  test('ignores recipient account suffix even when OCR drops the x', () {
    for (final accountLine in ['x-5899', '-5899', '5899']) {
      final rawText =
          '''
SCB
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E19\u0E32\u0E22\u0E01\u0E21\u0E25 \u0E1E\u0E27\u0E07\u0E1A\u0E38\u0E1B\u0E1C\u0E32
$accountLine
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
50.00
''';

      final result = parser.parse(rawText);
      final candidates = AmountClassifier.instance
          .extractCandidateContexts(rawText)
          .map((context) => context.value)
          .toList();

      expect(result.amount, 50, reason: accountLine);
      expect(candidates, [50], reason: accountLine);
    }
  });

  test('uses amount when OCR reads amount before a decomposed Thai label', () {
    final rawText = '''
SCB
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E19\u0E32\u0E22\u0E01\u0E21\u0E25 \u0E1E\u0E27\u0E07\u0E1A\u0E38\u0E1B\u0E1C\u0E32
x-5899
50.00
\u0E08\u0E4D\u0E32\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 50);
    expect(candidates, [50]);
  });

  test('uses amount when OCR inserts spaces in the Thai amount label', () {
    final rawText = '''
SCB
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E19\u0E32\u0E22\u0E01\u0E21\u0E25 \u0E1E\u0E27\u0E07\u0E1A\u0E38\u0E1B\u0E1C\u0E32
x-5899
\u0E08 \u0E4D \u0E32 \u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
50.00
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 50);
    expect(candidates, [50]);
  });

  test('uses SCB QR payment amount instead of merchant code', () {
    final rawText = '''
SCB
\u0E08\u0E48\u0E32\u0E22\u0E1A\u0E34\u0E25\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
11 \u0E21\u0E34.\u0E22. 2569 - 18:52
\u0E23\u0E2B\u0E31\u0E2A\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07: 202606118ILidd1V7WroPiNAE
\u0E08\u0E32\u0E01
\u0E19\u0E32\u0E22 \u0E0A\u0E35\u0E29\u0E13\u0E38\u0E0A\u0E32 \u0E2A.
xxx-xxx899-2
\u0E44\u0E1B\u0E22\u0E31\u0E07
QR Payment at BTS
Biller ID : 010753600031501
\u0E23\u0E2B\u0E31\u0E2A\u0E23\u0E49\u0E32\u0E19\u0E04\u0E49\u0E32 : KB0000001525759
\u0E23\u0E2B\u0E31\u0E2A\u0E18\u0E38\u0E23\u0E01\u0E23\u0E23\u0E21 : APIC1781178747630ROY
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
19.00
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 19);
    expect(candidates, [19]);
  });

  test('uses SCB bill amount instead of merchant name number', () {
    final rawText = '''
SCB
\u0E08\u0E48\u0E32\u0E22\u0E1A\u0E34\u0E25\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
18 \u0E21\u0E34.\u0E22. 2569 - 15:02
\u0E23\u0E2B\u0E31\u0E2A\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07: 202606184laIlzOPAQHsGrpa3
\u0E08\u0E32\u0E01
\u0E19\u0E32\u0E22 \u0E0A\u0E35\u0E29\u0E13\u0E38\u0E0A\u0E32 \u0E2A.
xxx-xxx893-6
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E41\u0E21\u0E04\u0E42\u0E14\u0E19\u0E31\u0E25\u0E14\u0E4C-00041 \u0E40\u0E2D\u0E2A \u0E0B\u0E35 \u0E1A\u0E35 \u0E1E\u0E32\u0E23\u0E4C
Biller ID : 010753600031501
\u0E23\u0E2B\u0E31\u0E2A\u0E23\u0E49\u0E32\u0E19\u0E04\u0E49\u0E32 : 401015897276001
\u0E23\u0E2B\u0E31\u0E2A\u0E18\u0E38\u0E23\u0E01\u0E23\u0E23\u0E21 : EDC17817697037296685
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
29.00
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 29);
    expect(candidates, [29]);
  });

  test('does not hard-code merchant branch number as a specific amount', () {
    final rawText = '''
SCB
\u0E08\u0E48\u0E32\u0E22\u0E1A\u0E34\u0E25\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E41\u0E21\u0E04\u0E42\u0E14\u0E19\u0E31\u0E25\u0E14\u0E4C-00041 \u0E40\u0E2D\u0E2A \u0E0B\u0E35 \u0E1A\u0E35 \u0E1E\u0E32\u0E23\u0E4C
\u0E23\u0E2B\u0E31\u0E2A\u0E23\u0E49\u0E32\u0E19\u0E04\u0E49\u0E32 : 401015897276001
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19 37.00 \u0E1A\u0E32\u0E17
''';

    final result = parser.parse(rawText);
    final candidates = AmountClassifier.instance
        .extractCandidateContexts(rawText)
        .map((context) => context.value)
        .toList();

    expect(result.amount, 37);
    expect(candidates, [37]);
  });

  test(
    'keeps explicit SCB transfer amount when external suggestion chooses account',
    () {
      final result = parser.parse(
        '''
SCB
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E19\u0E32\u0E22\u0E01\u0E21\u0E25 \u0E1E\u0E27\u0E07\u0E1A\u0E38\u0E1B\u0E1C\u0E32
x-5899
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
50.00
''',
        suggestedAmount: 5899,
        suggestedConfidence: 0.99,
      );

      expect(result.amount, 50);
    },
  );

  test('rejects external account suggestion when no amount context exists', () {
    final result = parser.parse(
      '''
SCB
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E19\u0E32\u0E22\u0E01\u0E21\u0E25 \u0E1E\u0E27\u0E07\u0E1A\u0E38\u0E1B\u0E1C\u0E32
x-5899
''',
      suggestedAmount: 5899,
      suggestedConfidence: 0.99,
    );

    expect(result.amount, isNull);
  });

  test('rejects external account suggestion next to an amount label', () {
    final result = parser.parse(
      '''
SCB
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
\u0E44\u0E1B\u0E22\u0E31\u0E07
\u0E19\u0E32\u0E22\u0E01\u0E21\u0E25 \u0E1E\u0E27\u0E07\u0E1A\u0E38\u0E1B\u0E1C\u0E32
x-5899
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
''',
      suggestedAmount: 5899,
      suggestedConfidence: 0.99,
    );

    expect(result.amount, isNull);
  });

  test(
    'keeps explicit SCB amount when external suggestion chooses metadata',
    () {
      final result = parser.parse(
        '''
SCB
\u0E08\u0E48\u0E32\u0E22\u0E1A\u0E34\u0E25\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
QR Payment at BTS
\u0E23\u0E2B\u0E31\u0E2A\u0E23\u0E49\u0E32\u0E19\u0E04\u0E49\u0E32 : KB0000001525759
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19
19.00
''',
        suggestedAmount: 1525759,
        suggestedConfidence: 0.99,
      );

      expect(result.amount, 19);
    },
  );

  test(
    'uses Thai amount and baht text instead of transfer metadata numbers',
    () {
      final result = parser.parse('''
K+
\u0E42\u0E2D\u0E19\u0E40\u0E07\u0E34\u0E19\u0E2A\u0E33\u0E40\u0E23\u0E47\u0E08
10 \u0E1E.\u0E04. 69 10:05 \u0E19.
\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48\u0E23\u0E32\u0E22\u0E01\u0E32\u0E23:
016130100551AOR01646
xxx-x-x0253-x
x-4365
\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19 100 \u0E1A\u0E32\u0E17
''');

      expect(result.amount, 100);
    },
  );

  test('uses English amount and THB text instead of ids', () {
    final result = parser.parse('''
SCB EASY
Transaction ID 991234567890
Merchant ID KB000002203311
Amount
396.00 THB
Reference 202607114iR0mvvXVGOK00Bjl
''');

    expect(result.amount, 396);
  });

  test('classifies SCB same-name transfer as internal transfer', () {
    final result = parser.parse('''
SCB
โอนเงินสำเร็จ
25 มิ.ย. 2569 - 06:09
รหัสอ้างอิง: 202606250UKVQD6yqY9oIW8kK
จาก
นาย ชิษณุชา ส.
xxx-xxx899-2
ไปยัง
นาย ชิษณุชา สมบูรณ์วรรณะ
x-4365
จำนวนเงิน
26,000.00
''');

    final decision = resolveLocalSlipDecision(result);

    expect(decision?.type, TransactionType.internalTransfer);
    expect(decision?.categoryId, 'internal_transfer');
  });

  test(
    'classifies SCB FOOD PATIO bill as expense and not internal transfer',
    () {
      final result = parser.parse('''
SCB
จ่ายบิลสำเร็จ
11 ก.ค. 2569 - 14:39
รหัสอ้างอิง: 202607114iR0mvvXVGOK00Bjl
จาก
นาย ชิษณุชา ส.
xxx-xxx893-6
ไปยัง
FOOD PATIO
Biller ID : 010753600031501
รหัสร้านค้า : KB000002203311
รหัสธุรกรรม : APIC1783755583516JHM
จำนวนเงิน
15.00
''');

      final decision = resolveLocalSlipDecision(result);

      expect(result.sender, 'นาย ชิษณุชา ส.');
      expect(result.recipient, 'FOOD PATIO');
      expect(result.amount, 15);
      expect(decision?.type, TransactionType.expense);
      expect(decision?.type, isNot(TransactionType.internalTransfer));
      expect(decision?.categoryId, 'food');
    },
  );

  test('extracts sender and recipient from KBank stacked transfer layout', () {
    final result = parser.parse('''
K+
โอนเงินสำเร็จ
10 พ.ค. 69 10:05 น.
นาย ชิษณุชา ส
ธ.กสิกรไทย
xxx-x-x0253-x
นาย ชิษณุชา สมบูรณ์วรรณะ
ธ.ไทยพาณิชย์
xxx-x-x8893-x
เลขที่รายการ:
016130100551AOR01646
จำนวน:
100.00 บาท
''');

    expect(result.sender, 'นาย ชิษณุชา ส');
    expect(result.recipient, 'นาย ชิษณุชา สมบูรณ์วรรณะ');
  });

  test(
    'classifies KBank stacked transfer with matching name part as internal transfer',
    () {
      final result = parser.parse('''
K+
โอนเงินสำเร็จ
10 พ.ค. 69 10:05 น.
นาย ชิษณุชา ส
ธ.กสิกรไทย
xxx-x-x0253-x
นาย ชิษณุชา สมบูรณ์วรรณะ
ธ.ไทยพาณิชย์
xxx-x-x8893-x
เลขที่รายการ:
016130100551AOR01646
จำนวน:
100.00 บาท
''');

      final decision = resolveLocalSlipDecision(result);

      expect(decision?.type, TransactionType.internalTransfer);
      expect(decision?.categoryId, 'internal_transfer');
    },
  );

  test(
    'does not classify KBank bill payment as internal transfer when names do not overlap',
    () {
      final result = parser.parse('''
K+
จ่ายบิลสำเร็จ
9 ก.ค. 69 22:33 น.
นาย ชิษณุชา ส
ธ.กสิกรไทย
xxx-x-x0253-x
องค์กรขนส่งมวลชนกรุงเทพ
00662162004X18NGV489
006621450000000070121
เลขที่รายการ:
016190223328BPM01586
จำนวน:
25.00 บาท
''');

      final decision = resolveLocalSlipDecision(result);

      expect(result.sender, 'นาย ชิษณุชา ส');
      expect(result.recipient, 'องค์กรขนส่งมวลชนกรุงเทพ');
      expect(result.amount, 25);
      expect(decision?.type, isNot(TransactionType.internalTransfer));
    },
  );

  test('repairs mojibake Thai OCR text before parsing', () {
    final result = parser.parse('''
SCB
à¹‚à¸­à¸™à¹€à¸‡à¸´à¸™à¸ªà¸³à¹€à¸£à¹‡à¸ˆ
à¸ˆà¸²à¸
à¸™à¸²à¸¢ à¸à¸²à¸£
à¹„à¸›à¸¢à¸±à¸‡
à¸™à¸²à¸¢ à¸à¸²à¸£
à¸ˆà¸³à¸™à¸§à¸™à¹€à¸‡à¸´à¸™
99.00
''');

    final decision = resolveLocalSlipDecision(result);

    expect(result.sender, 'นาย การ');
    expect(result.recipient, 'นาย การ');
    expect(decision?.type, TransactionType.internalTransfer);
  });
}
