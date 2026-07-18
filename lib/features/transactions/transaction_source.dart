import '../../app/app_language.dart';

enum TransactionSource {
  manual,
  gallerySlip;

  String get firestoreValue {
    return switch (this) {
      TransactionSource.manual => 'manual',
      TransactionSource.gallerySlip => 'gallery_slip',
    };
  }

  String localizedName(AppStrings strings) {
    return switch (this) {
      TransactionSource.manual => strings.manualSource,
      TransactionSource.gallerySlip => strings.gallerySlipSource,
    };
  }
}
