import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../auth/auth_user.dart';
import '../transactions/category_localization.dart';
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
    final strings = context.strings;
    final month = DateTime(DateTime.now().year, DateTime.now().month);

    return _DesignScaffold(
      status: strings.fromSummary,
      smallLabel: strings.analytics,
      title: strings.analyticsTitle,
      onBack: () => Navigator.of(context).maybePop(),
      headerBadge: const _HeaderBadge(label: '7'),
      child: StreamBuilder<List<TransactionRecord>>(
        stream: transactionRepository.watchMonthTransactions(user.uid, month),
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? const <TransactionRecord>[];
          final analytics = _MonthlyAnalytics.fromRecords(
            strings: strings,
            month: month,
            records: transactions,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DailyTrendCard(analytics: analytics),
              const SizedBox(height: 14),
              _CategoryDonutCard(analytics: analytics),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetricCard(
                      label: strings.isThai
                          ? 'ใช้เดือนนี้'
                          : 'Spent this month',
                      value: _formatMoney(analytics.expenseTotal),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniMetricCard(
                      label: strings.balance,
                      value: _formatMoney(analytics.balance),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DailyTrendCard extends StatelessWidget {
  const _DailyTrendCard({required this.analytics});

  final _MonthlyAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                strings.isThai ? 'แนวโน้มรายจ่าย' : 'Expense trend',
                style: _titleStyle,
              ),
              const Spacer(),
              Text(
                strings.isThai ? 'รายวัน' : 'Daily',
                style: _smallAccentStyle,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in analytics.dailyBars)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _TrendBar(
                        label: bar.label,
                        value: bar.amount,
                        maxValue: analytics.maxDailyExpense,
                      ),
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

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final double value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final heightFactor = maxValue <= 0
        ? 0.12
        : (value / maxValue).clamp(0.12, 1.0).toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF28C4D7), Color(0xFF3763F1)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: _tinyLabelStyle),
      ],
    );
  }
}

class _CategoryDonutCard extends StatelessWidget {
  const _CategoryDonutCard({required this.analytics});

  final _MonthlyAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final centerLabel = analytics.topCategoryLabel ??
        (strings.isThai ? 'ยังไม่มีข้อมูล' : 'No data');
    final centerValue = analytics.topCategoryPercent <= 0
        ? ''
        : '${analytics.topCategoryPercent.round()}%';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(context.strings.topCategories, style: _titleStyle),
              const Spacer(),
              Text(
                analytics.topCategoryLabel ??
                    (strings.isThai ? 'ไม่มี' : 'None'),
                style: _smallAccentStyle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(188),
                  painter: _DonutPainter(
                    segments: analytics.donutSegments,
                    emptyColor: const Color(0xFFD9E1F2),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        centerLabel,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF10233F),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (centerValue.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        centerValue,
                        style: const TextStyle(
                          color: Color(0xFF10233F),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x1D5D81AD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _smallAccentStyle),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A2D4C),
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

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFF3FBFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF21406E),
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
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
    this.headerBadge,
  });

  final String status;
  final String smallLabel;
  final String title;
  final Widget child;
  final VoidCallback onBack;
  final Widget? headerBadge;

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(smallLabel, style: _mutedStyle),
                          const SizedBox(height: 4),
                          Text(title, style: _pageTitleStyle),
                        ],
                      ),
                    ),
                    if (headerBadge != null) ...[
                      const SizedBox(width: 16),
                      headerBadge!,
                    ],
                  ],
                ),
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

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.segments, required this.emptyColor});

  final List<_DonutSegment> segments;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 32.0;
    const gap = 0.045;

    final basePaint = Paint()
      ..color = emptyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius - strokeWidth / 2, basePaint);

    if (segments.isEmpty) {
      return;
    }

    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      final sweepAngle = (math.pi * 2 * segment.fraction) - gap;
      if (sweepAngle <= 0) {
        continue;
      }

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.emptyColor != emptyColor;
  }
}

class _MonthlyAnalytics {
  const _MonthlyAnalytics({
    required this.dailyBars,
    required this.maxDailyExpense,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.balance,
    required this.topCategoryLabel,
    required this.topCategoryPercent,
    required this.donutSegments,
  });

  final List<_DailyBarPoint> dailyBars;
  final double maxDailyExpense;
  final double expenseTotal;
  final double incomeTotal;
  final double balance;
  final String? topCategoryLabel;
  final double topCategoryPercent;
  final List<_DonutSegment> donutSegments;

  factory _MonthlyAnalytics.fromRecords({
    required AppStrings strings,
    required DateTime month,
    required List<TransactionRecord> records,
  }) {
    final expenseRecords = records
        .where((record) => record.type == TransactionType.expense)
        .toList();
    final incomeTotal = records
        .where((record) => record.type == TransactionType.income)
        .fold(0.0, (sum, record) => sum + record.amount);
    final expenseTotal = expenseRecords.fold(
      0.0,
      (sum, record) => sum + record.amount,
    );

    final dayTotals = <int, double>{};
    for (final record in expenseRecords) {
      final day = record.transactionDate.day;
      dayTotals.update(day, (value) => value + record.amount, ifAbsent: () => record.amount);
    }

    final monthEndDay = _isSameMonth(month, DateTime.now())
        ? DateTime.now().day
        : DateUtils.getDaysInMonth(month.year, month.month);
    final startDay = math.max(1, monthEndDay - 6);
    final dailyBars = <_DailyBarPoint>[
      for (var day = startDay; day <= monthEndDay; day++)
        _DailyBarPoint(label: day.toString(), amount: dayTotals[day] ?? 0),
    ];
    final maxDailyExpense = dailyBars.fold<double>(
      0,
      (maxValue, point) => math.max(maxValue, point.amount).toDouble(),
    );

    final categoryTotals = <String, double>{};
    for (final record in expenseRecords) {
      final categoryName = localizedCategoryName(
        strings: strings,
        categoryId: record.categoryId,
        fallbackName: record.categoryName,
      );
      categoryTotals.update(
        categoryName,
        (value) => value + record.amount,
        ifAbsent: () => record.amount,
      );
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final totalExpense = sortedCategories.fold(
      0.0,
      (sum, entry) => sum + entry.value,
    );
    final topCategoryLabel = sortedCategories.isEmpty ? null : sortedCategories.first.key;
    final topCategoryPercent = sortedCategories.isEmpty || totalExpense <= 0
        ? 0.0
        : ((sortedCategories.first.value / totalExpense) * 100).toDouble();

    const palette = [
      Color(0xFF3763F1),
      Color(0xFF2CC4D8),
      Color(0xFF6B45EB),
      Color(0xFFB7C5E3),
    ];

    final donutSource = sortedCategories.take(4).toList();
    final donutSegments = <_DonutSegment>[];
    for (var i = 0; i < donutSource.length; i++) {
      final entry = donutSource[i];
      donutSegments.add(
        _DonutSegment(
          color: palette[i % palette.length],
          fraction: totalExpense <= 0 ? 0 : entry.value / totalExpense,
        ),
      );
    }

    return _MonthlyAnalytics(
      dailyBars: dailyBars,
      maxDailyExpense: maxDailyExpense,
      expenseTotal: expenseTotal,
      incomeTotal: incomeTotal,
      balance: incomeTotal - expenseTotal,
      topCategoryLabel: topCategoryLabel,
      topCategoryPercent: topCategoryPercent,
      donutSegments: donutSegments,
    );
  }
}

class _DailyBarPoint {
  const _DailyBarPoint({required this.label, required this.amount});

  final String label;
  final double amount;
}

class _DonutSegment {
  const _DonutSegment({required this.color, required this.fraction});

  final Color color;
  final double fraction;
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

const _smallAccentStyle = TextStyle(
  color: Color(0xFF6D7F97),
  fontSize: 14,
  fontWeight: FontWeight.w800,
  letterSpacing: 0,
);

const _tinyLabelStyle = TextStyle(
  color: Color(0xFF6D7F97),
  fontSize: 11,
  fontWeight: FontWeight.w800,
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

bool _isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}
