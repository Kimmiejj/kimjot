import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/app/app_language.dart';
import 'package:kimjot/features/auth/auth_user.dart';
import 'package:kimjot/features/settings/support_screens.dart';
import 'package:kimjot/features/transactions/custom_category_store.dart';
import 'package:kimjot/features/transactions/transaction_type.dart';
import 'package:kimjot/shared/widgets/pastel_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'adds custom categories independently for every transaction type',
    () async {
      SharedPreferences.setMockInitialValues({});
      final userId = 'test-${DateTime.now().microsecondsSinceEpoch}';
      final store = CustomCategoryStore.instance;

      await store.add(
        userId: userId,
        name: 'Pet care',
        type: TransactionType.expense,
      );
      await store.add(
        userId: userId,
        name: 'Freelance',
        type: TransactionType.income,
      );
      await store.add(
        userId: userId,
        name: 'My accounts',
        type: TransactionType.internalTransfer,
      );

      expect(
        store.categoriesFor(userId, TransactionType.expense).single.name,
        'Pet care',
      );
      expect(
        store.categoriesFor(userId, TransactionType.income).single.name,
        'Freelance',
      );
      expect(
        store
            .categoriesFor(userId, TransactionType.internalTransfer)
            .single
            .name,
        'My accounts',
      );
    },
  );

  testWidgets('category editor stays themed and saves on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final userId = 'widget-${DateTime.now().microsecondsSinceEpoch}';

    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController(initialLanguage: AppLanguage.en),
        child: MaterialApp(
          home: CategoriesScreen(user: AuthUser(uid: userId)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add category'), findsNothing);
    final addButton = find.widgetWithText(
      FilledButton,
      'Add a category for any transaction type',
    );
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.byType(KimjodDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).last, 'Pet care');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Pet care'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
