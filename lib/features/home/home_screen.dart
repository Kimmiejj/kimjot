import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/formatters/money_formatter.dart';
import '../../shared/widgets/month_year_picker_dialog.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../ai/ai_chat_screen.dart';
import '../ai/ai_consent_gate.dart';
import '../auth/auth_user.dart';
import '../scan/album_sync_background_service.dart';
import '../scan/album_sync_job_actions.dart';
import '../settings/money_settings_store.dart';
import '../settings/support_screens.dart';
import '../transactions/category_icons.dart';
import '../transactions/category_localization.dart';
import '../transactions/home_summary.dart';
import '../transactions/manual_add_screen.dart';
import '../transactions/manual_transaction_sheet.dart';
import '../transactions/transaction_list_screen.dart';
import '../transactions/transaction_record.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_type.dart';
import '../voice/voice_transaction_screen.dart';

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
  StreamSubscription<AlbumSyncJobSnapshot?>? _albumSyncSubscription;
  AlbumSyncJobSnapshot? _albumSyncJob;
  bool _isSavingAlbum = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _currentMonth();
    MoneySettingsStore.instance.load();
    _albumSyncSubscription = AlbumSyncBackgroundService.watchJob.listen(
      _applyAlbumSyncJob,
    );
    unawaited(_loadAlbumSyncJob());
  }

  @override
  void dispose() {
    _albumSyncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAlbumSyncJob() async {
    final job = await AlbumSyncBackgroundService.loadJob();
    if (!mounted) return;
    _applyAlbumSyncJob(job);
  }

  void _applyAlbumSyncJob(AlbumSyncJobSnapshot? job) {
    if (!mounted) return;
    setState(() {
      _albumSyncJob = job?.userId == widget.user.uid ? job : null;
    });
  }

  Future<void> _saveAlbumSyncJob() async {
    final job = _albumSyncJob;
    if (job == null || job.isScanning || _isSavingAlbum) return;
    setState(() => _isSavingAlbum = true);

    final savedCount = await saveAlbumSyncItems(
      user: widget.user,
      transactionRepository: widget.transactionRepository,
      strings: context.strings,
      items: job.items,
    );
    if (!mounted) return;
    setState(() => _isSavingAlbum = false);

    if (savedCount > 0) {
      await AlbumSyncBackgroundService.clearFinishedJob();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.isThai
                ? '\u0E1A\u0E31\u0E19\u0E17\u0E36\u0E01 $savedCount \u0E23\u0E32\u0E22\u0E01\u0E32\u0E23\u0E41\u0E25\u0E49\u0E27'
                : 'Saved $savedCount transactions',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.couldNotSaveTransaction)),
    );
  }

  Future<void> _discardAlbumSyncJob() async {
    final job = _albumSyncJob;
    if (job == null || job.isScanning || _isSavingAlbum) return;
    await AlbumSyncBackgroundService.clearFinishedJob();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.strings.isThai
              ? '\u0E22\u0E01\u0E40\u0E25\u0E34\u0E01\u0E1C\u0E25 Sync Album \u0E41\u0E25\u0E49\u0E27'
              : 'Album sync result discarded',
        ),
      ),
    );
  }

  Future<void> _cancelAlbumSyncJob() async {
    final job = _albumSyncJob;
    if (job == null || !job.isScanning || _isSavingAlbum) return;
    await AlbumSyncBackgroundService.requestCancel();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.albumSyncCancelled)));
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

  Future<void> _openMoneySettings(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => page));
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAiChat() async {
    if (!await ensureAiAllowed(context) || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AiChatScreen(
          user: widget.user,
          transactionRepository: widget.transactionRepository,
        ),
      ),
    );
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
    final selected = await showMonthYearPickerDialog(
      context: context,
      initialMonth: _selectedMonth,
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
    final gutter = KimjodLayout.gutter(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5EF), Color(0xFFEAF8F2), Color(0xFFFFF4ED)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 0),
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
                padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 0),
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
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
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
                    onVoice: () => _openPage(
                      context,
                      VoiceTransactionScreen(
                        user: widget.user,
                        transactionRepository: widget.transactionRepository,
                      ),
                    ),
                  ),
                ),
              ),
              if (_albumSyncJob != null)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                  sliver: SliverToBoxAdapter(
                    child: _AlbumSyncHomeCard(
                      job: _albumSyncJob!,
                      isSaving: _isSavingAlbum,
                      onSave: _saveAlbumSyncJob,
                      onDiscard: _discardAlbumSyncJob,
                      onCancel: _cancelAlbumSyncJob,
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: _AiChatCard(onTap: _openAiChat),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: _BudgetStatusBuilder(
                    userId: widget.user.uid,
                    month: _selectedMonth,
                    transactionRepository: widget.transactionRepository,
                    onManageBudget: () =>
                        _openMoneySettings(const BudgetsScreen()),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(title: strings.installments),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: _InstallmentStatusBuilder(
                    month: _selectedMonth,
                    onManageInstallments: () => _openMoneySettings(
                      InstallmentsScreen(
                        user: widget.user,
                        transactionRepository: widget.transactionRepository,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(title: strings.recentTransactions),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 112),
                sliver: SliverToBoxAdapter(
                  child: _RecentTransactionsBuilder(
                    user: widget.user,
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

class _AlbumSyncHomeCard extends StatelessWidget {
  const _AlbumSyncHomeCard({
    required this.job,
    required this.isSaving,
    required this.onSave,
    required this.onDiscard,
    required this.onCancel,
  });

  final AlbumSyncJobSnapshot job;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final percent = (job.progress * 100).round();
    final isScanning = job.isScanning;
    final title = strings.isThai
        ? '\u0E01\u0E33\u0E25\u0E31\u0E07 Sync Album'
        : 'Album sync';
    final status = isScanning
        ? (strings.isThai
              ? '\u0E2D\u0E48\u0E32\u0E19\u0E2A\u0E25\u0E34\u0E1B ${job.completedCount}/${job.totalCount}'
              : 'Reading ${job.completedCount}/${job.totalCount} slips')
        : job.state == AlbumSyncJobState.cancelled
        ? strings.albumSyncCancelled
        : (strings.isThai
              ? '\u0E2A\u0E41\u0E01\u0E19\u0E40\u0E2A\u0E23\u0E47\u0E08\u0E41\u0E25\u0E49\u0E27 \u0E1E\u0E23\u0E49\u0E2D\u0E21\u0E1A\u0E31\u0E19\u0E17\u0E36\u0E01 ${job.readyCount} \u0E23\u0E32\u0E22\u0E01\u0E32\u0E23'
              : 'Scan complete · ${job.readyCount} ready to save');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7FFF4), Color(0xFFEAFBFF)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x335D81AD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142A6F65),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF172826),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.collections_rounded,
                  color: Color(0xFFCFF7E9),
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
                        color: Color(0xFF172826),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: const TextStyle(
                        color: Color(0xFF60716C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: job.progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF28B78D)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.isThai
                ? '\u0E1E\u0E23\u0E49\u0E2D\u0E21 ${job.readyCount}  ·  \u0E0B\u0E49\u0E33 ${job.duplicateCount}  ·  \u0E2D\u0E48\u0E32\u0E19\u0E44\u0E21\u0E48\u0E44\u0E14\u0E49 ${job.failedCount}'
                : 'Ready ${job.readyCount}  ·  Duplicate ${job.duplicateCount}  ·  Failed ${job.failedCount}',
            style: const TextStyle(
              color: Color(0xFF60716C),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (isScanning) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD94768),
                side: const BorderSide(color: Color(0xFFD94768)),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(strings.cancelAlbumSync),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isSaving || job.readyCount == 0 ? null : onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF168765),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: isSaving
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      strings.isThai
                          ? '\u0E1A\u0E31\u0E19\u0E17\u0E36\u0E01\u0E17\u0E31\u0E49\u0E07\u0E2B\u0E21\u0E14'
                          : 'Save all',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onDiscard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD94768),
                    side: const BorderSide(color: Color(0xFFD94768)),
                    minimumSize: const Size(112, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: Text(
                    strings.isThai
                        ? '\u0E22\u0E01\u0E40\u0E25\u0E34\u0E01'
                        : 'Cancel',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetStatusBuilder extends StatelessWidget {
  const _BudgetStatusBuilder({
    required this.userId,
    required this.month,
    required this.transactionRepository,
    required this.onManageBudget,
  });

  final String userId;
  final DateTime month;
  final TransactionRepository transactionRepository;
  final VoidCallback onManageBudget;

  @override
  Widget build(BuildContext context) {
    return _MoneySettingsBuilder(
      builder: (settings) {
        final budget = settings.monthlyBudget;
        if (budget == null || budget <= 0) {
          return _EmptyInfoCard(
            title: context.strings.budget,
            message: context.strings.noBudget,
            icon: Icons.account_balance_wallet_rounded,
            actionLabel: 'Set',
            actionIcon: Icons.tune_rounded,
            onAction: onManageBudget,
          );
        }

        return _SummaryBuilder(
          userId: userId,
          month: month,
          transactionRepository: transactionRepository,
          builder: (summary) => _BudgetProgressCard(
            budget: budget,
            spent: summary.expenseTotal,
            month: month,
            onEdit: onManageBudget,
          ),
        );
      },
    );
  }
}

class _InstallmentStatusBuilder extends StatelessWidget {
  const _InstallmentStatusBuilder({
    required this.month,
    required this.onManageInstallments,
  });

  final DateTime month;
  final VoidCallback onManageInstallments;

  @override
  Widget build(BuildContext context) {
    return _MoneySettingsBuilder(
      builder: (settings) {
        final duePlans = settings.dueInstallmentsFor(month);
        if (duePlans.isEmpty) {
          return _EmptyInfoCard(
            title: context.strings.noDueInstallment,
            message: context.strings.installmentHint,
            icon: Icons.event_available_rounded,
            actionLabel: 'Add',
            actionIcon: Icons.add_rounded,
            onAction: onManageInstallments,
          );
        }
        return _InstallmentDueCard(
          plans: duePlans,
          month: month,
          onManage: onManageInstallments,
        );
      },
    );
  }
}

class _MoneySettingsBuilder extends StatefulWidget {
  const _MoneySettingsBuilder({required this.builder});

  final Widget Function(MoneySettingsSnapshot settings) builder;

  @override
  State<_MoneySettingsBuilder> createState() => _MoneySettingsBuilderState();
}

class _MoneySettingsBuilderState extends State<_MoneySettingsBuilder> {
  final _store = MoneySettingsStore.instance;
  late Future<MoneySettingsSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return FutureBuilder<MoneySettingsSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            return widget.builder(snapshot.data ?? _store.snapshot);
          },
        );
      },
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
            child: KimjodMascot(
              size: KimjodLayout.isCompact(context) ? 54 : 64,
            ),
          ),
        ),
      ],
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
    final compact = KimjodLayout.isCompact(context);

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
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
  const _QuickActions({
    required this.onAdd,
    required this.onScan,
    required this.onVoice,
  });

  final VoidCallback onAdd;
  final VoidCallback onScan;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final gap = KimjodLayout.isCompact(context) ? 8.0 : 12.0;

    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.add_rounded,
            label: strings.add,
            onTap: onAdd,
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            foregroundColor: const Color(0xFF111827),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _ActionTile(
            icon: Icons.document_scanner_rounded,
            label: strings.scanSlip,
            onTap: onScan,
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            foregroundColor: const Color(0xFF111827),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _ActionTile(
            icon: Icons.mic_rounded,
            label: strings.isThai ? 'เสียง' : 'Voice',
            onTap: onVoice,
            backgroundColor: const Color(0xFF172826),
            foregroundColor: const Color(0xFFCFF7E9),
          ),
        ),
      ],
    );
  }
}

class _AiChatCard extends StatelessWidget {
  const _AiChatCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thai = context.strings.isThai;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF172826), Color(0xFF244A43)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30172826),
                blurRadius: 22,
                offset: Offset(0, 11),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFCFF7E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF172826),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thai ? 'คุยกับ Kimjod Gemini' : 'Chat with Kimjod Gemini',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      thai
                          ? 'ถาม Gemini เรื่องงบและยอดรวมเดือนนี้ได้เลย'
                          : 'Ask Gemini about budgets and this month’s totals.',
                      style: const TextStyle(
                        color: Color(0xFFCFE0DA),
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFFCFF7E9)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 23),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                  letterSpacing: 0,
                ),
              ),
            ],
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
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

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
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: 12),
            _MiniActionButton(
              icon: actionIcon ?? Icons.chevron_right_rounded,
              label: actionLabel!,
              onPressed: onAction!,
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  const _BudgetProgressCard({
    required this.budget,
    required this.spent,
    required this.month,
    required this.onEdit,
  });

  final double budget;
  final double spent;
  final DateTime month;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final remaining = budget - spent;
    final progress = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final isOver = spent > budget;
    final now = DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrentMonth = _isSameMonth(month, now);
    final isFutureMonth = month.isAfter(DateTime(now.year, now.month));
    final remainingDays = isFutureMonth
        ? daysInMonth
        : isCurrentMonth
        ? daysInMonth - now.day + 1
        : 0;
    final dailyAllowance = remainingDays > 0 && remaining > 0
        ? remaining / remainingDays
        : 0.0;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: isOver
                      ? const Color(0xFFB66A72)
                      : const Color(0xFF0C8C8C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.budget,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOver
                          ? 'Over by ${_formatMoney(remaining.abs())}'
                          : '${_formatMoney(remaining)} left',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: isOver
                      ? const Color(0xFFB66A72)
                      : const Color(0xFF0C8C8C),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Edit budget',
                onPressed: onEdit,
                icon: const Icon(Icons.tune_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F8F8),
                  foregroundColor: const Color(0xFF0C8C8C),
                  fixedSize: const Size.square(42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFE7EDF4),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? const Color(0xFFB66A72) : const Color(0xFF0C8C8C),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_formatMoney(spent)} spent of ${_formatMoney(budget)}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          if (remainingDays > 0) ...[
            const SizedBox(height: 6),
            Text(
              strings.isThai
                  ? 'ใช้ได้เฉลี่ย ${_formatMoney(dailyAllowance)} ต่อวัน · เหลือ $remainingDays วัน'
                  : '${_formatMoney(dailyAllowance)} available per day · $remainingDays days left',
              style: const TextStyle(
                color: Color(0xFF0C6F6F),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InstallmentDueCard extends StatelessWidget {
  const _InstallmentDueCard({
    required this.plans,
    required this.month,
    required this.onManage,
  });

  final List<InstallmentPlan> plans;
  final DateTime month;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final total = plans.fold<double>(0, (sum, plan) => sum + plan.amount);
    final first = plans.first;
    final moreCount = plans.length - 1;

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
            child: const Icon(
              Icons.event_available_rounded,
              color: Color(0xFF475569),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  moreCount > 0
                      ? '${_formatMoney(total)} due across ${plans.length} plans'
                      : '${_formatMoney(first.amount)} due this month',
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
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Manage installments',
            onPressed: onManage,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE7EDF4),
              foregroundColor: const Color(0xFF475569),
              fixedSize: const Size.square(42),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: const Color(0xFF10233F),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
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
    required this.user,
    required this.userId,
    required this.month,
    required this.transactionRepository,
    required this.onSeeMore,
  });

  final AuthUser user;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < transactions.length; index++) ...[
              if (index == 0 ||
                  !DateUtils.isSameDay(
                    transactions[index - 1].transactionDate,
                    transactions[index].transactionDate,
                  ))
                _RecentDayHeader(date: transactions[index].transactionDate),
              _TransactionListTile(
                record: transactions[index],
                onTap: () => showModalBottomSheet<Object?>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFFF8FFFF),
                  builder: (context) => ManualTransactionSheet(
                    user: user,
                    transactionRepository: transactionRepository,
                    source: transactions[index].source,
                    title: context.strings.isThai
                        ? 'ดูและแก้ไขรายการ'
                        : 'View and edit transaction',
                    initialType: transactions[index].type,
                    initialAmount: transactions[index].amount,
                    initialNote: transactions[index].note,
                    initialDate: transactions[index].transactionDate,
                    existingRecord: transactions[index],
                  ),
                ),
              ),
              if (index != transactions.length - 1) const SizedBox(height: 8),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      context.strings.isThai
                          ? 'ดูรายการทั้งหมดของเดือนนี้'
                          : 'View all transactions this month',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentDayHeader extends StatelessWidget {
  const _RecentDayHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF0C8C8C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            context.strings.formatDate(date),
            style: const TextStyle(
              color: Color(0xFF496582),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0x245D81AD), height: 1)),
        ],
      ),
    );
  }
}

class _TransactionListTile extends StatelessWidget {
  const _TransactionListTile({required this.record, required this.onTap});

  final TransactionRecord record;
  final VoidCallback onTap;

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
      categoryColor: categoryAccentColor(record.categoryId),
      title: title,
      time: context.strings.formatTime(record.transactionDate),
      subtitle: '$categoryName · ${record.source.firestoreValue}',
      amount:
          '${_transactionPrefix(record.type)}${_formatMoney(record.amount)}',
      amountColor: _transactionColor(record.type),
      onTap: onTap,
    );
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({
    required this.categoryIcon,
    required this.categoryColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.amount,
    required this.amountColor,
    required this.onTap,
  });

  final IconData categoryIcon;
  final Color categoryColor;
  final String title;
  final String subtitle;
  final String time;
  final String amount;
  final Color amountColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(categoryIcon, color: categoryColor, size: 22),
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
                        color: Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      amount,
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.strings.isThai ? 'รายละเอียด' : 'Details',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
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

String _formatMoney(double amount) {
  final sign = amount < 0 ? '-' : '';
  return '${sign}THB ${_formatNumber(amount.abs())}';
}

String _transactionPrefix(TransactionType type) {
  if (type == TransactionType.internalTransfer) {
    return '';
  }
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
  return formatOriginalNumber(amount);
}

bool _isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}
