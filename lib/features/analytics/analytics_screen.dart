import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../auth/auth_user.dart';
import '../transactions/category_localization.dart';
import '../transactions/transaction_record.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_type.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    required this.user,
    required this.transactionRepository,
    this.onBack,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final VoidCallback? onBack;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late DateTime _selectedMonth;
  _TrendViewMode _selectedView = _TrendViewMode.daily;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _currentMonth();
  }

  DateTime _currentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
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
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) =>
          _MonthYearPickerDialog(initialMonth: _selectedMonth),
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
    final month = _selectedMonth;

    return _DesignScaffold(
      status: strings.fromSummary,
      smallLabel: strings.analytics,
      title: strings.analyticsTitle,
      onBack: widget.onBack,
      selectedMonth: month,
      onPreviousMonth: () => _changeMonth(-1),
      onNextMonth: () => _changeMonth(1),
      onSelectMonth: _selectMonth,
      child: StreamBuilder<List<TransactionRecord>>(
        stream: widget.transactionRepository.watchTransactions(widget.user.uid),
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? const <TransactionRecord>[];
          final analytics = _TrendAnalytics.fromRecords(
            strings: strings,
            month: month,
            records: transactions,
            selectedView: _selectedView,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ExpenseTrendCard(
                analytics: analytics,
                selectedView: _selectedView,
                onViewChanged: (view) {
                  setState(() {
                    _selectedView = view;
                  });
                },
              ),
              const SizedBox(height: 14),
              _CategoryDonutCard(analytics: analytics),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetricCard(
                      label: strings.isThai
                          ? 'ใช้ในช่วงที่เลือก'
                          : 'Spent in selected period',
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

enum _TrendViewMode { daily, monthly, yearly }

class _ExpenseTrendCard extends StatelessWidget {
  const _ExpenseTrendCard({
    required this.analytics,
    required this.selectedView,
    required this.onViewChanged,
  });

  final _TrendAnalytics analytics;
  final _TrendViewMode selectedView;
  final ValueChanged<_TrendViewMode> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings.isThai
                          ? 'แนวโน้มรายจ่าย'
                          : 'Expense trend',
                      style: _titleStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      analytics.periodLabel,
                      style: _smallAccentStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _TrendViewSwitcher(
                selectedView: selectedView,
                onChanged: onViewChanged,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(
                  MediaQuery.sizeOf(context).width - 80,
                  analytics.points.length * _trendBarWidth,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in analytics.points)
                      SizedBox(
                        width: _trendBarWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _TrendBar(
                            label: point.label,
                            value: point.amount,
                            maxValue: analytics.maxPointAmount,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendViewSwitcher extends StatelessWidget {
  const _TrendViewSwitcher({
    required this.selectedView,
    required this.onChanged,
  });

  final _TrendViewMode selectedView;
  final ValueChanged<_TrendViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        for (final view in _TrendViewMode.values)
          _TrendChip(
            label: _viewLabel(context.strings, view),
            isSelected: selectedView == view,
            onTap: () => onChanged(view),
          ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE7F1FF)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3763F1)
                : const Color(0x245D81AD),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF1F4FD6)
                : const Color(0xFF6D7F97),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
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
        ? 0.06
        : (value / maxValue).clamp(0.06, 1.0).toDouble();

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

  final _TrendAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final centerLabel =
        analytics.topCategoryLabel ??
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
          if (analytics.topCategories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              children: [
                for (final category in analytics.topCategories)
                  _CategoryLegendRow(category: category),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({required this.category});

  final _TopCategory category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF123052),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${category.percent.round()}%', style: _smallAccentStyle),
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

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectMonth,
  });

  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onSelectMonth;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Row(
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
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x2E5D81AD)),
                ),
                child: Row(
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
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF3268F6),
                      size: 22,
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
                  label: _monthLabel(context.strings, month),
                  isSelected: isSelected,
                  onTap: () =>
                      Navigator.of(context).pop(DateTime(_year, month)),
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
          border: Border.all(color: borderColor, width: isSelected ? 2.2 : 1),
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

class _DesignScaffold extends StatelessWidget {
  const _DesignScaffold({
    required this.status,
    required this.smallLabel,
    required this.title,
    required this.child,
    required this.onBack,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectMonth,
  });

  final String status;
  final String smallLabel;
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onSelectMonth;

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
                    if (onBack != null)
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
                          const SizedBox(height: 12),
                          _MonthSelector(
                            selectedMonth: selectedMonth,
                            onPreviousMonth: onPreviousMonth,
                            onNextMonth: onNextMonth,
                            onSelectMonth: onSelectMonth,
                          ),
                        ],
                      ),
                    ),
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

class _TrendAnalytics {
  const _TrendAnalytics({
    required this.points,
    required this.maxPointAmount,
    required this.periodLabel,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.balance,
    required this.topCategoryLabel,
    required this.topCategoryPercent,
    required this.topCategories,
    required this.donutSegments,
  });

  final List<_TrendPoint> points;
  final double maxPointAmount;
  final String periodLabel;
  final double expenseTotal;
  final double incomeTotal;
  final double balance;
  final String? topCategoryLabel;
  final double topCategoryPercent;
  final List<_TopCategory> topCategories;
  final List<_DonutSegment> donutSegments;

  factory _TrendAnalytics.fromRecords({
    required AppStrings strings,
    required DateTime month,
    required List<TransactionRecord> records,
    required _TrendViewMode selectedView,
  }) {
    final periodRecords = records
        .where(
          (record) =>
              _matchesView(record.transactionDate, month, selectedView),
        )
        .toList();
    final expenseRecords = periodRecords
        .where((record) => record.type == TransactionType.expense)
        .toList();
    final incomeTotal = periodRecords
        .where((record) => record.type == TransactionType.income)
        .fold(0.0, (sum, record) => sum + record.amount);
    final expenseTotal = expenseRecords.fold(
      0.0,
      (sum, record) => sum + record.amount,
    );

    final points = _buildTrendPoints(
      strings: strings,
      month: month,
      records: expenseRecords,
      selectedView: selectedView,
    );
    final maxPointAmount = points.fold<double>(
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
    final topCategoryLabel = sortedCategories.isEmpty
        ? null
        : sortedCategories.first.key;
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
    final topCategories = <_TopCategory>[];
    for (var i = 0; i < donutSource.length; i++) {
      final entry = donutSource[i];
      final color = palette[i % palette.length];
      donutSegments.add(
        _DonutSegment(
          color: color,
          fraction: totalExpense <= 0 ? 0 : entry.value / totalExpense,
        ),
      );
      topCategories.add(
        _TopCategory(
          color: color,
          label: entry.key,
          percent: totalExpense <= 0 ? 0 : (entry.value / totalExpense) * 100,
        ),
      );
    }

    return _TrendAnalytics(
      points: points,
      maxPointAmount: maxPointAmount,
      periodLabel: _periodLabel(strings, month, selectedView),
      expenseTotal: expenseTotal,
      incomeTotal: incomeTotal,
      balance: incomeTotal - expenseTotal,
      topCategoryLabel: topCategoryLabel,
      topCategoryPercent: topCategoryPercent,
      topCategories: topCategories,
      donutSegments: donutSegments,
    );
  }
}

class _TrendPoint {
  const _TrendPoint({required this.label, required this.amount});

  final String label;
  final double amount;
}

class _DonutSegment {
  const _DonutSegment({required this.color, required this.fraction});

  final Color color;
  final double fraction;
}

class _TopCategory {
  const _TopCategory({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final double percent;
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

const _trendBarWidth = 38.0;

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

String _monthLabel(AppStrings strings, int month) {
  final months = strings.isThai
      ? const [
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
        ]
      : const [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
  return months[month - 1];
}

String _monthShortLabel(AppStrings strings, int month) {
  final months = strings.isThai
      ? const [
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
        ]
      : const [
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
  return months[month - 1];
}

bool _isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}

bool _matchesView(
  DateTime transactionDate,
  DateTime selectedMonth,
  _TrendViewMode selectedView,
) {
  return switch (selectedView) {
    _TrendViewMode.daily => _isSameMonth(transactionDate, selectedMonth),
    _TrendViewMode.monthly => transactionDate.year == selectedMonth.year,
    _TrendViewMode.yearly => true,
  };
}

List<_TrendPoint> _buildTrendPoints({
  required AppStrings strings,
  required DateTime month,
  required List<TransactionRecord> records,
  required _TrendViewMode selectedView,
}) {
  return switch (selectedView) {
    _TrendViewMode.daily => _buildDailyPoints(month, records),
    _TrendViewMode.monthly => _buildMonthlyPoints(strings, records),
    _TrendViewMode.yearly => _buildYearlyPoints(month, records),
  };
}

List<_TrendPoint> _buildDailyPoints(
  DateTime month,
  List<TransactionRecord> records,
) {
  final dayTotals = <int, double>{};
  for (final record in records) {
    final day = record.transactionDate.day;
    dayTotals.update(
      day,
      (value) => value + record.amount,
      ifAbsent: () => record.amount,
    );
  }

  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
  return [
    for (var day = 1; day <= daysInMonth; day++)
      _TrendPoint(label: day.toString(), amount: dayTotals[day] ?? 0),
  ];
}

List<_TrendPoint> _buildMonthlyPoints(
  AppStrings strings,
  List<TransactionRecord> records,
) {
  final monthTotals = <int, double>{};
  for (final record in records) {
    final recordMonth = record.transactionDate.month;
    monthTotals.update(
      recordMonth,
      (value) => value + record.amount,
      ifAbsent: () => record.amount,
    );
  }

  return [
    for (var monthIndex = 1; monthIndex <= 12; monthIndex++)
      _TrendPoint(
        label: _monthShortLabel(strings, monthIndex),
        amount: monthTotals[monthIndex] ?? 0,
      ),
  ];
}

List<_TrendPoint> _buildYearlyPoints(
  DateTime month,
  List<TransactionRecord> records,
) {
  final yearTotals = <int, double>{};
  for (final record in records) {
    final year = record.transactionDate.year;
    yearTotals.update(
      year,
      (value) => value + record.amount,
      ifAbsent: () => record.amount,
    );
  }

  if (yearTotals.isEmpty) {
    return [_TrendPoint(label: month.year.toString(), amount: 0)];
  }

  final years = yearTotals.keys.toList()..sort();
  return [
    for (final year in years)
      _TrendPoint(label: year.toString(), amount: yearTotals[year] ?? 0),
  ];
}

String _viewLabel(AppStrings strings, _TrendViewMode view) {
  return switch (view) {
    _TrendViewMode.daily => strings.isThai ? 'รายวัน' : 'Daily',
    _TrendViewMode.monthly => strings.isThai ? 'รายเดือน' : 'Monthly',
    _TrendViewMode.yearly => strings.isThai ? 'รายปี' : 'Yearly',
  };
}

String _periodLabel(
  AppStrings strings,
  DateTime month,
  _TrendViewMode selectedView,
) {
  return switch (selectedView) {
    _TrendViewMode.daily => strings.formatMonthYear(month),
    _TrendViewMode.monthly => month.year.toString(),
    _TrendViewMode.yearly => strings.isThai ? 'ทุกปี' : 'All years',
  };
}
