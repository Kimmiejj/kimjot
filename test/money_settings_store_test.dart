import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/features/settings/money_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps budgets isolated by user id', () async {
    SharedPreferences.setMockInitialValues({
      'money_settings.monthly_budget': 99999.0,
    });
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final user1 = 'budget-user-1-$suffix';
    final user2 = 'budget-user-2-$suffix';
    final store = MoneySettingsStore.instance;

    expect((await store.load(user1)).monthlyBudget, isNull);
    await store.saveMonthlyBudget(user1, 12000);

    expect((await store.load(user2)).monthlyBudget, isNull);
    await store.saveMonthlyBudget(user2, 8000);

    expect(store.snapshotFor(user1).monthlyBudget, 12000);
    expect(store.snapshotFor(user2).monthlyBudget, 8000);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getDouble('money_settings.monthly_budget.$user1'),
      12000,
    );
    expect(preferences.getDouble('money_settings.monthly_budget.$user2'), 8000);
  });
}
