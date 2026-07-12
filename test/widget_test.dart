import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimjod/app/app_language.dart';
import 'package:kimjod/features/auth/auth_gate.dart';
import 'package:kimjod/features/auth/auth_service.dart';
import 'package:kimjod/features/auth/auth_user.dart';
import 'package:kimjod/features/auth/login_screen.dart';
import 'package:kimjod/features/transactions/create_transaction_input.dart';
import 'package:kimjod/features/transactions/home_summary.dart';
import 'package:kimjod/features/transactions/transaction_repository.dart';
import 'package:kimjod/features/transactions/transaction_record.dart';
import 'package:kimjod/features/transactions/transaction_type.dart';

void main() {
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

    await tester.tap(find.text('+\nAdd'));
    await tester.pumpAndSettle();

    expect(find.text('Add transaction'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '125.50');
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
    expect(find.text('-THB 126'), findsWidgets);
    expect(find.text('THB 126'), findsOneWidget);

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
  Future<void> createManualTransaction(CreateTransactionInput input) async {
    savedInputs.add(input);
    _summaryController.add(_buildSummary());
    _transactionsController.add(_buildTransactions());
  }

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
  Stream<List<TransactionRecord>> watchRecentTransactions(
    String userId, {
    int limit = 5,
  }) {
    return _transactionsController.stream.map(
      (transactions) => transactions.take(limit).toList(),
    );
  }

  @override
  Stream<List<TransactionRecord>> watchTransactions(String userId) {
    return _transactionsController.stream;
  }

  HomeSummary _buildSummary() {
    var incomeTotal = 0.0;
    var expenseTotal = 0.0;

    for (final input in savedInputs) {
      if (input.type == TransactionType.income) {
        incomeTotal += input.amount;
      } else {
        expenseTotal += input.amount;
      }
    }

    return HomeSummary(
      incomeTotal: incomeTotal,
      expenseTotal: expenseTotal,
      transactionCount: savedInputs.length,
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
