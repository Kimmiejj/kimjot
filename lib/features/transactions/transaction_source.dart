enum TransactionSource {
  manual,
  gallerySlip,
  qrCamera;

  String get firestoreValue {
    return switch (this) {
      TransactionSource.manual => 'manual',
      TransactionSource.gallerySlip => 'gallery_slip',
      TransactionSource.qrCamera => 'qr_camera',
    };
  }
}
