import 'package:flutter/material.dart';

import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/transaction_repository.dart';
import 'slip_review_screen.dart';

class ScanHubScreen extends StatelessWidget {
  const ScanHubScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  Future<void> _openSlipReview(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SlipReviewScreen(
          user: user,
          transactionRepository: transactionRepository,
        ),
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Scan Hub'),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                'Page 4',
                style: TextStyle(
                  color: Color(0xFF65748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              const MascotTip(
                message:
                    'Pick a slip or QR route. Images stay private and are used only for reading.',
                mood: MascotMood.calm,
              ),
              const SizedBox(height: 16),
              _ScanOption(
                icon: Icons.document_scanner_rounded,
                title: 'Scan slip',
                subtitle: 'Open slip review. OCR engine comes next.',
                onTap: () => _openSlipReview(context),
              ),
              const SizedBox(height: 12),
              const _ScanOption(
                icon: Icons.photo_library_rounded,
                title: 'Import from gallery',
                subtitle: 'Coming next after the save flow is stable.',
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF3268F6), size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF071844),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF65748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF65748B)),
            ],
          ),
        ),
      ),
    );
  }
}
