import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../analytics/analytics_screen.dart';
import '../auth/auth_service.dart';
import '../auth/auth_user.dart';
import '../scan/scan_hub_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/category_localization.dart';
import '../transactions/home_summary.dart';
import '../transactions/manual_add_screen.dart';
import '../transactions/transaction_list_screen.dart';
import '../transactions/transaction_record.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_type.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.user,
    required this.authService,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final AuthService authService;
  final TransactionRepository transactionRepository;

  Future<void> _openPage(BuildContext context, Widget page) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (context) => page));

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.transactionSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF3FAFB),
      bottomNavigationBar: _FloatingHomeNavigationBar(
        onHome: () {},
        onScan: () => _openPage(
          context,
          ScanHubScreen(
            user: user,
            transactionRepository: transactionRepository,
          ),
        ),
        onGraph: () => _openPage(
          context,
          AnalyticsScreen(
            user: user,
            transactionRepository: transactionRepository,
          ),
        ),
        onSettings: () => _openPage(
          context,
          SettingsScreen(
            user: user,
            authService: authService,
            transactionRepository: transactionRepository,
          ),
        ),
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
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _HomeHeader(
                    displayName: user.displayName ?? 'Kim',
                    onSettings: () => _openPage(
                      context,
                      SettingsScreen(
                        user: user,
                        authService: authService,
                        transactionRepository: transactionRepository,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _SummaryBuilder(
                    userId: user.uid,
                    transactionRepository: transactionRepository,
                    builder: (summary) => _BalancePanel(summary: summary),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _QuickActions(
                    onAdd: () => _openPage(
                      context,
                      ManualAddScreen(
                        user: user,
                        transactionRepository: transactionRepository,
                      ),
                    ),
                    onScan: () => _openPage(
                      context,
                      ScanHubScreen(
                        user: user,
                        transactionRepository: transactionRepository,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _EmptyInfoCard(
                    title: strings.budget,
                    message: strings.noBudget,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(title: strings.installments),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _EmptyInfoCard(
                    title: strings.noDueInstallment,
                    message: strings.installmentHint,
                    icon: Icons.event_available_rounded,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(title: strings.recentTransactions),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 112),
                sliver: SliverToBoxAdapter(
                  child: _RecentTransactionsBuilder(
                    userId: user.uid,
                    transactionRepository: transactionRepository,
                    onSeeMore: () => _openPage(
                      context,
                      TransactionListScreen(
                        user: user,
                        transactionRepository: transactionRepository,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBuilder extends StatelessWidget {
  const _SummaryBuilder({
    required this.userId,
    required this.transactionRepository,
    required this.builder,
  });

  final String userId;
  final TransactionRepository transactionRepository;
  final Widget Function(HomeSummary summary) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HomeSummary>(
      stream: transactionRepository.watchCurrentMonthSummary(userId),
      builder: (context, snapshot) {
        return builder(snapshot.data ?? const HomeSummary.empty());
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.displayName, required this.onSettings});

  final String displayName;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.synced,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                strings.hello(displayName),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.thisMonth,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: strings.settings,
          child: InkWell(
            onTap: onSettings,
            borderRadius: BorderRadius.circular(24),
            child: const KimjodMascot(size: 64),
          ),
        ),
      ],
    );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FEFD), Color(0xFFE7FAF8), Color(0xFFEAFBF1)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C7DCFC7),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.monthlyBalance,
            style: TextStyle(
              color: Color(0xFF5B7F84),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatMoney(summary.balance),
              style: const TextStyle(
                color: Color(0xFF17383D),
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BalanceMetric(
                  label: strings.income,
                  value: _formatMoney(summary.incomeTotal),
                  valueColor: const Color(0xFF1B8F73),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceMetric(
                  label: strings.expense,
                  value: _formatMoney(summary.expenseTotal),
                  valueColor: const Color(0xFFB66A72),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAdd, required this.onScan});

  final VoidCallback onAdd;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            label: '+\n${strings.add}',
            onTap: onAdd,
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            foregroundColor: const Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            label: strings.scanSlip,
            onTap: onScan,
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            foregroundColor: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14305472),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.18,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyInfoCard extends StatelessWidget {
  const _EmptyInfoCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10305472),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EDF4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF475569), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentTransactionsBuilder extends StatelessWidget {
  const _RecentTransactionsBuilder({
    required this.userId,
    required this.transactionRepository,
    required this.onSeeMore,
  });

  final String userId;
  final TransactionRepository transactionRepository;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionRecord>>(
      stream: transactionRepository.watchRecentTransactions(userId, limit: 5),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? const [];

        if (transactions.isEmpty) {
          return _EmptyInfoCard(
            title: context.strings.noTransactionsYet,
            message: context.strings.savedTransactionsHint,
            icon: Icons.receipt_long_rounded,
          );
        }

        return Column(
          children: [
            for (var index = 0; index < transactions.length; index++) ...[
              _TransactionListTile(record: transactions[index]),
              if (index != transactions.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSeeMore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF16345F),
                  backgroundColor: Colors.white.withValues(alpha: 0.72),
                  side: const BorderSide(color: Color(0x2E5D81AD)),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  context.strings.seeMore,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TransactionListTile extends StatelessWidget {
  const _TransactionListTile({required this.record});

  final TransactionRecord record;

  @override
  Widget build(BuildContext context) {
    final isIncome = record.type == TransactionType.income;
    final categoryName = localizedCategoryName(
      strings: context.strings,
      categoryId: record.categoryId,
      fallbackName: record.categoryName,
    );
    final title = localizedTransactionTitle(
      strings: context.strings,
      categoryId: record.categoryId,
      categoryName: record.categoryName,
      note: record.note,
      merchantName: record.merchantName,
    );

    return _ListTileCard(
      badge: _badgeFor(categoryName),
      title: title,
      subtitle: '${record.source.firestoreValue} · $categoryName',
      amount: '${isIncome ? '+' : '-'}${_formatMoney(record.amount)}',
      amountColor: isIncome ? const Color(0xFF589F76) : const Color(0xFFB66A72),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EDF4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                badge,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: amountColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingHomeNavigationBar extends StatelessWidget {
  const _FloatingHomeNavigationBar({
    required this.onHome,
    required this.onScan,
    required this.onGraph,
    required this.onSettings,
  });

  final VoidCallback onHome;
  final VoidCallback onScan;
  final VoidCallback onGraph;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26305472),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: strings.home,
              onTap: onHome,
            ),
            _NavItem(
              icon: Icons.crop_square_rounded,
              label: strings.scan,
              onTap: onScan,
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: strings.graph,
              onTap: onGraph,
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: strings.settings,
              onTap: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(double amount) {
  final sign = amount < 0 ? '-' : '';
  return '${sign}THB ${_formatNumber(amount.abs())}';
}

String _formatNumber(double amount) {
  final digits = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _badgeFor(String value) {
  final letters = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part.characters.first.toUpperCase())
      .take(2)
      .join();
  return letters.isEmpty ? 'TX' : letters;
}
