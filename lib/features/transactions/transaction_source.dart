enum TransactionSource {
  manual,
  gallerySlip;

  String get firestoreValue {
    return switch (this) {
      TransactionSource.manual => 'manual',
      TransactionSource.gallerySlip => 'gallery_slip',
    };
  }
}
