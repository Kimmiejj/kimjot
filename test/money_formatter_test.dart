import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/shared/formatters/money_formatter.dart';

void main() {
  test('rounds and displays every amount with two decimal places', () {
    expect(formatOriginalNumber(1234.5678), '1,234.57');
    expect(formatOriginalNumber(99.999), '100.00');
    expect(formatOriginalNumber(1200), '1,200.00');
  });

  test('formats signed money and normalizes values before persistence', () {
    expect(formatOriginalMoney(-45.25), '-THB 45.25');
    expect(normalizeMoneyAmount(10.126), 10.13);
    expect(normalizeMoneyAmount(10.124), 10.12);
  });
}
