import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/shared/widgets/loading_screen.dart';

void main() {
  testWidgets('launch movie runs on a two-second timeline without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: LoadingScreen(message: 'Starting Kimjod...')),
    );

    expect(
      find.byKey(const ValueKey('two-second-launch-movie')),
      findsOneWidget,
    );
    expect(find.text('Starting Kimjod...'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 1));
    final halfway = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(halfway.value, closeTo(0.5, 0.02));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 990));
    final nearlyComplete = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(nearlyComplete.value, greaterThan(0.98));
    expect(tester.takeException(), isNull);
  });
}
