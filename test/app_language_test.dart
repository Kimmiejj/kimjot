import 'package:flutter_test/flutter_test.dart';
import 'package:kimjod/app/app_language.dart';
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
}
