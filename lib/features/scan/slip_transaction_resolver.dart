import '../transactions/transaction_type.dart';
import 'slip_scan_result.dart';

class SlipTransactionDecision {
  const SlipTransactionDecision({
    required this.type,
    required this.categoryId,
    required this.categoryName,
    this.note,
  });

  final TransactionType type;
  final String categoryId;
  final String categoryName;
  final String? note;
}

const List<String> kSlipAnalysisCategoryIds = [
  'food',
  'drink',
  'groceries',
  'transport',
  'shopping',
  'bills',
  'rent',
  'health',
  'education',
  'entertainment',
  'travel',
  'family',
  'insurance',
  'tax',
  'donation',
  'transfer',
  'salary',
  'side_job',
  'business',
  'bonus',
  'investment',
  'interest',
  'sale',
  'allowance',
  'gift',
  'refund',
  'internal_transfer',
  'other',
  'other_income',
];

String savedCategoryNameForId(String categoryId) {
  return switch (categoryId) {
    'food' => 'Food',
    'drink' => 'Drinks',
    'groceries' => 'Groceries',
    'transport' => 'Transport',
    'shopping' => 'Shopping',
    'bills' => 'Bills',
    'rent' => 'Rent / Home',
    'health' => 'Health',
    'education' => 'Education',
    'entertainment' => 'Entertainment',
    'travel' => 'Travel',
    'family' => 'Family',
    'insurance' => 'Insurance',
    'tax' => 'Tax / Fees',
    'donation' => 'Donation',
    'transfer' => 'Transfer',
    'salary' => 'Salary',
    'side_job' => 'Side Job',
    'business' => 'Business',
    'bonus' => 'Bonus',
    'investment' => 'Investment',
    'interest' => 'Interest / Dividend',
    'sale' => 'Sale',
    'allowance' => 'Allowance',
    'gift' => 'Gift',
    'refund' => 'Refund',
    'internal_transfer' => 'Internal Transfer',
    _ => 'Other',
  };
}

TransactionType? resolveTransactionTypeFromSlip(SlipScanResult result) {
  if (partiesLookLikeSamePerson(result.sender, result.recipient)) {
    return TransactionType.internalTransfer;
  }
  if (result.category == SlipCategory.income) {
    return TransactionType.income;
  }
  if (result.category == SlipCategory.expense) {
    return TransactionType.expense;
  }
  if (looksLikePaymentSlip(result)) {
    return TransactionType.expense;
  }
  return null;
}

SlipTransactionDecision? resolveLocalSlipDecision(SlipScanResult result) {
  final type = resolveTransactionTypeFromSlip(result);
  if (type == null) {
    return null;
  }

  final text = result.rawText.toLowerCase();
  if (type == TransactionType.internalTransfer) {
    return SlipTransactionDecision(
      type: type,
      categoryId: 'internal_transfer',
      categoryName: 'Internal Transfer',
      note: buildSlipNote(result),
    );
  }

  if (type == TransactionType.income) {
    if (text.contains('salary') || text.contains('à¹€à¸‡à¸´à¸™à¹€à¸”à¸·à¸­à¸™')) {
      return _decision(type, 'salary', 'Salary', result);
    }
    if (text.contains('bonus') || text.contains('à¹‚à¸šà¸™à¸±à¸ª')) {
      return _decision(type, 'bonus', 'Bonus', result);
    }
    if (text.contains('interest') || text.contains('à¸”à¸­à¸à¹€à¸šà¸µà¹‰à¸¢')) {
      return _decision(type, 'interest', 'Interest / Dividend', result);
    }
    if (text.contains('sale') || text.contains('à¸‚à¸²à¸¢')) {
      return _decision(type, 'sale', 'Sale', result);
    }
    if (text.contains('refund') || text.contains('à¸„à¸·à¸™à¹€à¸‡à¸´à¸™')) {
      return _decision(type, 'refund', 'Refund', result);
    }
    if (text.contains('gift') || text.contains('à¸‚à¸­à¸‡à¸‚à¸§à¸±à¸')) {
      return _decision(type, 'gift', 'Gift', result);
    }
    return _decision(type, 'salary', 'Salary', result);
  }

  if (looksLikePaymentSlip(result) || result.reference != null) {
    return _decision(type, 'transfer', 'Transfer', result);
  }
  if (text.contains('food') ||
      text.contains('restaurant') ||
      text.contains('à¸£à¹‰à¸²à¸™à¸­à¸²à¸«à¸²à¸£') ||
      text.contains('à¸­à¸²à¸«à¸²à¸£')) {
    return _decision(type, 'food', 'Food', result);
  }
  if (text.contains('drink') ||
      text.contains('coffee') ||
      text.contains('cafe') ||
      text.contains('à¸à¸²à¹à¸Ÿ')) {
    return _decision(type, 'drink', 'Drinks', result);
  }
  if (text.contains('grocery') ||
      text.contains('groceries') ||
      text.contains('supermarket') ||
      text.contains('à¸‹à¸¹à¹€à¸›à¸­à¸£à¹Œ')) {
    return _decision(type, 'groceries', 'Groceries', result);
  }
  if (text.contains('transport') ||
      text.contains('taxi') ||
      text.contains('grab') ||
      text.contains('bus') ||
      text.contains('à¸‚à¸™à¸ªà¹ˆà¸‡') ||
      text.contains('à¹à¸—à¹‡à¸à¸‹à¸µà¹ˆ')) {
    return _decision(type, 'transport', 'Transport', result);
  }
  if (text.contains('health') ||
      text.contains('hospital') ||
      text.contains('clinic') ||
      text.contains('pharmacy') ||
      text.contains('medicine') ||
      text.contains('à¹‚à¸£à¸‡à¸žà¸¢à¸²à¸šà¸²à¸¥') ||
      text.contains('à¸¢à¸²')) {
    return _decision(type, 'health', 'Health', result);
  }
  if (text.contains('education') ||
      text.contains('school') ||
      text.contains('course') ||
      text.contains('training') ||
      text.contains('à¹‚à¸£à¸‡à¹€à¸£à¸µà¸¢à¸™') ||
      text.contains('à¸¨à¸¶à¸à¸©à¸²')) {
    return _decision(type, 'education', 'Education', result);
  }
  if (text.contains('entertainment') ||
      text.contains('movie') ||
      text.contains('cinema') ||
      text.contains('game') ||
      text.contains('à¸šà¸±à¸™à¹€à¸—à¸´à¸‡') ||
      text.contains('à¸ à¸²à¸žà¸¢à¸™à¸•à¸£à¹Œ')) {
    return _decision(type, 'entertainment', 'Entertainment', result);
  }
  if (text.contains('travel') ||
      text.contains('hotel') ||
      text.contains('flight') ||
      text.contains('ticket') ||
      text.contains('à¸—à¹ˆà¸­à¸‡à¹€à¸—à¸µà¹ˆà¸¢à¸§') ||
      text.contains('à¹‚à¸£à¸‡à¹à¸£à¸¡')) {
    return _decision(type, 'travel', 'Travel', result);
  }
  if (text.contains('bill') ||
      text.contains('electricity') ||
      text.contains('water') ||
      text.contains('internet') ||
      text.contains('phone') ||
      text.contains('utility') ||
      text.contains('à¸„à¹ˆà¸²à¸ˆà¹‰à¸²à¸‡') ||
      text.contains('à¸„à¹ˆà¸²')) {
    return _decision(type, 'bills', 'Bills', result);
  }
  if (text.contains('rent') ||
      text.contains('lease') ||
      text.contains('apartment') ||
      text.contains('house') ||
      text.contains('à¹€à¸Šà¹ˆà¸²')) {
    return _decision(type, 'rent', 'Rent / Home', result);
  }
  if (text.contains('insurance') || text.contains('policy') || text.contains('à¸›à¸£à¸°à¸à¸±à¸™')) {
    return _decision(type, 'insurance', 'Insurance', result);
  }
  if (text.contains('tax') ||
      text.contains('fee') ||
      text.contains('charge') ||
      text.contains('à¸„à¹ˆà¸²à¸˜à¸£à¸£à¸¡à¹€à¸™à¸µà¸¢à¸¡')) {
    return _decision(type, 'tax', 'Tax / Fees', result);
  }
  if (text.contains('donation') || text.contains('charity') || text.contains('à¸šà¸£à¸´à¸ˆà¸²à¸„')) {
    return _decision(type, 'donation', 'Donation', result);
  }
  return _decision(type, 'shopping', 'Shopping', result);
}

bool looksLikePaymentSlip(SlipScanResult result) {
  final text = result.rawText.toLowerCase();
  return result.bankName != null ||
      result.reference != null ||
      text.contains('k plus') ||
      text.contains('scb') ||
      text.contains('transfer') ||
      text.contains('payment') ||
      text.contains('transaction') ||
      text.contains('à¹‚à¸­à¸™') ||
      text.contains('à¸Šà¸³à¸£à¸°') ||
      text.contains('à¸žà¸£à¹‰à¸­à¸¡à¹€à¸žà¸¢à¹Œ') ||
      text.contains('à¹€à¸¥à¸‚à¸—à¸µà¹ˆ') ||
      text.contains('à¸­à¹‰à¸²à¸‡à¸­à¸´à¸‡') ||
      text.contains('à¸ˆà¸³à¸™à¸§à¸™à¹€à¸‡à¸´à¸™');
}

bool partiesLookLikeSamePerson(String? sender, String? recipient) {
  final normalizedSender = _normalizePartyName(sender);
  final normalizedRecipient = _normalizePartyName(recipient);
  if (normalizedSender == null || normalizedRecipient == null) {
    return false;
  }

  if (normalizedSender == normalizedRecipient) {
    return true;
  }

  if (normalizedSender.contains(normalizedRecipient) ||
      normalizedRecipient.contains(normalizedSender)) {
    return true;
  }

  final senderTokens = _nameTokens(sender);
  final recipientTokens = _nameTokens(recipient);
  if (senderTokens.isEmpty || recipientTokens.isEmpty) {
    return false;
  }

  final overlap = senderTokens.intersection(recipientTokens);
  return overlap.isNotEmpty;
}

String? buildSlipNote(SlipScanResult result, {String? overrideNote}) {
  final values = <String>[
    if (result.sender != null && result.sender!.trim().isNotEmpty)
      'From ${result.sender!.trim()}',
    if (result.recipient != null && result.recipient!.trim().isNotEmpty)
      'To ${result.recipient!.trim()}',
    if (result.bankName != null && result.bankName!.trim().isNotEmpty)
      result.bankName!.trim(),
    if (result.reference != null && result.reference!.trim().isNotEmpty)
      result.reference!.trim(),
    if (overrideNote != null && overrideNote.trim().isNotEmpty)
      overrideNote.trim(),
  ];

  if (values.isEmpty) {
    return null;
  }

  return values.toSet().join(' / ');
}

SlipTransactionDecision _decision(
  TransactionType type,
  String categoryId,
  String categoryName,
  SlipScanResult result,
) {
  return SlipTransactionDecision(
    type: type,
    categoryId: categoryId,
    categoryName: categoryName,
    note: buildSlipNote(result),
  );
}

String? _normalizePartyName(String? value) {
  if (value == null) {
    return null;
  }

  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'account|บัญชี|เลขที่|นาย|นางสาว|นาง'), '')
      .replaceAll(RegExp(r'[^a-z0-9\u0E00-\u0E7F]'), '');
  if (normalized.length < 3) {
    return null;
  }
  return normalized;
}

Set<String> _nameTokens(String? value) {
  if (value == null) {
    return const {};
  }

  return value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9\u0E00-\u0E7F]+'))
      .map((token) => _normalizePartyName(token))
      .whereType<String>()
      .where((token) => token.length >= 3)
      .toSet();
}
