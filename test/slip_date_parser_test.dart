import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/features/scan/slip_date_parser.dart';

void main() {
  test('parses Thai Buddhist Era date from slip text', () {
    final result = parseTransactionDateFrom(
      dateText: '11 ก.ค. 2569 - 14:39',
      now: DateTime(2026, 7, 12),
    );

    expect(result.year, 2026);
    expect(result.month, 7);
    expect(result.day, 11);
    expect(result.hour, 14);
    expect(result.minute, 39);
  });

  test('falls back to image date instead of today when slip date is missing', () {
    final fallback = DateTime(2026, 5, 9, 18, 20);
    final result = parseTransactionDateFrom(
      timeText: '08:12',
      fallbackDate: fallback,
      now: DateTime(2026, 7, 12, 10, 0),
    );

    expect(result.year, 2026);
    expect(result.month, 5);
    expect(result.day, 9);
    expect(result.hour, 8);
    expect(result.minute, 12);
  });

  test('uses embedded yyyymmdd from reference before falling back to image date', () {
    final fallback = DateTime(2026, 7, 12, 9, 0);
    final result = parseTransactionDateFrom(
      timeText: '14:39',
      referenceText: '2026071114IROmvvXVGoK00BjI',
      fallbackDate: fallback,
      now: DateTime(2026, 7, 12, 10, 0),
    );

    expect(result.year, 2026);
    expect(result.month, 7);
    expect(result.day, 11);
    expect(result.hour, 14);
    expect(result.minute, 39);
  });
}
