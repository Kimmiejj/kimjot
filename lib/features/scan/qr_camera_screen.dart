import 'package:flutter/material.dart';

import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/manual_transaction_sheet.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';

class QrCameraScreen extends StatelessWidget {
  const QrCameraScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('QR Camera'),
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7FFF4), Color(0xFFEAFBFF), Color(0xFFF7F4FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MascotTip(
                  message:
                      'QR reading is only for prefilling details. kimjod never makes payments.',
                  mood: MascotMood.calm,
                ),
                const SizedBox(height: 14),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2353),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ManualTransactionForm(
                  user: user,
                  transactionRepository: transactionRepository,
                  source: TransactionSource.qrCamera,
                  title: 'Review QR',
                  description:
                      'Page 6. Camera parsing will prefill this later. For now, enter the QR amount manually.',
                  initialType: TransactionType.expense,
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
