import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import 'transaction_record.dart';
import 'transaction_repository.dart';
import 'transaction_type.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE7FFF4),
              Color(0xFFEAFBFF),
              Color(0xFFF7F4FF),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _TransactionsHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                sliver: StreamBuilder<List<TransactionRecord>>(
                  stream: transactionRepository.watchTransactions(user.uid),
                  builder: (context, snapshot) {
                    final transactions = snapshot.data ?? const [];

                    if (transactions.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: _EmptyTransactionsCard(),
                      );
                    }

                    return SliverList.separated(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        return TransactionRow(record: transactions[index]);
                      },
                      separatorBuilder: (context, index) {
                        final current = transactions[index].transactionDate;
                        final next = transactions[index + 1].transactionDate;
                        if (_isSameDate(current, next)) {
                          return const SizedBox(height: 10);
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
                          child: Text(
                            _formatDateSection(next),
                            style: const TextStyle(
                              color: Color(0xFF123052),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
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
  const _TransactionsHeader({required this.onBack});

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
        Text(
          context.strings.allTransactions,
          style: const TextStyle(
            color: Color(0xFF10233F),
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x2E7092BE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Color(0xFF65748B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.strings.searchPlaceholder,
                  style: const TextStyle(
                    color: Color(0xFF65748B),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TransactionRow extends StatelessWidget {
  const TransactionRow({required this.record, super.key});

  final TransactionRecord record;

  @override
  Widget build(BuildContext context) {
    final isIncome = record.type == TransactionType.income;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0x2E1FC9DC),
                  Color(0x2E3268F6),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                _categoryBadge(record.categoryName),
                style: const TextStyle(
                  color: Color(0xFF145CC8),
                  fontSize: 13,
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
                  record.displayTitle,
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
                  '${record.source.firestoreValue} · ${record.categoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF65748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatSignedMoney(record),
            style: TextStyle(
              color: isIncome ? const Color(0xFF18B98E) : const Color(0xFFD94768),
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

String _categoryBadge(String value) {
  final letters = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part.characters.first.toUpperCase())
      .take(2)
      .join();
  return letters.isEmpty ? 'TX' : letters;
}

String _formatSignedMoney(TransactionRecord record) {
  final sign = record.type == TransactionType.income ? '+' : '-';
  return '$sign฿${_formatNumber(record.amount)}';
}

String _formatNumber(double value) {
  final whole = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatDateSection(DateTime date) {
  const months = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
