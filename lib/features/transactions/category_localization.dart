import '../../app/app_language.dart';

String localizedCategoryName({
  required AppStrings strings,
  required String categoryId,
  required String fallbackName,
}) {
  return switch (categoryId) {
    'food' => strings.food,
    'drink' => strings.drink,
    'groceries' => strings.groceries,
    'transport' => strings.transport,
    'shopping' => strings.shopping,
    'bills' => strings.bills,
    'rent' => strings.rent,
    'health' => strings.health,
    'education' => strings.education,
    'entertainment' => strings.entertainment,
    'travel' => strings.travel,
    'family' => strings.family,
    'insurance' => strings.insurance,
    'tax' => strings.tax,
    'donation' => strings.donation,
    'transfer' => strings.transfer,
    'salary' => strings.salary,
    'side_job' => strings.sideJob,
    'business' => strings.business,
    'bonus' => strings.bonus,
    'investment' => strings.investment,
    'interest' => strings.interest,
    'sale' => strings.sale,
    'allowance' => strings.allowance,
    'gift' => strings.gift,
    'refund' => strings.refund,
    'other' || 'other_income' => strings.other,
    _ => fallbackName,
  };
}

String localizedTransactionTitle({
  required AppStrings strings,
  required String categoryId,
  required String categoryName,
  String? note,
  String? merchantName,
}) {
  final trimmedMerchant = merchantName?.trim();
  if (trimmedMerchant != null && trimmedMerchant.isNotEmpty) {
    return trimmedMerchant;
  }

  final trimmedNote = note?.trim();
  if (trimmedNote != null && trimmedNote.isNotEmpty) {
    return trimmedNote;
  }

  return localizedCategoryName(
    strings: strings,
    categoryId: categoryId,
    fallbackName: categoryName,
  );
}
