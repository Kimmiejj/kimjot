import '../transactions/transaction_type.dart';
import 'slip_scan_result.dart';
import 'slip_text_parser.dart';

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

const kSlipAnalysisCategoryIds = <String>[
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
  'internal_transfer',
  'other',
];

String savedCategoryNameForId(String categoryId) => switch (categoryId) {
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

TransactionType? resolveTransactionTypeFromSlip(SlipScanResult result) {
  if (partiesLookLikeSamePerson(result.sender, result.recipient) ||
      _rawTextLooksLikeSamePersonParties(result.rawText)) {
    return TransactionType.internalTransfer;
  }
  if (result.category == SlipCategory.expense ||
      result.category == SlipCategory.income ||
      looksLikePaymentSlip(result)) {
    return TransactionType.expense;
  }
  return null;
}

SlipTransactionDecision? resolveLocalSlipDecision(SlipScanResult result) {
  final type = resolveTransactionTypeFromSlip(result);
  if (type == null) return null;
  if (type == TransactionType.internalTransfer) {
    return SlipTransactionDecision(
      type: type,
      categoryId: 'internal_transfer',
      categoryName: 'Internal Transfer',
      note: buildSlipNote(result),
    );
  }

  final text = SlipTextParser.repairThaiMojibake(result.rawText).toLowerCase();
  final categories = <(String, String, String)>[
    ('ptt', 'transport', 'Transport'),
    ('\u0E1B\u0E15\u0E17', 'transport', 'Transport'),
    ('food patio', 'food', 'Food'),
    ('food', 'food', 'Food'),
    ('restaurant', 'food', 'Food'),
    ('\u0E23\u0E49\u0E32\u0E19\u0E2D\u0E32\u0E2B\u0E32\u0E23', 'food', 'Food'),
    ('\u0E2D\u0E32\u0E2B\u0E32\u0E23', 'food', 'Food'),
    ('drink', 'drink', 'Drinks'),
    ('coffee', 'drink', 'Drinks'),
    ('cafe', 'drink', 'Drinks'),
    ('\u0E01\u0E32\u0E41\u0E1F', 'drink', 'Drinks'),
    ('grocery', 'groceries', 'Groceries'),
    ('groceries', 'groceries', 'Groceries'),
    ('supermarket', 'groceries', 'Groceries'),
    ('\u0E0B\u0E39\u0E40\u0E1B\u0E2D\u0E23\u0E4C', 'groceries', 'Groceries'),
    ('transport', 'transport', 'Transport'),
    ('taxi', 'transport', 'Transport'),
    ('grab', 'transport', 'Transport'),
    ('bus', 'transport', 'Transport'),
    ('\u0E02\u0E19\u0E2A\u0E48\u0E07', 'transport', 'Transport'),
    ('\u0E41\u0E17\u0E47\u0E01\u0E0B\u0E35\u0E48', 'transport', 'Transport'),
    ('health', 'health', 'Health'),
    ('hospital', 'health', 'Health'),
    ('clinic', 'health', 'Health'),
    ('pharmacy', 'health', 'Health'),
    ('\u0E22\u0E32', 'health', 'Health'),
    ('bill', 'bills', 'Bills'),
    ('electricity', 'bills', 'Bills'),
    ('water', 'bills', 'Bills'),
    ('internet', 'bills', 'Bills'),
    ('phone', 'bills', 'Bills'),
    (
      '\u0E04\u0E48\u0E32\u0E43\u0E0A\u0E49\u0E08\u0E48\u0E32\u0E22',
      'bills',
      'Bills',
    ),
    ('\u0E04\u0E48\u0E32', 'bills', 'Bills'),
    ('rent', 'rent', 'Rent / Home'),
    ('\u0E40\u0E0A\u0E48\u0E32', 'rent', 'Rent / Home'),
    ('insurance', 'insurance', 'Insurance'),
    ('\u0E1B\u0E23\u0E30\u0E01\u0E31\u0E19', 'insurance', 'Insurance'),
    ('tax', 'tax', 'Tax / Fees'),
    ('fee', 'tax', 'Tax / Fees'),
    (
      '\u0E04\u0E48\u0E32\u0E18\u0E23\u0E23\u0E21\u0E40\u0E19\u0E35\u0E22\u0E21',
      'tax',
      'Tax / Fees',
    ),
    ('donation', 'donation', 'Donation'),
    ('\u0E1A\u0E23\u0E34\u0E08\u0E32\u0E04', 'donation', 'Donation'),
  ];
  for (final category in categories) {
    if (text.contains(category.$1)) {
      return _decision(type, category.$2, category.$3, result);
    }
  }
  if (looksLikePaymentSlip(result) || result.reference != null) {
    return _decision(type, 'transfer', 'Transfer', result);
  }
  return _decision(type, 'shopping', 'Shopping', result);
}

SlipTransactionDecision? resolveBestEffortSlipDecision(SlipScanResult result) {
  final localDecision = resolveLocalSlipDecision(result);
  if (localDecision != null) return localDecision;
  if (result.amount == null || result.amount! <= 0) return null;

  final text = SlipTextParser.repairThaiMojibake(result.rawText).toLowerCase();
  final looksLikeSlip =
      result.hasUsefulData ||
      [
        'scb',
        'k plus',
        'truemoney',
        'wallet',
        'reference',
        'transaction',
        'biller',
        '\u0E08\u0E48\u0E32\u0E22',
        '\u0E0A\u0E33\u0E23\u0E30',
        '\u0E40\u0E15\u0E34\u0E21\u0E40\u0E07\u0E34\u0E19',
        '\u0E42\u0E2D\u0E19',
        '\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19',
      ].any(text.contains);
  if (!looksLikeSlip) return null;

  return _decision(TransactionType.expense, 'transfer', 'Transfer', result);
}

bool looksLikePaymentSlip(SlipScanResult result) {
  final text = SlipTextParser.repairThaiMojibake(result.rawText).toLowerCase();
  return result.bankName != null ||
      result.reference != null ||
      [
        'k plus',
        'scb',
        'truemoney',
        'wallet',
        'transfer',
        'payment',
        'transaction',
        'biller',
        '\u0E42\u0E2D\u0E19',
        '\u0E0A\u0E33\u0E23\u0E30',
        '\u0E1E\u0E23\u0E49\u0E2D\u0E21\u0E40\u0E1E\u0E22\u0E4C',
        '\u0E40\u0E15\u0E34\u0E21\u0E40\u0E07\u0E34\u0E19',
        '\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48',
        '\u0E2D\u0E49\u0E32\u0E07\u0E2D\u0E34\u0E07',
        '\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19',
      ].any(text.contains);
}

bool partiesLookLikeSamePerson(String? sender, String? recipient) {
  final senderTokens = _nameTokens(_withoutThaiTitles(sender));
  final recipientTokens = _nameTokens(_withoutThaiTitles(recipient));
  if (senderTokens.isEmpty || recipientTokens.isEmpty) return false;
  if (senderTokens.intersection(recipientTokens).isNotEmpty) return true;

  final normalizedSenderTokens = _normalizedThaiNameTokens(senderTokens);
  final normalizedRecipientTokens = _normalizedThaiNameTokens(recipientTokens);
  return normalizedSenderTokens
      .intersection(normalizedRecipientTokens)
      .isNotEmpty;
}

bool _rawTextLooksLikeSamePersonParties(String rawText) {
  final repaired = SlipTextParser.repairThaiMojibake(rawText);
  final candidates = _personNameCandidatesFromRawText(repaired);
  if (candidates.length < 2) return false;

  for (var i = 0; i < candidates.length; i++) {
    for (var j = i + 1; j < candidates.length; j++) {
      if (partiesLookLikeSamePerson(candidates[i], candidates[j])) {
        return true;
      }
    }
  }
  return false;
}

List<String> _personNameCandidatesFromRawText(String rawText) {
  final candidates = <String>{};
  final personName = RegExp(
    r'(?:\u0E19\u0E32\u0E22|\u0E19\u0E32\u0E07\u0E2A\u0E32\u0E27|\u0E19\u0E32\u0E07|\u0E04\u0E38\u0E13)\s*[\u0E00-\u0E7F.]{2,}(?:\s+[\u0E00-\u0E7F.]{1,})?',
  );
  for (final match in personName.allMatches(rawText)) {
    candidates.add(match.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim());
  }
  return candidates.toList(growable: false);
}

String? _withoutThaiTitles(String? value) {
  if (value == null) return null;
  return SlipTextParser.repairThaiMojibake(value).replaceAll(
    RegExp(
      r'\b(account|mr|mrs|ms|miss|bank|wallet)\b|\u0E19\u0E32\u0E22|\u0E19\u0E32\u0E07\u0E2A\u0E32\u0E27|\u0E19\u0E32\u0E07|\u0E04\u0E38\u0E13|\u0E14\u0E23\.?|\u0E18\.?|\u0E18\u0E19\u0E32\u0E04\u0E32\u0E23',
    ),
    ' ',
  );
}

String? buildSlipNote(SlipScanResult result, {String? overrideNote}) {
  final cleanedOverride = _cleanNoteCandidate(overrideNote);
  if (cleanedOverride != null &&
      !_sameCleanedParty(cleanedOverride, result.sender) &&
      !_sameCleanedParty(cleanedOverride, result.recipient)) {
    return cleanedOverride;
  }

  final merchant =
      _merchantNoteFrom(result.recipient) ??
      _merchantNoteFromText(result.rawText);
  if (merchant != null) return merchant;

  final bank = _bankNote(result.bankName);
  if (_looksLikePerson(result.recipient) || _looksLikePerson(result.sender)) {
    return bank == null ? 'Transfer' : '$bank transfer';
  }
  return bank == null ? null : '$bank transfer';
}

String? _cleanNoteCandidate(String? value) {
  if (value == null) return null;
  final repaired = SlipTextParser.repairThaiMojibake(
    value,
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (repaired.isEmpty || SlipTextParser.looksUnreadable(repaired)) return null;
  return repaired;
}

String? _merchantNoteFrom(String? value) {
  final cleaned = _cleanNoteCandidate(value);
  if (cleaned == null ||
      _looksLikePerson(cleaned) ||
      _isMostlyAccountOrReference(cleaned)) {
    return null;
  }
  return cleaned;
}

String? _merchantNoteFromText(String text) {
  final repaired = SlipTextParser.repairThaiMojibake(text);
  final lower = repaired.toLowerCase();
  for (final known in <String>[
    'PTT',
    'Food Patio',
    '7-Eleven',
    'Lotus',
    'Big C',
    'Grab',
    'TrueMoney',
  ]) {
    if (lower.contains(known.toLowerCase())) return known;
  }

  final lines = repaired
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  for (var i = 0; i < lines.length; i++) {
    final lowerLine = lines[i].toLowerCase();
    if (!(lowerLine.contains('merchant') ||
        lowerLine.contains('biller') ||
        lowerLine.contains('\u0E23\u0E49\u0E32\u0E19'))) {
      continue;
    }
    final inline = lines[i]
        .replaceFirst(RegExp(r'^.*?[:\uFF1A]\s*'), '')
        .trim();
    final inlineMerchant = _merchantNoteFrom(inline);
    if (inlineMerchant != null) return inlineMerchant;
    if (i + 1 < lines.length) {
      final nextMerchant = _merchantNoteFrom(lines[i + 1]);
      if (nextMerchant != null) return nextMerchant;
    }
  }
  return null;
}

String? _bankNote(String? bankName) {
  final cleaned = _cleanNoteCandidate(bankName);
  if (cleaned == null) return null;
  final upper = cleaned.toUpperCase();
  if (upper.contains('SCB')) return 'SCB';
  if (upper.contains('K PLUS') ||
      upper.contains('KPLUS') ||
      upper.contains('KASIKORN')) {
    return 'K PLUS';
  }
  return cleaned;
}

bool _sameCleanedParty(String value, String? party) {
  final cleanedParty = _cleanNoteCandidate(party);
  return cleanedParty != null &&
      value.toLowerCase() == cleanedParty.toLowerCase();
}

bool _looksLikePerson(String? value) {
  final cleaned = _cleanNoteCandidate(value);
  if (cleaned == null) return false;
  final lower = cleaned.toLowerCase();
  if (RegExp(r'\b(mr|mrs|ms|miss)\b').hasMatch(lower)) return true;
  if (RegExp(
    r'\u0E19\u0E32\u0E22|\u0E19\u0E32\u0E07\u0E2A\u0E32\u0E27|\u0E19\u0E32\u0E07|\u0E04\u0E38\u0E13',
  ).hasMatch(cleaned)) {
    return true;
  }
  final tokens = _nameTokens(cleaned);
  return tokens.length >= 2 && !_isMostlyBusinessName(cleaned);
}

bool _isMostlyBusinessName(String value) {
  final lower = value.toLowerCase();
  return [
    'food',
    'patio',
    'ptt',
    'biller',
    'company',
    'co.',
    'ltd',
    'restaurant',
    'cafe',
    'shop',
    'store',
  ].any(lower.contains);
}

bool _isMostlyAccountOrReference(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  return compact.isEmpty ||
      RegExp(r'^[xX*\u2022\-\d]+$').hasMatch(compact) ||
      RegExp(r'^[A-Z0-9\-]{8,}$', caseSensitive: false).hasMatch(compact);
}

SlipTransactionDecision _decision(
  TransactionType type,
  String categoryId,
  String categoryName,
  SlipScanResult result,
) => SlipTransactionDecision(
  type: type,
  categoryId: categoryId,
  categoryName: categoryName,
  note: buildSlipNote(result),
);

Set<String> _nameTokens(String? value) {
  if (value == null) return const {};
  final stripped = SlipTextParser.repairThaiMojibake(value)
      .toLowerCase()
      .replaceAll(
        RegExp(
          r'\b(account|mr|mrs|ms|miss|bank|wallet|true|money)\b|\u0E19\u0E32\u0E22|\u0E19\u0E32\u0E07\u0E2A\u0E32\u0E27|\u0E19\u0E32\u0E07|\u0E04\u0E38\u0E13|\u0E14\u0E23\.?|\u0E18\.?|\u0E18\u0E19\u0E32\u0E04\u0E32\u0E23|\u0E1A\u0E31\u0E0D\u0E0A\u0E35|\u0E40\u0E25\u0E02\u0E17\u0E35\u0E48',
        ),
        ' ',
      );
  const ignored = {'account', 'bank', 'wallet', 'true', 'money', 'k', 'plus'};
  return stripped
      .split(RegExp(r'[^a-z0-9\u0E00-\u0E7F]+'))
      .map((token) => token.trim())
      .where((token) => token.length >= 2 && !ignored.contains(token))
      .toSet();
}

Set<String> _normalizedThaiNameTokens(Set<String> tokens) {
  return tokens
      .where((token) => RegExp(r'[\u0E00-\u0E7F]').hasMatch(token))
      .map(
        (token) =>
            token.replaceAll(RegExp(r'[\u0E31\u0E34-\u0E3A\u0E47-\u0E4E]'), ''),
      )
      .where((token) => token.length >= 4)
      .toSet();
}
