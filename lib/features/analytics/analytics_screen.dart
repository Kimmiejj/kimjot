import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_language.dart';
import '../../shared/formatters/money_formatter.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../ai/ai_models.dart';
import '../ai/ai_settings_store.dart';
import '../ai/ai_consent_gate.dart';
import '../auth/auth_user.dart';
import '../scan/external_ai_client.dart';
import '../settings/money_settings_store.dart';
import '../transactions/category_localization.dart';
import '../transactions/transaction_record.dart';
import '../transactions/transaction_repository.dart';

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
  _AnalyticsRange _range = _AnalyticsRange.sixMonths;
  bool _loadingInsight = false;
  FinancialAiInsight? _insight;
  late Stream<List<TransactionRecord>> _transactionsStream;

  @override
  void initState() {
    super.initState();
    _transactionsStream = widget.transactionRepository.watchTransactions(
      widget.user.uid,
    );
    AiSettingsStore.instance.load();
    MoneySettingsStore.instance.load(widget.user.uid);
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid ||
        oldWidget.transactionRepository != widget.transactionRepository) {
      _transactionsStream = widget.transactionRepository.watchTransactions(
        widget.user.uid,
      );
    }
  }

  Future<void> _analyze(_AnalyticsData data) async {
    if (_loadingInsight) return;
    if (!await ensureAiAllowed(context)) return;
    HapticFeedback.mediumImpact();
    setState(() => _loadingInsight = true);
    final insight = await ExternalAiClient.instance.analyzeFinances(
      summary: data.aiSummary,
      mode: AiSettingsStore.instance.mode,
    );
    if (!mounted) return;
    setState(() {
      _loadingInsight = false;
      _insight = insight;
    });
    if (insight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.isThai
                ? 'AI ยังไม่พร้อม กรุณาตรวจ backend หรืออินเทอร์เน็ต'
                : 'AI is unavailable. Check the backend or connection.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final thai = context.strings.isThai;
    final gutter = KimjodLayout.gutter(context, regular: 22);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5EF), Color(0xFFEDF8F3), Color(0xFFFFF5EF)],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<TransactionRecord>>(
            stream: _transactionsStream,
            builder: (context, snapshot) {
              final settings = MoneySettingsStore.instance.snapshotFor(
                widget.user.uid,
              );
              final data = _AnalyticsData.from(
                records: snapshot.data ?? const [],
                range: _range,
                monthlyBudget: settings.monthlyBudget,
                installments: settings.installments,
                context: context,
              );
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 0),
                    sliver: SliverToBoxAdapter(
                      child: _Header(thai: thai, onBack: widget.onBack),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 0),
                    sliver: SliverToBoxAdapter(
                      child: _RangeSelector(
                        selected: _range,
                        thai: thai,
                        onChanged: (range) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _range = range;
                            _insight = null;
                          });
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 0),
                    sliver: SliverToBoxAdapter(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _OverviewHero(
                          key: ValueKey(_range),
                          data: data,
                          thai: thai,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                    sliver: SliverToBoxAdapter(
                      child: _TrendCard(data: data, thai: thai),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                    sliver: SliverToBoxAdapter(
                      child: _CategoryCard(data: data, thai: thai),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                    sliver: SliverToBoxAdapter(
                      child: _LocalAdviceCard(data: data, thai: thai),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 120),
                    sliver: SliverToBoxAdapter(
                      child: AnimatedBuilder(
                        animation: AiSettingsStore.instance,
                        builder: (context, _) => _AiInsightCard(
                          data: data,
                          thai: thai,
                          backendReady: ExternalAiClient.instance.isConfigured,
                          loading: _loadingInsight,
                          insight: _insight,
                          selectedMode: AiSettingsStore.instance.mode,
                          onModeChanged: AiSettingsStore.instance.setMode,
                          onAnalyze: () => _analyze(data),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _AnalyticsRange {
  sixMonths(6),
  twelveMonths(12),
  threeYears(36);

  const _AnalyticsRange(this.months);
  final int months;

  String label(bool thai) => switch (this) {
    sixMonths => thai ? '6 เดือน' : '6 months',
    twelveMonths => thai ? '12 เดือน' : '12 months',
    threeYears => thai ? '3 ปี' : '3 years',
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.thai, this.onBack});

  final bool thai;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          IconButton.filledTonal(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thai ? 'ภาพรวมการเงิน' : 'Money intelligence',
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                thai
                    ? 'เห็นนิสัยการใช้เงิน\nก่อนเงินหายไป'
                    : 'See where your money\nis really going',
                style: const TextStyle(
                  color: Color(0xFF172826),
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF172826),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.insights_rounded, color: Color(0xFFCFF7E9)),
        ),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.thai,
    required this.onChanged,
  });

  final _AnalyticsRange selected;
  final bool thai;
  final ValueChanged<_AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E9E3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final range in _AnalyticsRange.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == range
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: selected == range
                        ? const [
                            BoxShadow(
                              color: Color(0x16172826),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    range.label(thai),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected == range
                          ? const Color(0xFF172826)
                          : const Color(0xFF74817D),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewHero extends StatelessWidget {
  const _OverviewHero({required this.data, required this.thai, super.key});

  final _AnalyticsData data;
  final bool thai;

  @override
  Widget build(BuildContext context) {
    final positive = data.balance >= 0;
    final compact = KimjodLayout.isCompact(context);
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF172826),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38172826),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                thai ? 'เงินคงเหลือในช่วงนี้' : 'Net balance',
                style: const TextStyle(
                  color: Color(0xFFB7C4C0),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: positive
                      ? const Color(0xFF24453E)
                      : const Color(0xFF4B302E),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  positive
                      ? (thai ? 'ยังเป็นบวก' : 'Positive')
                      : (thai ? 'ต้องระวัง' : 'Watch out'),
                  style: TextStyle(
                    color: positive
                        ? const Color(0xFFCFF7E9)
                        : const Color(0xFFFFC9BE),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(_round(data.balance)),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: thai ? 'รายรับ' : 'Income',
                  value: _round(data.incomeTotal),
                  color: const Color(0xFFCFF7E9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMetric(
                  label: thai ? 'รายจ่าย' : 'Expense',
                  value: _round(data.expenseTotal),
                  color: const Color(0xFFFFC9BE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9EB0AA), fontSize: 12),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(value),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data, required this.thai});
  final _AnalyticsData data;
  final bool thai;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            icon: Icons.show_chart_rounded,
            title: thai ? 'จังหวะการใช้เงิน' : 'Spending rhythm',
            subtitle: data.range == _AnalyticsRange.threeYears
                ? (thai
                      ? 'แตะไตรมาสเพื่อดูรายเดือน'
                      : 'Tap a quarter for monthly detail')
                : (thai ? 'รายจ่ายแยกตามเดือน' : 'Monthly expenses'),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 210,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in data.trendPoints)
                  Expanded(
                    child: GestureDetector(
                      onTap: point.months.length > 1
                          ? () => _showQuarter(context, point, thai)
                          : null,
                      child: _AnimatedBar(point: point, max: data.maxTrend),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuarter(BuildContext context, _TrendPoint point, bool thai) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFDF8),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${point.label} · ${thai ? 'รายละเอียดรายเดือน' : 'Monthly detail'}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            for (final month in point.months)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        month.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      _money(month.amount),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.point, required this.max});
  final _TrendPoint point;
  final double max;

  @override
  Widget build(BuildContext context) {
    final target = max <= 0 ? 0.04 : (point.amount / max).clamp(0.04, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: target),
              duration: const Duration(milliseconds: 720),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF35BFA6), Color(0xFF0F766E)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            point.label,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF74817D),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.data, required this.thai});
  final _AnalyticsData data;
  final bool thai;

  @override
  Widget build(BuildContext context) {
    final entries = data.sortedCategories.take(5).toList();
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            icon: Icons.donut_large_rounded,
            title: thai ? 'เงินออกไปที่ไหน' : 'Where it went',
            subtitle: thai ? '5 หมวดสูงสุด' : 'Top five categories',
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Text(
              thai ? 'ยังไม่มีรายจ่ายในช่วงนี้' : 'No expenses in this period',
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              _CategoryRow(
                entry: entries[i],
                total: data.expenseTotal,
                color: _categoryColors[i % _categoryColors.length],
              ),
              if (i != entries.length - 1) const SizedBox(height: 13),
            ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.entry,
    required this.total,
    required this.color,
  });
  final MapEntry<String, double> entry;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0
        ? 0.0
        : (entry.value / total).clamp(0, 1).toDouble();
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: ratio,
            backgroundColor: const Color(0xFFE8ECE9),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LocalAdviceCard extends StatelessWidget {
  const _LocalAdviceCard({required this.data, required this.thai});
  final _AnalyticsData data;
  final bool thai;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      color: const Color(0xFFFFEEE7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            icon: Icons.lightbulb_rounded,
            title: thai ? 'อ่านเกมเงินแบบออฟไลน์' : 'Offline money check',
            subtitle: thai
                ? 'คำนวณจากข้อมูลจริงในเครื่อง'
                : 'Calculated locally',
          ),
          const SizedBox(height: 16),
          for (final advice in data.localAdvice(thai))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      size: 15,
                      color: Color(0xFFB55242),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      advice,
                      style: const TextStyle(
                        color: Color(0xFF4B302E),
                        height: 1.4,
                        fontWeight: FontWeight.w700,
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

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({
    required this.data,
    required this.thai,
    required this.backendReady,
    required this.loading,
    required this.insight,
    required this.selectedMode,
    required this.onModeChanged,
    required this.onAnalyze,
  });

  final _AnalyticsData data;
  final bool thai;
  final bool backendReady;
  final bool loading;
  final FinancialAiInsight? insight;
  final AiMode selectedMode;
  final ValueChanged<AiMode> onModeChanged;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final ready = backendReady;
    return _PremiumCard(
      color: const Color(0xFFE9E7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            icon: Icons.auto_awesome_rounded,
            title: thai ? 'วิเคราะห์ด้วย Gemini' : 'Analyze with Gemini',
            subtitle: thai
                ? 'เรียกเมื่อคุณต้องการเท่านั้น'
                : 'Runs only when you ask',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final mode in AiMode.values)
                ChoiceChip(
                  selected: selectedMode == mode,
                  onSelected: (_) => onModeChanged(mode),
                  label: Text(mode.label(isThai: thai)),
                  selectedColor: const Color(0xFF6D5CE7),
                  labelStyle: TextStyle(
                    color: selectedMode == mode
                        ? Colors.white
                        : const Color(0xFF47416D),
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!ready) ...[
            Text(
              thai
                  ? 'ยังไม่ได้เชื่อม AI backend — ตั้งค่าได้ในเมนู AI'
                  : 'AI backend is not connected. Configure it in AI settings.',
              style: const TextStyle(
                color: Color(0xFF47416D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: loading || data.transactionCount == 0
                  ? null
                  : onAnalyze,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_graph_rounded),
              label: Text(
                loading
                    ? (thai ? 'กำลังคิด…' : 'Thinking…')
                    : (thai ? 'วิเคราะห์ช่วงนี้' : 'Analyze this period'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6D5CE7),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ],
          if (insight != null) ...[
            const SizedBox(height: 20),
            Text(
              insight!.headline,
              style: const TextStyle(
                color: Color(0xFF2E2854),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _InsightSection(
              title: thai ? 'ข้อดี' : 'Strengths',
              items: insight!.strengths,
              color: const Color(0xFF0F766E),
            ),
            _InsightSection(
              title: thai ? 'จุดเสี่ยง' : 'Risks',
              items: insight!.risks,
              color: const Color(0xFFB55242),
            ),
            _InsightSection(
              title: thai ? 'แนะนำให้ทำ' : 'Recommendations',
              items: insight!.recommendations,
              color: const Color(0xFF5A4CC1),
            ),
            if (insight!.suggestedMonthlyCut > 0)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.content_cut_rounded,
                      color: Color(0xFFB55242),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${thai ? 'เป้าหมายลดรายจ่าย' : 'Suggested monthly cut'} ${_money(insight!.suggestedMonthlyCut)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              thai
                  ? 'ข้อมูลนี้เป็นคำแนะนำด้านงบประมาณ ไม่ใช่คำแนะนำการลงทุน'
                  : 'Budget guidance only; not investment advice.',
              style: const TextStyle(color: Color(0xFF6F6894), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({
    required this.title,
    required this.items,
    required this.color,
  });
  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: Color(0xFF47416D),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x16172826)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17172826),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF172826),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFFCFF7E9), size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF172826),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF74817D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsData {
  const _AnalyticsData({
    required this.range,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.balance,
    required this.transactionCount,
    required this.trendPoints,
    required this.categoryTotals,
    required this.monthlyBudget,
    required this.installmentTotal,
    required this.recentMonthlyExpense,
    required this.previousMonthlyExpense,
  });

  final _AnalyticsRange range;
  final double incomeTotal;
  final double expenseTotal;
  final double balance;
  final int transactionCount;
  final List<_TrendPoint> trendPoints;
  final Map<String, double> categoryTotals;
  final double? monthlyBudget;
  final double installmentTotal;
  final double recentMonthlyExpense;
  final double previousMonthlyExpense;

  double get maxTrend =>
      trendPoints.fold(0, (max, point) => math.max(max, point.amount));

  List<MapEntry<String, double>> get sortedCategories {
    final entries = categoryTotals.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  Map<String, Object?> get aiSummary => <String, Object?>{
    'periodMonths': range.months,
    'incomeTotal': _round(incomeTotal),
    'expenseTotal': _round(expenseTotal),
    'balance': _round(balance),
    'transactionCount': transactionCount,
    'monthlyBudget': monthlyBudget,
    'installmentTotalPerMonth': _round(installmentTotal),
    'categoryTotals': categoryTotals.map(
      (key, value) => MapEntry(key, _round(value)),
    ),
    'trend': trendPoints
        .map(
          (point) => <String, Object?>{
            'period': point.label,
            'expense': _round(point.amount),
          },
        )
        .toList(),
  };

  List<String> localAdvice(bool thai) {
    if (transactionCount == 0) {
      return [
        thai
            ? 'เพิ่มรายการก่อน ระบบจึงจะวิเคราะห์พฤติกรรมได้'
            : 'Add transactions to unlock analysis.',
      ];
    }
    final advice = <String>[];
    if (balance >= 0) {
      advice.add(
        thai
            ? 'รายรับยังครอบคลุมรายจ่ายในช่วงที่เลือก'
            : 'Income covers expenses in this period.',
      );
    } else {
      advice.add(
        thai
            ? 'รายจ่ายสูงกว่ารายรับ ${_money(balance.abs())}'
            : 'Expenses exceed income by ${_money(balance.abs())}.',
      );
    }
    final top = sortedCategories.isEmpty ? null : sortedCategories.first;
    if (top != null) {
      advice.add(
        thai
            ? '${top.key} เป็นหมวดที่ใช้มากที่สุด ${_money(top.value)}'
            : '${top.key} is the largest category at ${_money(top.value)}.',
      );
    }
    if (monthlyBudget != null && recentMonthlyExpense > monthlyBudget!) {
      advice.add(
        thai
            ? 'เดือนล่าสุดเกินงบ ${_money(recentMonthlyExpense - monthlyBudget!)}'
            : 'The latest month is ${_money(recentMonthlyExpense - monthlyBudget!)} over budget.',
      );
    }
    if (previousMonthlyExpense > 0 &&
        recentMonthlyExpense > previousMonthlyExpense * 1.15) {
      final percent =
          ((recentMonthlyExpense / previousMonthlyExpense - 1) * 100).round();
      advice.add(
        thai
            ? 'รายจ่ายเดือนล่าสุดเพิ่มขึ้นประมาณ $percent% จากเดือนก่อน'
            : 'Latest monthly spending rose about $percent%.',
      );
    }
    if (installmentTotal > 0) {
      advice.add(
        thai
            ? 'กันเงินค่างวดอย่างน้อย ${_money(installmentTotal)} ก่อนใช้งบส่วนอื่น'
            : 'Reserve at least ${_money(installmentTotal)} for installments first.',
      );
    }
    return advice.take(4).toList(growable: false);
  }

  factory _AnalyticsData.from({
    required List<TransactionRecord> records,
    required _AnalyticsRange range,
    required double? monthlyBudget,
    required List<InstallmentPlan> installments,
    required BuildContext context,
  }) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final start = DateTime(now.year, now.month - range.months + 1);
    final filtered = records
        .where((record) => !record.transactionDate.isBefore(start))
        .toList();
    var income = 0.0;
    var expense = 0.0;
    final byMonth = <DateTime, double>{};
    final categories = <String, double>{};
    for (final record in filtered) {
      if (record.type.isInternalTransfer) continue;
      if (record.type.isIncome) {
        income += record.amount;
        continue;
      }
      expense += record.amount;
      final month = DateTime(
        record.transactionDate.year,
        record.transactionDate.month,
      );
      byMonth.update(
        month,
        (value) => value + record.amount,
        ifAbsent: () => record.amount,
      );
      final category = localizedCategoryName(
        strings: context.strings,
        categoryId: record.categoryId,
        fallbackName: record.categoryName,
      );
      categories.update(
        category,
        (value) => value + record.amount,
        ifAbsent: () => record.amount,
      );
    }

    final monthlyPoints = <_MonthPoint>[];
    for (var offset = range.months - 1; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset);
      monthlyPoints.add(
        _MonthPoint(
          date: month,
          label: _monthLabel(month, context.strings.isThai),
          amount: byMonth[month] ?? 0,
        ),
      );
    }

    final trend = <_TrendPoint>[];
    if (range == _AnalyticsRange.threeYears) {
      for (var i = 0; i < monthlyPoints.length; i += 3) {
        final months = monthlyPoints.skip(i).take(3).toList(growable: false);
        final first = months.first.date;
        final quarter = ((first.month - 1) ~/ 3) + 1;
        trend.add(
          _TrendPoint(
            label:
                'Q$quarter\n${(first.year + (context.strings.isThai ? 543 : 0)).toString().substring(2)}',
            amount: months.fold(0, (sum, point) => sum + point.amount),
            months: months,
          ),
        );
      }
    } else {
      trend.addAll(
        monthlyPoints.map(
          (point) => _TrendPoint(
            label: point.label,
            amount: point.amount,
            months: [point],
          ),
        ),
      );
    }

    final recent = byMonth[currentMonth] ?? 0;
    final previousMonth = DateTime(now.year, now.month - 1);
    final previous = byMonth[previousMonth] ?? 0;
    final installmentTotal = installments
        .where((plan) => plan.isDueInMonth(currentMonth))
        .fold<double>(0, (sum, plan) => sum + plan.amount);
    return _AnalyticsData(
      range: range,
      incomeTotal: income,
      expenseTotal: expense,
      balance: income - expense,
      transactionCount: filtered.length,
      trendPoints: trend,
      categoryTotals: categories,
      monthlyBudget: monthlyBudget,
      installmentTotal: installmentTotal,
      recentMonthlyExpense: recent,
      previousMonthlyExpense: previous,
    );
  }
}

class _TrendPoint {
  const _TrendPoint({
    required this.label,
    required this.amount,
    required this.months,
  });
  final String label;
  final double amount;
  final List<_MonthPoint> months;
}

class _MonthPoint {
  const _MonthPoint({
    required this.date,
    required this.label,
    required this.amount,
  });
  final DateTime date;
  final String label;
  final double amount;
}

const _categoryColors = <Color>[
  Color(0xFF0F766E),
  Color(0xFFFF7A66),
  Color(0xFF6D5CE7),
  Color(0xFFE7A93E),
  Color(0xFF3578B8),
];

String _monthLabel(DateTime date, bool thai) {
  const en = [
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
  const th = [
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
  return (thai ? th : en)[date.month - 1];
}

double _round(double value) => double.parse(value.toStringAsFixed(2));

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  return '$sign฿${formatOriginalNumber(value)}';
}
