import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/app/app_language.dart';
import 'package:kimjot/shared/widgets/app_exit_animation.dart';

void main() {
  testWidgets('exit animation transitions from mascot to app icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController(initialLanguage: AppLanguage.en),
        child: const MaterialApp(home: AppExitAnimation()),
      ),
    );

    expect(find.byKey(const ValueKey('exit-sloth-mascot')), findsOneWidget);
    expect(find.byKey(const ValueKey('exit-wallet')), findsOneWidget);
    expect(find.text('All tucked away!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1750));

    expect(find.byKey(const ValueKey('exit-app-icon')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
