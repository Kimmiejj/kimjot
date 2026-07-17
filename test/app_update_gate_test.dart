import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/app/app_language.dart';
import 'package:kimjot/app/app_update_gate.dart';

void main() {
  test('requires an update only below the configured minimum version code', () {
    final requirement = AppUpdateRequirement.fromMap(
      const <String, Object?>{
        'minimumVersionCode': 8,
        'latestVersionName': '2.4.0',
        'updateUrl': 'https://example.com/app',
      },
      installedVersionCode: 7,
      installedVersionName: '2.3.0',
    );

    expect(requirement.isRequired, isTrue);
    expect(requirement.latestVersionName, '2.4.0');
    expect(requirement.updateUrl, 'https://example.com/app');
  });

  testWidgets('blocks the app and automatically starts a required update', (
    tester,
  ) async {
    final service = _FakeAppUpdateService(
      const AppUpdateRequirement(
        minimumVersionCode: 2,
        installedVersionCode: 1,
        installedVersionName: '1.0.0',
        latestVersionName: '1.1.0',
        updateUrl: 'https://example.com/kimjod.apk',
        messageTh: null,
        messageEn: null,
      ),
    );

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('App update required'), findsOneWidget);
    expect(find.text('PROTECTED APP'), findsNothing);
    expect(service.updateStarts, 1);
    expect(service.lastApkUrl, 'https://example.com/kimjod.apk');
    expect(service.lastTargetVersionCode, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('allows the app when no update is required', (tester) async {
    final service = _FakeAppUpdateService(null);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('PROTECTED APP'), findsOneWidget);
    expect(service.updateStarts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('detects a required update while the app stays open', (
    tester,
  ) async {
    final service = _FakeAppUpdateService(null);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    service.requirement = const AppUpdateRequirement(
      minimumVersionCode: 4,
      installedVersionCode: 3,
      installedVersionName: '1.1.1',
      latestVersionName: '1.1.2',
      updateUrl: 'https://example.com/kimjod-4.apk',
      messageTh: null,
      messageEn: null,
    );
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(find.text('App update required'), findsOneWidget);
    expect(service.updateStarts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _app(AppUpdateService service) {
  return AppLanguageScope(
    controller: AppLanguageController(initialLanguage: AppLanguage.en),
    child: MaterialApp(
      home: AppUpdateGate(
        service: service,
        child: const Scaffold(body: Text('PROTECTED APP')),
      ),
    ),
  );
}

class _FakeAppUpdateService implements AppUpdateService {
  _FakeAppUpdateService(this.requirement);

  AppUpdateRequirement? requirement;
  int updateStarts = 0;
  String? lastApkUrl;
  int? lastTargetVersionCode;

  @override
  Future<AppUpdateRequirement?> checkForRequiredUpdate() async => requirement;

  @override
  Future<bool> startRequiredUpdate(
    String? apkUrl,
    int targetVersionCode,
  ) async {
    updateStarts += 1;
    lastApkUrl = apkUrl;
    lastTargetVersionCode = targetVersionCode;
    return true;
  }
}
