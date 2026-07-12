import 'package:flutter_test/flutter_test.dart';
import 'package:kimjod/features/scan/slip_text_parser.dart';

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
}
