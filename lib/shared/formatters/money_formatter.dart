String formatOriginalNumber(double value) {
  final text = value.abs().toStringAsFixed(2);
  final parts = text.split('.');
  final whole = _addThousandsSeparators(parts.first);
  return '$whole.${parts[1]}';
}

double normalizeMoneyAmount(double value) {
  return double.parse(value.toStringAsFixed(2));
}

String formatOriginalMoney(double value, {String currency = 'THB'}) {
  final sign = value < 0 ? '-' : '';
  return '$sign$currency ${formatOriginalNumber(value)}';
}

String _addThousandsSeparators(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
