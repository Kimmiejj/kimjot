import 'package:flutter/material.dart';

import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/home_summary.dart';
import '../transactions/transaction_record.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_type.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  @override
  Widget build(BuildContext context) {
    return _DesignScaffold(
      status: 'FROM SUMMARY',
      smallLabel: 'Analytics',
      title: 'วิเคราะห์เดือนนี้',
      onBack: () => Navigator.of(context).maybePop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<HomeSummary>(
            stream: transactionRepository.watchCurrentMonthSummary(user.uid),
            builder: (context, snapshot) {
              final summary = snapshot.data ?? const HomeSummary.empty();
              return _SummaryCard(summary: summary);
            },
          ),
          const SizedBox(height: 14),
          const MascotTip(
            message:
                'Trends will get friendlier as you add more real transactions.',
            mood: MascotMood.calm,
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<TransactionRecord>>(
            stream: transactionRepository.watchTransactions(user.uid),
            builder: (context, snapshot) {
              final transactions = snapshot.data ?? const [];
              final categoryTotals = _expenseTotalsByCategory(transactions);

              if (categoryTotals.isEmpty) {
                return const _EmptyCard(
                  title: 'ยังไม่มีข้อมูลวิเคราะห์',
                  message: 'บันทึกรายจ่ายก่อน แล้วกราฟและหมวดที่ใช้เยอะจะขึ้นที่นี่',
                );
              }

              return _CategoryBreakdownCard(categoryTotals: categoryTotals);
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'แนวโน้มเดือนนี้',
            style: TextStyle(
              color: Color(0xFF123052),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(label: 'รายรับ', value: _formatMoney(summary.incomeTotal)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(label: 'รายจ่าย', value: _formatMoney(summary.expenseTotal)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Metric(label: 'คงเหลือ', value: _formatMoney(summary.balance)),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.categoryTotals});

  final Map<String, double> categoryTotals;

  @override
  Widget build(BuildContext context) {
    final total = categoryTotals.values.fold(0.0, (sum, value) => sum + value);
    final rows = categoryTotals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'หมวดที่ใช้เยอะสุด',
            style: TextStyle(
              color: Color(0xFF123052),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in rows.take(5)) ...[
            _ProgressRow(
              label: row.key,
              amount: row.value,
              progress: total == 0 ? 0 : row.value / total,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.amount,
    required this.progress,
  });

  final String label;
  final double amount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF10233F),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              _formatMoney(amount),
              style: const TextStyle(
                color: Color(0xFFD94768),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 12,
            backgroundColor: const Color(0x1F65748B),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF3268F6)),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x2E5D81AD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _mutedStyle),
          const SizedBox(height: 6),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF10233F),
                fontSize: 20,
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle),
          const SizedBox(height: 6),
          Text(message, style: _mutedStyle),
        ],
      ),
    );
  }
}

class _DesignScaffold extends StatelessWidget {
  const _DesignScaffold({
    required this.status,
    required this.smallLabel,
    required this.title,
    required this.child,
    required this.onBack,
  });

  final String status;
  final String smallLabel;
  final String title;
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
                const SizedBox(height: 4),
                Text(title, style: _pageTitleStyle),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Map<String, double> _expenseTotalsByCategory(List<TransactionRecord> records) {
  final totals = <String, double>{};
  for (final record in records) {
    if (record.type == TransactionType.expense) {
      totals.update(
        record.categoryName,
        (value) => value + record.amount,
        ifAbsent: () => record.amount,
      );
    }
  }
  return totals;
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

const _pageTitleStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 30,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _titleStyle = TextStyle(
  color: Color(0xFF123052),
  fontSize: 16,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _mutedStyle = TextStyle(
  color: Color(0xFF65748B),
  fontSize: 14,
  fontWeight: FontWeight.w700,
  height: 1.4,
  letterSpacing: 0,
);

const _statusStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 12,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

String _formatMoney(double amount) {
  final sign = amount < 0 ? '-' : '';
  return '$sign฿${_formatNumber(amount.abs())}';
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
