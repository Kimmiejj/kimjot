DateTime parseTransactionDateFrom({
  String? dateText,
  String? timeText,
  String? referenceText,
  String? rawText,
  DateTime? fallbackDate,
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  final normalizedDateText = _normalizeDateText(dateText);
  final extractedTime = _extractTimeValue(normalizedDateText);
  final resolvedTimeText = _normalizeTimeText(timeText) ?? extractedTime;
  final parsedTime = _parseTimeParts(resolvedTimeText);

  if (normalizedDateText != null) {
    final cleanedDateText = _removeTimeFromDateText(normalizedDateText);
    final parsedDate = _parseDate(cleanedDateText);
    if (parsedDate != null) {
      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        parsedTime.hour,
        parsedTime.minute,
        parsedTime.second,
      );
    }
  }

  final inferredDate =
      _parseDateFromReferenceText(
        referenceText,
        assumedYear: (fallbackDate ?? resolvedNow).year,
      ) ??
      _parseDateFromReferenceText(
        rawText,
        assumedYear: (fallbackDate ?? resolvedNow).year,
      );
  if (inferredDate != null) {
    return DateTime(
      inferredDate.year,
      inferredDate.month,
      inferredDate.day,
      parsedTime.hour,
      parsedTime.minute,
      parsedTime.second,
    );
  }

  final baseDate = fallbackDate ?? resolvedNow;
  return DateTime(
    baseDate.year,
    baseDate.month,
    baseDate.day,
    parsedTime.hour,
    parsedTime.minute,
    parsedTime.second,
  );
}

DateTime? _parseDateFromReferenceText(
  String? value, {
  required int assumedYear,
}) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  final kPlusMatch = RegExp(r'\b016(\d{3})(\d{2})(\d{2})').firstMatch(value);
  if (kPlusMatch != null) {
    final ordinalDay = int.parse(kPlusMatch.group(1)!);
    final firstDay = DateTime(assumedYear);
    final date = firstDay.add(Duration(days: ordinalDay - 1));
    if (ordinalDay >= 1 && ordinalDay <= 366 && date.year == assumedYear) {
      return date;
    }
  }

  final fullYearMatch = RegExp(
    r'((?:19|20|21|24|25)\d{2})(\d{2})(\d{2})',
  ).firstMatch(value);
  if (fullYearMatch != null) {
    final fullYearDate = _buildDate(
      year: int.parse(fullYearMatch.group(1)!),
      month: int.parse(fullYearMatch.group(2)!),
      day: int.parse(fullYearMatch.group(3)!),
    );
    if (fullYearDate != null) return fullYearDate;
  }

  final dimeMatch = RegExp(
    r'\bDMBP(\d{2})(\d{2})(\d{2})|\bDM(\d{2})(\d{2})(\d{2})',
    caseSensitive: false,
  ).firstMatch(value);
  if (dimeMatch == null) return null;

  final isBillPayment = dimeMatch.group(1) != null;
  return _buildDate(
    year: 2000 + int.parse(dimeMatch.group(isBillPayment ? 1 : 4)!),
    month: int.parse(dimeMatch.group(isBillPayment ? 2 : 5)!),
    day: int.parse(dimeMatch.group(isBillPayment ? 3 : 6)!),
  );
}

DateTime? _parseDate(String dateText) {
  final normalized = dateText.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final yearMonthDayMatch = RegExp(
    r'(?<!\d)((?:19|20|21|24|25)\d{2})\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{1,2})(?!\d)',
  ).firstMatch(normalized);
  if (yearMonthDayMatch != null) {
    return _buildDate(
      day: int.parse(yearMonthDayMatch.group(3)!),
      month: int.parse(yearMonthDayMatch.group(2)!),
      year: int.parse(yearMonthDayMatch.group(1)!),
    );
  }

  final dayMonthYearMatch = RegExp(
    r'(?<!\d)(\d{1,2})\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{2,4})(?!\d)',
  ).firstMatch(normalized);
  if (dayMonthYearMatch != null) {
    return _buildDate(
      day: int.parse(dayMonthYearMatch.group(1)!),
      month: int.parse(dayMonthYearMatch.group(2)!),
      year: int.parse(dayMonthYearMatch.group(3)!),
    );
  }

  final englishMatch = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{2,4})',
  ).firstMatch(normalized);
  if (englishMatch != null) {
    final month = _englishMonths[englishMatch.group(2)!.toLowerCase()];
    if (month != null) {
      return _buildDate(
        day: int.parse(englishMatch.group(1)!),
        month: month,
        year: int.parse(englishMatch.group(3)!),
      );
    }
  }

  final thaiMatch = RegExp(
    r'(\d{1,2})\s*([\u0E00-\u0E7F.]{2,20})\s*(\d{2,4})',
  ).firstMatch(normalized);
  if (thaiMatch != null) {
    final month = _thaiMonths[_normalizeThaiMonthKey(thaiMatch.group(2)!)];
    if (month != null) {
      return _buildDate(
        day: int.parse(thaiMatch.group(1)!),
        month: month,
        year: int.parse(thaiMatch.group(3)!),
      );
    }
  }

  return null;
}

DateTime? _buildDate({
  required int day,
  required int month,
  required int year,
}) {
  final normalizedYear = _normalizeYear(year);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }

  try {
    final parsed = DateTime(normalizedYear, month, day);
    if (parsed.year != normalizedYear ||
        parsed.month != month ||
        parsed.day != day) {
      return null;
    }
    return parsed;
  } catch (_) {
    return null;
  }
}

int _normalizeYear(int year) {
  if (year > 2400) {
    return year - 543;
  }
  if (year < 100) {
    return year < 50 ? year + 2000 : year + 1957;
  }
  return year;
}

({int hour, int minute, int second}) _parseTimeParts(String? timeText) {
  if (timeText == null || timeText.isEmpty) {
    return (hour: 0, minute: 0, second: 0);
  }

  final parts = timeText.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  return (
    hour: hour.clamp(0, 23),
    minute: minute.clamp(0, 59),
    second: second.clamp(0, 59),
  );
}

String? _normalizeDateText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return trimmed
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-');
}

String? _normalizeTimeText(String? value) {
  return RegExp(
    r'(\d{1,2}:\d{2}(?::\d{2})?)',
  ).firstMatch(value ?? '')?.group(1);
}

String? _extractTimeValue(String? dateText) {
  if (dateText == null) {
    return null;
  }

  return RegExp(r'(\d{1,2}:\d{2}(?::\d{2})?)').firstMatch(dateText)?.group(1);
}

String _removeTimeFromDateText(String dateText) {
  return dateText
      .replaceAll(RegExp(r'(\d{1,2}:\d{2}(?::\d{2})?)'), ' ')
      .replaceAll(RegExp(r'\s+-\s+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeThaiMonthKey(String value) {
  return value.replaceAll('.', '').trim();
}

const Map<String, int> _englishMonths = {
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

const Map<String, int> _thaiMonths = {
  '\u0E21\u0E04': 1,
  '\u0E21\u0E01\u0E23\u0E32\u0E04\u0E21': 1,
  '\u0E01\u0E1E': 2,
  '\u0E01\u0E38\u0E21\u0E20\u0E32\u0E1E\u0E31\u0E19\u0E18\u0E4C': 2,
  '\u0E21\u0E35\u0E04': 3,
  '\u0E21\u0E35\u0E19\u0E32\u0E04\u0E21': 3,
  '\u0E40\u0E21\u0E22': 4,
  '\u0E40\u0E21\u0E29\u0E32\u0E22\u0E19': 4,
  '\u0E1E\u0E04': 5,
  '\u0E1E\u0E24\u0E29\u0E20\u0E32\u0E04\u0E21': 5,
  '\u0E21\u0E34\u0E22': 6,
  '\u0E21\u0E34\u0E16\u0E38\u0E19\u0E32\u0E22\u0E19': 6,
  '\u0E01\u0E04': 7,
  '\u0E01\u0E23\u0E01\u0E0E\u0E32\u0E04\u0E21': 7,
  '\u0E2A\u0E04': 8,
  '\u0E2A\u0E34\u0E07\u0E2B\u0E32\u0E04\u0E21': 8,
  '\u0E01\u0E22': 9,
  '\u0E01\u0E31\u0E19\u0E22\u0E32\u0E22\u0E19': 9,
  '\u0E15\u0E04': 10,
  '\u0E15\u0E38\u0E25\u0E32\u0E04\u0E21': 10,
  '\u0E1E\u0E22': 11,
  '\u0E1E\u0E24\u0E28\u0E08\u0E34\u0E01\u0E32\u0E22\u0E19': 11,
  '\u0E18\u0E04': 12,
  '\u0E18\u0E31\u0E19\u0E27\u0E32\u0E04\u0E21': 12,
};
