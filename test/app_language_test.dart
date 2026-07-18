import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/app/app_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists selected language', () async {
    final controller = AppLanguageController();

    await controller.setLanguage(AppLanguage.th);

    expect(await AppLanguageController.loadSavedLanguage(), AppLanguage.th);

    controller.dispose();
  });

  test('falls back to English when no language has been saved', () async {
    expect(await AppLanguageController.loadSavedLanguage(), AppLanguage.en);
  });

  test('formats transaction time without changing the minute', () {
    final strings = AppStrings(AppLanguage.th);

    expect(strings.formatTime(DateTime(2026, 7, 17, 9, 5)), '09:05');
    expect(
      strings.formatDateTime(DateTime(2026, 7, 17, 9, 5)),
      contains('09:05'),
    );
  });

  test('new app surfaces have distinct Thai and English copy', () {
    const thai = AppStrings(AppLanguage.th);
    const english = AppStrings(AppLanguage.en);

    final pairs = <(String, String)>[
      (thai.firebaseSetupRequired, english.firebaseSetupRequired),
      (thai.budgetSaved, english.budgetSaved),
      (thai.monthlyBudgetSetup, english.monthlyBudgetSetup),
      (thai.addInstallment, english.addInstallment),
      (thai.editTransaction, english.editTransaction),
      (thai.clearSearch, english.clearSearch),
      (thai.albumScanComplete, english.albumScanComplete),
      (thai.trainingComplete, english.trainingComplete),
      (thai.manualSource, english.manualSource),
      (thai.gallerySlipSource, english.gallerySlipSource),
      (thai.albumSyncProgressChannel, english.albumSyncProgressChannel),
    ];

    for (final (thaiText, englishText) in pairs) {
      expect(thaiText, isNot(equals(englishText)));
      expect(thaiText, matches(RegExp(r'[ก-๙]')));
      expect(englishText, matches(RegExp(r'[A-Za-z]')));
    }
  });
}
