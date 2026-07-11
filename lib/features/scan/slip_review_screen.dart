import 'package:flutter/material.dart';

import '../auth/auth_user.dart';
import '../transactions/manual_transaction_sheet.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';

class SlipReviewScreen extends StatelessWidget {
  const SlipReviewScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4FBFC),
        title: const Text('Slip Review'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: ManualTransactionForm(
            user: user,
            transactionRepository: transactionRepository,
            source: TransactionSource.gallerySlip,
            title: 'Review slip',
            description:
                'Page 5. OCR will prefill this later. For now, confirm the slip amount manually.',
            initialType: TransactionType.expense,
            onSaved: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    );
  }
}
