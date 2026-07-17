import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import 'manual_transaction_sheet.dart';
import 'transaction_repository.dart';
import 'transaction_source.dart';
import 'transaction_type.dart';

class ManualAddScreen extends StatelessWidget {
  const ManualAddScreen({
    required this.user,
    required this.transactionRepository,
    this.initialType = TransactionType.expense,
    this.initialDate,
    this.initialAmount,
    this.initialNote,
    this.initialCategoryId,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final TransactionType initialType;
  final DateTime? initialDate;
  final double? initialAmount;
  final String? initialNote;
  final String? initialCategoryId;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final strings = context.strings;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5EF), Color(0xFFEAF8F2), Color(0xFFFFF4ED)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(22, 18, 22, bottomInset + 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: const Color(0xFF10233F),
                      tooltip: strings.back,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                MascotTip(message: strings.addTransactionTip),
                const SizedBox(height: 18),
                ManualTransactionForm(
                  user: user,
                  transactionRepository: transactionRepository,
                  source: TransactionSource.manual,
                  title: strings.addTransaction,
                  description: strings.addTransactionTip,
                  initialType: initialType,
                  initialDate: initialDate,
                  initialAmount: initialAmount,
                  initialNote: initialNote,
                  initialCategoryId: initialCategoryId,
                  onSaved: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
