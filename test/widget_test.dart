import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/app/app_language.dart';
import 'package:kimjot/app/app_shell.dart';
import 'package:kimjot/features/auth/auth_gate.dart';
import 'package:kimjot/features/auth/auth_service.dart';
import 'package:kimjot/features/auth/auth_user.dart';
import 'package:kimjot/features/auth/login_screen.dart';
import 'package:kimjot/features/scan/album_sync_review_screen.dart';
import 'package:kimjot/features/scan/slip_scan_result.dart';
import 'package:kimjot/features/transactions/create_transaction_input.dart';
import 'package:kimjot/features/transactions/home_summary.dart';
import 'package:kimjot/features/transactions/manual_transaction_sheet.dart';
import 'package:kimjot/features/transactions/transaction_list_screen.dart';
import 'package:kimjot/features/transactions/transaction_repository.dart';
import 'package:kimjot/features/transactions/transaction_record.dart';
import 'package:kimjot/features/transactions/transaction_source.dart';
import 'package:kimjot/features/transactions/transaction_sync_status.dart';
import 'package:kimjot/features/transactions/transaction_type.dart';
import 'package:kimjot/features/transactions/update_transaction_input.dart';

void main() {
  for (final size in <Size>[const Size(375, 667), const Size(384, 824)]) {
    testWidgets('main tabs fit ${size.width}x${size.height}', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final authService = _FakeAuthService();
      final transactionRepository = _FakeTransactionRepository();
      const user = AuthUser(
        uid: 'test-user',
        displayName: 'Test User',
        email: 'test@example.com',
      );

      await tester.pumpWidget(
        _buildTestApp(
          AppShell(
            user: user,
            authService: authService,
            transactionRepository: transactionRepository,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      for (final label in <String>['Slip', 'Graph', 'Settings']) {
        await tester.tap(find.text(label).last);
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          tester.takeException(),
          isNull,
          reason: '$label overflowed at ${size.width}x${size.height}',
        );
      }

      authService.dispose();
    });
  }

  testWidgets('shows the kimjod login screen', (WidgetTester tester) async {
    final authService = _FakeAuthService();

    await tester.pumpWidget(
      _buildTestApp(LoginScreen(authService: authService)),
    );

    expect(find.text('Keep money clear\nevery day'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('On-device'), findsOneWidget);
    expect(find.text('No slip image'), findsOneWidget);

    authService.dispose();
  });

  testWidgets('goes to the home screen after Google login succeeds', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    final transactionRepository = _FakeTransactionRepository();

    await tester.pumpWidget(
      _buildTestApp(
        AuthGate(
          authService: authService,
          transactionRepository: transactionRepository,
        ),
      ),
    );

    expect(find.text('Checking sign in...'), findsOneWidget);

    authService.emitSignedOut();
    await tester.pump();

    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Monthly balance'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Graph'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    authService.dispose();
  });

  testWidgets('saves a manual expense transaction from home', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    final transactionRepository = _FakeTransactionRepository();

    await tester.pumpWidget(
      _buildTestApp(
        AuthGate(
          authService: authService,
          transactionRepository: transactionRepository,
        ),
      ),
    );

    authService.signInWithGoogle();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add transaction'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '125.509');
    await tester.enterText(find.byType(TextFormField).last, 'Lunch');
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(transactionRepository.savedInputs, hasLength(1));

    final input = transactionRepository.savedInputs.single;
    expect(input.userId, 'test-user');
    expect(input.amount, 125.50);
    expect(input.type, TransactionType.expense);
    expect(input.categoryId, 'food');
    expect(input.categoryName, 'Food');
    expect(input.note, 'Lunch');
    expect(find.text('Transaction saved.'), findsOneWidget);
    expect(find.text('-THB 125.50'), findsWidgets);
    expect(find.text('THB 125.50'), findsOneWidget);

    authService.dispose();
  });

  testWidgets('slip import page only offers gallery import', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    final transactionRepository = _FakeTransactionRepository();

    await tester.pumpWidget(
      _buildTestApp(
        AuthGate(
          authService: authService,
          transactionRepository: transactionRepository,
        ),
      ),
    );

    authService.signInWithGoogle();
    await tester.pumpAndSettle();

    expect(find.text('QR\nBank'), findsNothing);
    await tester.tap(find.text('Slip\nGallery'));
    await tester.pumpAndSettle();
    expect(find.text('Slip Import'), findsOneWidget);
    expect(find.text('Import from gallery'), findsOneWidget);
    expect(find.text('Scan slip'), findsNothing);
    expect(transactionRepository.savedInputs, isEmpty);

    authService.dispose();
  });

  testWidgets('transaction list search matches amounts', (
    WidgetTester tester,
  ) async {
    final transactionRepository = _FakeTransactionRepository();
    const user = AuthUser(
      uid: 'test-user',
      displayName: 'Test User',
      email: 'test@example.com',
    );

    await tester.pumpWidget(
      _buildTestApp(
        TransactionListScreen(
          user: user,
          transactionRepository: transactionRepository,
          initialMonth: DateTime.now(),
        ),
      ),
    );

    await transactionRepository.createManualTransaction(
      CreateTransactionInput(
        userId: user.uid,
        amount: 100,
        type: TransactionType.expense,
        categoryId: 'food',
        categoryName: 'Food',
        transactionDate: DateTime.now(),
        transactionDateText: 'Today',
        note: 'Coffee',
      ),
    );
    await transactionRepository.createManualTransaction(
      CreateTransactionInput(
        userId: user.uid,
        amount: 250,
        type: TransactionType.expense,
        categoryId: 'transport',
        categoryName: 'Transport',
        transactionDate: DateTime.now(),
        transactionDateText: 'Today',
        note: 'Taxi',
      ),
    );
    await tester.pump();

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Taxi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Taxi'), findsNothing);
  });

  testWidgets('history can filter by month and year', (
    WidgetTester tester,
  ) async {
    final transactionRepository = _FakeTransactionRepository();
    const user = AuthUser(uid: 'test-user', email: 'test@example.com');
    final initialMonth = DateTime(2026, 7);

    await tester.pumpWidget(
      _buildTestApp(
        TransactionListScreen(
          user: user,
          transactionRepository: transactionRepository,
          initialMonth: initialMonth,
        ),
      ),
    );

    await tester.tap(find.text('July 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Select month and year'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);

    await tester.tap(find.text('Jan'));
    await tester.pumpAndSettle();

    expect(find.text('January 2026'), findsOneWidget);
    expect(find.text('Select month and year'), findsNothing);
  });

  testWidgets('slip form updates to internal transfer after OCR decision', (
    WidgetTester tester,
  ) async {
    final transactionRepository = _FakeTransactionRepository();
    const user = AuthUser(
      uid: 'test-user',
      displayName: 'Test User',
      email: 'test@example.com',
    );

    Widget form(TransactionType type) {
      return _buildTestApp(
        Scaffold(
          body: SingleChildScrollView(
            child: ManualTransactionForm(
              user: user,
              transactionRepository: transactionRepository,
              source: TransactionSource.gallerySlip,
              title: 'Review slip',
              initialType: type,
              initialAmount: 26000,
              initialNote: 'SCB transfer',
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(form(TransactionType.expense));
    expect(find.text('Expense'), findsOneWidget);

    await tester.pumpWidget(form(TransactionType.internalTransfer));
    await tester.pump();

    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(transactionRepository.savedInputs, hasLength(1));
    expect(
      transactionRepository.savedInputs.single.type,
      TransactionType.internalTransfer,
    );
    expect(
      transactionRepository.savedInputs.single.categoryId,
      'internal_transfer',
    );
  });

  testWidgets('album save all keeps same-name SCB slip as internal transfer', (
    WidgetTester tester,
  ) async {
    final transactionRepository = _FakeTransactionRepository();
    const user = AuthUser(
      uid: 'test-user',
      displayName: 'Test User',
      email: 'test@example.com',
    );

    await tester.pumpWidget(
      _buildTestApp(
        AlbumSyncReviewScreen(
          user: user,
          transactionRepository: transactionRepository,
          imagePaths: const ['missing-scb-internal-transfer.png'],
          scanImagePath: (_) async => const SlipScanResult(
            rawText:
                'SCB\n'
                '\u0E19\u0E32\u0E22 \u0E0A\u0E34\u0E29\u0E13\u0E38\u0E0A\u0E32 \u0E2A.\n'
                'xxx-xxx899-2\n'
                '\u0E19\u0E32\u0E22 \u0E0A\u0E34\u0E29\u0E13\u0E38\u0E0A\u0E32 \u0E2A\u0E21\u0E1A\u0E39\u0E23\u0E13\u0E4C\u0E27\u0E23\u0E23\u0E13\u0E30\n'
                'x-4365\n'
                '\u0E08\u0E33\u0E19\u0E27\u0E19\u0E40\u0E07\u0E34\u0E19 26,000.00',
            bankName: 'SCB EASY',
            sender: 'xxx-xxx899-2',
            recipient: 'x-4365',
            amount: 26000,
            reference: '202606250UKVQD6yqY9olW8kK',
            category: SlipCategory.expense,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Save all'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Internal Transfer'), findsOneWidget);

    await tester.tap(find.text('Save all'));
    await tester.pumpAndSettle();

    expect(transactionRepository.savedInputs, hasLength(1));
    expect(
      transactionRepository.savedInputs.single.type,
      TransactionType.internalTransfer,
    );
    expect(
      transactionRepository.savedInputs.single.categoryId,
      'internal_transfer',
    );
  });

  testWidgets('album sync can be cancelled before the active scan completes', (
    WidgetTester tester,
  ) async {
    final scanCompleter = Completer<SlipScanResult>();
    final transactionRepository = _FakeTransactionRepository();
    const user = AuthUser(
      uid: 'test-user',
      displayName: 'Test User',
      email: 'test@example.com',
    );

    await tester.pumpWidget(
      _buildTestApp(
        AlbumSyncReviewScreen(
          user: user,
          transactionRepository: transactionRepository,
          imagePaths: const ['slow-slip.png'],
          scanImagePath: (_) => scanCompleter.future,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cancel sync'), findsOneWidget);
    await tester.tap(find.text('Cancel sync'));
    await tester.pump();

    expect(find.text('Cancel sync'), findsNothing);
    expect(find.text('Sync cancelled'), findsWidgets);
    expect(transactionRepository.savedInputs, isEmpty);

    scanCompleter.complete(
      const SlipScanResult(rawText: 'late result', amount: 100),
    );
    await tester.pumpAndSettle();

    expect(transactionRepository.savedInputs, isEmpty);
    expect(find.text('Sync cancelled'), findsWidgets);
  });
}

Widget _buildTestApp(Widget home, {Key? key}) {
  return AppLanguageScope(
    controller: AppLanguageController(initialLanguage: AppLanguage.en),
    child: MaterialApp(key: key, home: home),
  );
}

class _FakeAuthService implements AuthService {
  final _authStateController = StreamController<AuthUser?>();

  @override
  Stream<AuthUser?> authStateChanges() {
    return _authStateController.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    _authStateController.add(
      const AuthUser(
        uid: 'test-user',
        displayName: 'Test User',
        email: 'test@example.com',
      ),
    );
  }

  @override
  Future<void> signOut() async {
    emitSignedOut();
  }

  void emitSignedOut() {
    _authStateController.add(null);
  }

  void dispose() {
    _authStateController.close();
  }
}

class _FakeTransactionRepository implements TransactionRepository {
  final savedInputs = <CreateTransactionInput>[];
  final _summaryController = StreamController<HomeSummary>.broadcast();
  final _transactionsController =
      StreamController<List<TransactionRecord>>.broadcast();

  @override
  Stream<TransactionSyncStatus> watchSyncStatus(String userId) {
    return Stream.value(const TransactionSyncStatus.synced());
  }

  @override
  Future<void> createManualTransaction(CreateTransactionInput input) async {
    savedInputs.add(input);
    _summaryController.add(_buildSummary(DateTime.now()));
    _transactionsController.add(_buildTransactions());
  }

  @override
  Future<void> updateTransaction(UpdateTransactionInput input) async {}

  @override
  Future<void> deleteTransaction({
    required String userId,
    required String transactionId,
  }) async {}

  @override
  Future<Set<String>> loadActiveSlipFingerprints(String userId) async {
    return savedInputs
        .map((input) => input.slipFingerprint)
        .whereType<String>()
        .toSet();
  }

  @override
  Stream<HomeSummary> watchCurrentMonthSummary(String userId) {
    return _summaryController.stream;
  }

  @override
  Stream<HomeSummary> watchMonthSummary(String userId, DateTime month) {
    return _summaryController.stream.map((_) => _buildSummary(month));
  }

  @override
  Stream<List<TransactionRecord>> watchRecentTransactions(
    String userId, {
    int limit = 5,
  }) {
    return _transactionsController.stream.map(
      (transactions) => transactions.take(limit).toList(),
    );
  }

  @override
  Stream<List<TransactionRecord>> watchMonthTransactions(
    String userId,
    DateTime month, {
    int? limit,
  }) {
    return _transactionsController.stream.map((transactions) {
      final filtered = transactions
          .where((record) => _isSameMonth(record.transactionDate, month))
          .toList();
      return limit == null ? filtered : filtered.take(limit).toList();
    });
  }

  @override
  Stream<List<TransactionRecord>> watchTransactions(String userId) {
    return _transactionsController.stream;
  }

  HomeSummary _buildSummary(DateTime month) {
    var incomeTotal = 0.0;
    var expenseTotal = 0.0;
    var transactionCount = 0;

    for (final input in savedInputs) {
      if (!_isSameMonth(input.transactionDate, month)) {
        continue;
      }

      transactionCount++;
      if (input.type == TransactionType.income) {
        incomeTotal += input.amount;
      } else {
        expenseTotal += input.amount;
      }
    }

    return HomeSummary(
      incomeTotal: incomeTotal,
      expenseTotal: expenseTotal,
      transactionCount: transactionCount,
    );
  }

  List<TransactionRecord> _buildTransactions() {
    return savedInputs.reversed.map((input) {
      final index = savedInputs.indexOf(input);
      return TransactionRecord(
        id: 'tx-$index',
        userId: input.userId,
        amount: input.amount,
        type: input.type,
        categoryId: input.categoryId,
        categoryName: input.categoryName,
        transactionDate: input.transactionDate,
        source: input.source,
        note: input.note,
      );
    }).toList();
  }
}

bool _isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}
