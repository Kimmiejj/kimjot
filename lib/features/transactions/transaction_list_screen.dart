import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/formatters/money_formatter.dart';
import '../../shared/widgets/month_year_picker_dialog.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import 'category_icons.dart';
import 'category_localization.dart';
import 'manual_transaction_sheet.dart';
import 'transaction_record.dart';
import 'transaction_repository.dart';
import 'transaction_type.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({
    required this.user,
    required this.transactionRepository,
    this.initialMonth,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final DateTime? initialMonth;

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  late DateTime _selectedMonth;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    _selectedMonth = DateTime(initial.year, initial.month);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
  }

  Future<void> _selectMonth() async {
    final selected = await showMonthYearPickerDialog(
      context: context,
      initialMonth: _selectedMonth,
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedMonth = selected);
  }

  void _setSearchQuery(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _setSearchQuery('');
  }

  Future<void> _editTransaction(TransactionRecord record) async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FFFF),
      builder: (context) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE7FFF4), Color(0xFFEAFBFF), Color(0xFFF7F4FF)],
            ),
          ),
          child: ManualTransactionSheet(
            user: widget.user,
            transactionRepository: widget.transactionRepository,
            source: record.source,
            title: 'Edit transaction',
            description: localizedCategoryName(
              strings: context.strings,
              categoryId: record.categoryId,
              fallbackName: record.categoryName,
            ),
            initialType: record.type,
            initialAmount: record.amount,
            initialNote: record.note,
            initialDate: record.transactionDate,
            initialDateText: context.strings.formatDate(record.transactionDate),
            existingRecord: record,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFF),
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _TransactionsHeader(
                    selectedMonth: _selectedMonth,
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    onPreviousMonth: () => _changeMonth(-1),
                    onNextMonth: () => _changeMonth(1),
                    onSelectMonth: _selectMonth,
                    onSearchChanged: _setSearchQuery,
                    onClearSearch: _clearSearch,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                sliver: StreamBuilder<List<TransactionRecord>>(
                  stream: widget.transactionRepository.watchMonthTransactions(
                    widget.user.uid,
                    _selectedMonth,
                  ),
                  builder: (context, snapshot) {
                    final records = snapshot.data ?? const [];
                    final transactions = _filterTransactions(
                      context,
                      records,
                      _searchQuery,
                    );

                    if (transactions.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: _EmptyTransactionsCard(),
                      );
                    }

                    return SliverList.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final record = transactions[index];
                        final startsNewDay = index == 0 ||
                            !_isSameDate(
                              transactions[index - 1].transactionDate,
                              record.transactionDate,
                            );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (startsNewDay)
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  2,
                                  index == 0 ? 0 : 18,
                                  2,
                                  10,
                                ),
                                child: Text(
                                  context.strings.formatDate(
                                    record.transactionDate,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF123052),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            TransactionRow(
                              record: record,
                              onTap: () => _editTransaction(record),
                            ),
                            if (index != transactions.length - 1 &&
                                _isSameDate(
                                  record.transactionDate,
                                  transactions[index + 1].transactionDate,
                                ))
                              const SizedBox(height: 10),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionsHeader extends StatelessWidget {
  const _TransactionsHeader({
    required this.selectedMonth,
    required this.searchController,
    required this.searchQuery,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectMonth,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onBack,
  });

  final DateTime selectedMonth;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onSelectMonth;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: context.strings.back,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.72),
                foregroundColor: const Color(0xFF10233F),
              ),
            ),
            const Spacer(),
            Text(
              context.strings.synced,
              style: const TextStyle(
                color: Color(0xFF65748B),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Align(
          alignment: Alignment.centerRight,
          child: KimjodMascot(size: 62, mood: MascotMood.calm),
        ),
        const SizedBox(height: 8),
        Text(
          context.strings.history,
          style: const TextStyle(
            color: Color(0xFF65748B),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onSelectMonth,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    context.strings.formatMonthYear(selectedMonth),
                    style: const TextStyle(
                      color: Color(0xFF10233F),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF3268F6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MonthControlButton(
              icon: Icons.chevron_left_rounded,
              tooltip: context.strings.previousMonth,
              onTap: onPreviousMonth,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                DateTime.now().year == selectedMonth.year &&
                        DateTime.now().month == selectedMonth.month
                    ? context.strings.thisMonth
                    : context.strings.otherMonth,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF65748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _MonthControlButton(
              icon: Icons.chevron_right_rounded,
              tooltip: context.strings.nextMonth,
              onTap: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            color: Color(0xFF10233F),
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            hintText: context.strings.searchPlaceholder,
            hintStyle: const TextStyle(
              color: Color(0xFF65748B),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF65748B),
            ),
            suffixIcon: searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF65748B),
                    tooltip: 'Clear search',
                  ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.78),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: Color(0x2E7092BE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: Color(0x2E7092BE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(
                color: Color(0x803268F6),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<TransactionRecord> _filterTransactions(
  BuildContext context,
  List<TransactionRecord> records,
  String query,
) {
  if (query.isEmpty) {
    return records;
  }

  final strings = context.strings;
  return records.where((record) {
    final categoryName = localizedCategoryName(
      strings: strings,
      categoryId: record.categoryId,
      fallbackName: record.categoryName,
    );
    final title = localizedTransactionTitle(
      strings: strings,
      categoryId: record.categoryId,
      categoryName: record.categoryName,
      note: record.note,
      merchantName: record.merchantName,
    );
    final searchableText = [
      title,
      categoryName,
      record.categoryId,
      record.categoryName,
      record.note,
      record.merchantName,
      record.source.firestoreValue,
      ..._amountSearchTerms(record),
      strings.formatMonthYear(record.transactionDate),
      strings.formatDate(record.transactionDate),
      _formatDateSection(record.transactionDate),
    ].whereType<String>().join(' ').toLowerCase();

    return searchableText.contains(query);
  }).toList();
}

List<String> _amountSearchTerms(TransactionRecord record) {
  final amount = record.amount.abs();
  final fixedAmount = amount.toStringAsFixed(2);
  final wholeAmount = amount.roundToDouble() == amount
      ? amount.toStringAsFixed(0)
      : null;
  final formattedAmount = _formatNumber(amount);
  final signedAmount = _formatTransferAwareMoney(record);
  final sign = switch (record.type) {
    TransactionType.income => '+',
    TransactionType.expense => '-',
    TransactionType.internalTransfer => '',
  };

  return [
    fixedAmount,
    wholeAmount,
    formattedAmount,
    signedAmount,
    'THB $fixedAmount',
    'THB $formattedAmount',
    '฿$fixedAmount',
    '฿$formattedAmount',
    if (sign.isNotEmpty) '$sign$fixedAmount',
    if (sign.isNotEmpty) '$sign$formattedAmount',
  ].whereType<String>().toList();
}

class _MonthControlButton extends StatelessWidget {
  const _MonthControlButton({
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
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        color: const Color(0xFF3268F6),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class TransactionRow extends StatelessWidget {
  const TransactionRow({required this.record, this.onTap, super.key});

  final TransactionRecord record;
  final VoidCallback? onTap;

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

    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x245D81AD)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EDF4),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Icon(
                    categoryIconData(record.categoryId),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF10233F),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${context.strings.formatTime(record.transactionDate)} · '
                      '${record.source.firestoreValue} · $categoryName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTransferAwareMoney(record),
                    style: TextStyle(
                      color: _transactionAmountColor(record.type),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Edit',
                    style: TextStyle(
                      color: Color(0xFF65748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactionsCard extends StatelessWidget {
  const _EmptyTransactionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        context.strings.noSavedTransactions,
        style: const TextStyle(
          color: Color(0xFF65748B),
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

// ignore: unused_element
String _formatSignedMoney(TransactionRecord record) {
  final sign = record.type == TransactionType.income ? '+' : '-';
  return '$sign฿${_formatNumber(record.amount)}';
}

String _formatTransferAwareMoney(TransactionRecord record) {
  if (record.type == TransactionType.internalTransfer) {
    return 'THB ${_formatNumber(record.amount)}';
  }
  final sign = switch (record.type) {
    TransactionType.income => '+',
    TransactionType.expense => '-',
    TransactionType.internalTransfer => '↔',
  };
  return '$sign฿${_formatNumber(record.amount)}';
}

Color _transactionAmountColor(TransactionType type) {
  return switch (type) {
    TransactionType.income => const Color(0xFF18B98E),
    TransactionType.expense => const Color(0xFFD94768),
    TransactionType.internalTransfer => const Color(0xFF168AA6),
  };
}

String _formatNumber(double value) {
  return formatOriginalNumber(value);
}

String _formatDateSection(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
