import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/category_icons.dart';
import '../transactions/category_localization.dart';
import '../transactions/home_summary.dart';
import '../transactions/manual_add_screen.dart';
import '../transactions/transaction_list_screen.dart';
import '../transactions/transaction_record.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_type.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.user,
    required this.transactionRepository,
    required this.onOpenScan,
    required this.onOpenSettings,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _currentMonth();
  }

  Future<void> _openPage(BuildContext context, Widget page) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (context) => page));

    if (!context.mounted) {
      return;
    }

    _resetToCurrentMonth();

    if (saved == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.transactionSaved)));
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
  }

  DateTime _currentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void _resetToCurrentMonth() {
    final currentMonth = _currentMonth();
    if (_isSameMonth(_selectedMonth, currentMonth)) {
      return;
    }

    setState(() {
      _selectedMonth = currentMonth;
    });
  }

  Future<void> _selectMonth() async {
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthYearPickerDialog(initialMonth: _selectedMonth),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedMonth = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      backgroundColor: const Color(0xFFF3FAFB),
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
                    displayName: widget.user.displayName ?? 'Kim',
                    selectedMonth: _selectedMonth,
                    onPreviousMonth: () => _changeMonth(-1),
                    onNextMonth: () => _changeMonth(1),
                    onSelectMonth: _selectMonth,
                    onSettings: widget.onOpenSettings,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _SummaryBuilder(
                    userId: widget.user.uid,
                    month: _selectedMonth,
                    transactionRepository: widget.transactionRepository,
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
                        user: widget.user,
                        transactionRepository: widget.transactionRepository,
                      ),
                    ),
                    onScan: widget.onOpenScan,
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
                    userId: widget.user.uid,
                    month: _selectedMonth,
                    transactionRepository: widget.transactionRepository,
                    onSeeMore: () => _openPage(
                      context,
                      TransactionListScreen(
                        user: widget.user,
                        transactionRepository: widget.transactionRepository,
                        initialMonth: _selectedMonth,
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
    required this.month,
    required this.transactionRepository,
    required this.builder,
  });

  final String userId;
  final DateTime month;
  final TransactionRepository transactionRepository;
  final Widget Function(HomeSummary summary) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HomeSummary>(
      stream: transactionRepository.watchMonthSummary(userId, month),
      builder: (context, snapshot) {
        return builder(snapshot.data ?? const HomeSummary.empty());
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.displayName,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectMonth,
    required this.onSettings,
  });

  final String displayName;
  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onSelectMonth;
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
              Row(
                children: [
                  _MonthArrowButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: strings.previousMonth,
                    onTap: onPreviousMonth,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: strings.isThai
                          ? 'เลือกเดือนและปี'
                          : 'Choose month and year',
                      child: InkWell(
                        onTap: onSelectMonth,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    strings.formatMonthYear(selectedMonth),
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF3268F6),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MonthArrowButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: strings.nextMonth,
                    onTap: onNextMonth,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _isSameMonth(selectedMonth, DateTime.now())
                    ? strings.thisMonth
                    : strings.otherMonth,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFEAFBFF), Color(0xFFF1FFF8)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26305472),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  strings.isThai ? 'เลือกเดือน' : 'Select month',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x245D81AD)),
              ),
              child: Row(
                children: [
                  _MonthArrowButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: strings.isThai ? 'ปีก่อนหน้า' : 'Previous year',
                    onTap: () => setState(() => _year--),
                  ),
                  Expanded(
                    child: Text(
                      '$_year',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  _MonthArrowButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: strings.isThai ? 'ปีถัดไป' : 'Next year',
                    onTap: () => setState(() => _year++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.05,
              ),
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected =
                    widget.initialMonth.year == _year &&
                    widget.initialMonth.month == month;

                return _MonthChoiceButton(
                  label: _monthLabel(context, month),
                  isSelected: isSelected,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(DateTime(_year, month)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthChoiceButton extends StatelessWidget {
  const _MonthChoiceButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const selectedBorderColor = Color(0xFF0C8C8C);
    final textColor = isSelected
        ? const Color(0xFF145A5A)
        : const Color(0xFF111827);
    final borderColor = isSelected
        ? selectedBorderColor
        : const Color(0x245D81AD);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE8F8F8)
              : Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.2 : 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1A0C8C8C),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x2E5D81AD)),
          ),
          child: Icon(icon, color: const Color(0xFF3268F6), size: 24),
        ),
      ),
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
    required this.month,
    required this.transactionRepository,
    required this.onSeeMore,
  });

  final String userId;
  final DateTime month;
  final TransactionRepository transactionRepository;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionRecord>>(
      stream: transactionRepository.watchMonthTransactions(
        userId,
        month,
        limit: 5,
      ),
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
      categoryIcon: categoryIconData(record.categoryId),
      title: title,
      subtitle: '${record.source.firestoreValue} · $categoryName',
      amount: '${_transactionPrefix(record.type)}${_formatMoney(record.amount)}',
      amountColor: _transactionColor(record.type),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({
    required this.categoryIcon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
  });

  final IconData categoryIcon;
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
              child: Icon(
                categoryIcon,
                color: const Color(0xFF334155),
                size: 22,
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


String _formatMoney(double amount) {
  final sign = amount < 0 ? '-' : '';
  return '${sign}THB ${_formatNumber(amount.abs())}';
}

String _transactionPrefix(TransactionType type) {
  return switch (type) {
    TransactionType.income => '+',
    TransactionType.expense => '-',
    TransactionType.internalTransfer => '↔',
  };
}

Color _transactionColor(TransactionType type) {
  return switch (type) {
    TransactionType.income => const Color(0xFF589F76),
    TransactionType.expense => const Color(0xFFB66A72),
    TransactionType.internalTransfer => const Color(0xFF168AA6),
  };
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

String _monthLabel(BuildContext context, int month) {
  final monthText = context.strings.formatMonthYear(DateTime(2000, month));
  return monthText.replaceFirst(' 2000', '');
}

bool _isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}
