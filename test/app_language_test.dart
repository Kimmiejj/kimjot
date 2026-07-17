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
}
