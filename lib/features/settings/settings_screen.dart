import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_service.dart';
import '../auth/auth_user.dart';
import '../transactions/transaction_repository.dart';
import 'support_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.user,
    required this.authService,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final AuthService authService;
  final TransactionRepository transactionRepository;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return _SettingsScaffold(
      title: strings.settings,
      smallLabel: strings.settings,
      status: strings.privateData,
      onBack: () => Navigator.of(context).maybePop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileCard(user: user),
          const SizedBox(height: 14),
          MascotTip(message: strings.settingsTip),
          const SizedBox(height: 14),
          const _LanguageCard(),
          const SizedBox(height: 14),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: 'CT',
                title: strings.category,
                subtitle: strings.fixedCustom,
                onTap: () => _open(context, const CategoriesScreen()),
              ),
              _SettingsRow(
                icon: 'BG',
                title: strings.budget,
                subtitle: strings.monthlyAndCategory,
                onTap: () => _open(context, const BudgetsScreen()),
              ),
              _SettingsRow(
                icon: 'IN',
                title: strings.installments,
                subtitle: strings.fixedInstallment,
                onTap: () => _open(context, const InstallmentsScreen()),
              ),
              _SettingsRow(
                icon: 'SY',
                title: strings.syncStatus,
                subtitle: strings.firestoreOffline,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _AmountClassifierCard(),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => _signOut(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              foregroundColor: const Color(0xFF16345F),
              backgroundColor: Colors.white.withValues(alpha: 0.72),
              side: const BorderSide(color: Color(0x2E5D81AD)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(21),
              ),
            ),
            child: Text(
              strings.signOut,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
  }

  Future<void> _signOut(BuildContext context) async {
    await authService.signOut();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF62E4B6),
                  Color(0xFF1FC9DC),
                  Color(0xFF6A4DF4),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                (user.displayName?.trim().isNotEmpty ?? false)
                    ? user.displayName!.trim().characters.first.toUpperCase()
                    : 'K',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'Kim',
                  style: const TextStyle(
                    color: Color(0xFF10233F),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.email ?? 'Google account'} · Google account',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: _cardDecoration(),
      child: Column(children: children),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    final controller = context.languageController;
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(label: 'LA'),
              const SizedBox(width: 12),
              Expanded(child: Text(strings.language, style: _rowTitleStyle)),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<AppLanguage>(
            segments: [
              ButtonSegment(value: AppLanguage.th, label: Text(strings.thai)),
              ButtonSegment(
                value: AppLanguage.en,
                label: Text(strings.english),
              ),
            ],
            selected: {controller.language},
            onSelectionChanged: (selection) {
              controller.setLanguage(selection.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
              ),
              side: const WidgetStatePropertyAll(
                BorderSide(color: Color(0x2E5D81AD)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            _IconBadge(label: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _rowTitleStyle),
                  const SizedBox(height: 3),
                  Text(subtitle, style: _mutedStyle),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF65748B)),
          ],
        ),
      ),
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({
    required this.title,
    required this.smallLabel,
    required this.status,
    required this.child,
    required this.onBack,
  });

  final String title;
  final String smallLabel;
  final String status;
  final Widget child;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.72),
                        foregroundColor: const Color(0xFF10233F),
                      ),
                    ),
                    const Spacer(),
                    Text(status, style: _statusStyle),
                  ],
                ),
                const SizedBox(height: 18),
                Text(smallLabel, style: _mutedStyle),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x2E1FC9DC), Color(0x2E3268F6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF145CC8),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.76),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x1F1E3660),
        blurRadius: 36,
        offset: Offset(0, 16),
      ),
    ],
  );
}

const _rowTitleStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 15,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _mutedStyle = TextStyle(
  color: Color(0xFF65748B),
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.35,
  letterSpacing: 0,
);

const _statusStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 12,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

class _AmountClassifierCard extends StatelessWidget {
  const _AmountClassifierCard();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(label: 'AI'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.isThai ? 'โมเดล AI' : 'AI Model',
                  style: _rowTitleStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strings.isThai
                ? 'ปรับปรุงการทำงานของ AI โดยการฝึกและตั้งค่า'
                : 'Improve AI by training and configuring model weights',
            style: _mutedStyle,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          strings.isThai ? 'ลบข้อมูลโมเดล' : 'Reset Model',
                        ),
                        content: Text(
                          strings.isThai
                              ? 'ลบข้อมูลการฝึกทั้งหมดและเริ่มใหม่?'
                              : 'Delete all training data and reset model?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(strings.isThai ? 'ยกเลิก' : 'Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(strings.isThai ? 'ลบ' : 'Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('amount_classifier_weights');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              strings.isThai ? 'ลบแล้ว' : 'Reset complete',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(strings.isThai ? 'รีเซ็ต' : 'Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
