import 'dart:io';

import '../../app/app_language.dart';
import '../auth/auth_user.dart';
import '../transactions/category_localization.dart';
import '../transactions/create_transaction_input.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';
import 'album_sync_background_service.dart';
import 'slip_date_parser.dart';
import 'slip_transaction_resolver.dart';

Future<int> saveAlbumSyncItems({
  required AuthUser user,
  required TransactionRepository transactionRepository,
  required AppStrings strings,
  required Iterable<AlbumSyncItemSnapshot> items,
}) async {
  var savedCount = 0;
  for (final item in items) {
    final result = item.result;
    final amount = item.amount;
    final fingerprint = item.fingerprint;
    final initialDecision = item.decision;
    if (item.status != AlbumSyncItemStatus.ready ||
        result == null ||
        amount == null ||
        amount <= 0 ||
        fingerprint == null ||
        initialDecision == null) {
      continue;
    }

    try {
      var decision = initialDecision;
      final localDecision = resolveBestEffortSlipDecision(result);
      if (localDecision != null &&
          localDecision.type == TransactionType.internalTransfer) {
        decision = localDecision;
      }
      final transactionDate = parseTransactionDateFrom(
        dateText: result.dateText,
        timeText: result.timeText,
        referenceText: result.reference,
        rawText: result.rawText,
        fallbackDate: _lastModified(item.path),
      );
      final categoryName = localizedCategoryName(
        strings: strings,
        categoryId: decision.categoryId,
        fallbackName: decision.categoryName,
      );

      await transactionRepository.createManualTransaction(
        CreateTransactionInput(
          userId: user.uid,
          amount: amount,
          type: decision.type,
          categoryId: decision.categoryId,
          categoryName: categoryName,
          transactionDate: transactionDate,
          transactionDateText: strings.formatDateTime(transactionDate),
          source: TransactionSource.gallerySlip,
          note: decision.note,
          slipFingerprint: fingerprint,
          slipReference: result.reference,
        ),
      );
      savedCount++;
    } catch (_) {
      // Keep saving the remaining valid slips.
    }
  }
  return savedCount;
}

DateTime? _lastModified(String imagePath) {
  try {
    return File(imagePath).lastModifiedSync();
  } catch (_) {
    return null;
  }
}
