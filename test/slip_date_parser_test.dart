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

  test(
    'falls back to image date instead of today when slip date is missing',
    () {
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
    },
  );

  test(
    'uses embedded yyyymmdd from reference before falling back to image date',
    () {
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
    },
  );

  test('parses ISO year-month-day dates in the correct order', () {
    final result = parseTransactionDateFrom(
      dateText: '2026-07-16 18:57',
      now: DateTime(2026, 7, 18),
    );

    expect(result, DateTime(2026, 7, 16, 18, 57));
  });

  test('uses compact Dime reference date when OCR misses the printed date', () {
    final result = parseTransactionDateFrom(
      referenceText: 'DM260716115756000bybzjo',
      timeText: '18:57',
      fallbackDate: DateTime(2026, 7, 18),
    );

    expect(result, DateTime(2026, 7, 16, 18, 57));
  });

  test('uses compact Dime bill-payment reference date', () {
    final result = parseTransactionDateFrom(
      referenceText: 'DMBP260711092725000lthcyz',
      timeText: '16:27',
      fallbackDate: DateTime(2026, 7, 18),
    );

    expect(result, DateTime(2026, 7, 11, 16, 27));
  });

  test('interprets short Thai Buddhist year 69 as 2026', () {
    final result = parseTransactionDateFrom(
      dateText: '16 \u0E01.\u0E04. 69 - 18:57',
      now: DateTime(2026, 7, 18),
    );

    expect(result, DateTime(2026, 7, 16, 18, 57));
  });

  test('infers K PLUS dates from ordinal-day transaction references', () {
    const cases = <String, (int, int)>{
      '016074131303121885': (3, 15),
      '016076061753532455': (3, 17),
      '016077062242122112': (3, 18),
      '016078055253919954': (3, 19),
      '016130100551AOR01646': (5, 10),
      '016143111803BPM12044': (5, 23),
      '016169224906APM14938': (6, 18),
      '016190223328BPM01586': (7, 9),
    };

    for (final entry in cases.entries) {
      final result = parseTransactionDateFrom(
        referenceText: entry.key,
        fallbackDate: DateTime(2026, 7, 18),
      );

      expect(
        result,
        DateTime(2026, entry.value.$1, entry.value.$2),
        reason: entry.key,
      );
    }
  });
}
