import 'package:flutter_test/flutter_test.dart';
import 'package:kimjod/features/scan/slip_text_parser.dart';
import 'package:kimjod/features/scan/slip_transaction_resolver.dart';
import 'package:kimjod/features/transactions/transaction_type.dart';

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

  test('extracts sender and recipient names from SCB style from and to blocks', () {
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

  test('classifies SCB FOOD PATIO bill as expense and not internal transfer', () {
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
  });

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

  test('classifies KBank stacked transfer with matching name part as internal transfer', () {
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
  });

  test('does not classify KBank bill payment as internal transfer when names do not overlap', () {
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
  });

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
