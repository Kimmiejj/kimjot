import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_language.dart';
import '../../shared/formatters/money_formatter.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/category_icons.dart';
import '../transactions/create_transaction_input.dart';
import '../transactions/custom_category_store.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';
import 'money_settings_store.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _store = MoneySettingsStore.instance;
  final _budgetController = TextEditingController();
  late Future<MoneySettingsSnapshot> _settingsFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _store.load();
    _settingsFuture.then((settings) {
      if (!mounted) return;
      _budgetController.text = settings.monthlyBudget == null
          ? ''
          : _formatAmount(settings.monthlyBudget!);
    });
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });
    await _store.saveMonthlyBudget(_parseAmount(_budgetController.text));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _settingsFuture = _store.load();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Budget saved.')));
  }

  void _setBudget(double amount) {
    setState(() {
      _budgetController.text = _formatAmount(amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return _SupportScaffold(
      status: 'LOCAL SETTINGS',
      smallLabel: strings.budget,
      title: strings.budgetControl,
      child: FutureBuilder<MoneySettingsSnapshot>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          final budget = snapshot.data?.monthlyBudget;
          final budgetStatus = budget == null
              ? strings.noBudgetYet
              : _formatMoney(budget);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MascotTip(message: strings.monthlyAndCategory),
              const SizedBox(height: 14),
              _HeroPanel(
                title: budget == null
                    ? strings.noBudgetYet
                    : '${strings.totalMonthlyBudget}: ${_formatMoney(budget)}',
                message:
                    'Home will compare this budget with the selected month expense total.',
              ),
              const SizedBox(height: 16),
              _SupportStatStrip(
                children: [
                  _SupportStatCard(
                    label: 'Current',
                    value: budgetStatus,
                    tone: _SupportTone.mint,
                  ),
                  _SupportStatCard(
                    label: 'Categories',
                    value: '${_expenseCategoryDefinitions.length} ready',
                    tone: _SupportTone.sky,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionCaption(
                title: 'Monthly budget',
                subtitle:
                    'Set the total limit here. Category budgets stay separate from installment plans.',
              ),
              const SizedBox(height: 10),
              _InputCard(
                label: strings.totalMonthlyBudget,
                child: TextField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [_MoneyInputFormatter()],
                  decoration: InputDecoration(
                    prefixText: strings.amountPrefix,
                    hintText: '0',
                    border: InputBorder.none,
                  ),
                  style: _inputStyle,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amount in const [5000, 10000, 15000, 20000, 30000])
                    _QuickValueChip(
                      label: _formatMoney(amount.toDouble()),
                      onTap: () => _setBudget(amount.toDouble()),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _PrimaryActionButton(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.save_rounded),
                label: _saving ? strings.saving : 'Save budget',
              ),
              const SizedBox(height: 12),
              _SecondaryActionButton(
                onPressed: _saving
                    ? null
                    : () async {
                        _budgetController.clear();
                        await _save();
                      },
                icon: const Icon(Icons.clear_rounded),
                label: 'Clear budget',
              ),
              const SizedBox(height: 16),
              const _SectionCaption(
                title: 'Category budget view',
                subtitle:
                    'Expense categories are ready for budget-level grouping. Installments are managed on their own page.',
              ),
              const SizedBox(height: 10),
              for (final category in _expenseCategoryDefinitions.take(4)) ...[
                _CategoryUsageTile(
                  definition: category,
                  subtitle:
                      'Available for budget grouping and expense tracking',
                  tags: const ['Expense', 'Budget'],
                ),
                const SizedBox(height: 10),
              ],
              _SoftNoteCard(
                icon: Icons.credit_card_rounded,
                title: 'Installments stay separate',
                message:
                    'Marking an installment as paid creates its own tracked expense flow. It does not overwrite the monthly budget value here.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  final _store = MoneySettingsStore.instance;
  late Future<MoneySettingsSnapshot> _settingsFuture;
  String? _payingPlanId;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _store.load();
  }

  void _reload() {
    setState(() {
      _settingsFuture = _store.load();
    });
  }

  Future<void> _openEditor([InstallmentPlan? plan]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InstallmentEditor(plan: plan),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _markPaid(InstallmentPlan plan) async {
    if (_payingPlanId != null) return;
    setState(() => _payingPlanId = plan.id);
    final now = DateTime.now();
    final due = plan.nextDueDateFrom(now) ?? now;
    final transactionDate = DateTime(
      due.year,
      due.month,
      due.day,
      now.hour,
      now.minute,
    );
    try {
      await widget.transactionRepository.createManualTransaction(
        CreateTransactionInput(
          userId: widget.user.uid,
          amount: plan.amount,
          type: TransactionType.expense,
          categoryId: 'bills',
          categoryName: 'Bills',
          transactionDate: transactionDate,
          transactionDateText: context.strings.formatDateTime(transactionDate),
          source: TransactionSource.manual,
          note:
              '${context.strings.isThai ? 'ค่างวด' : 'Installment'}: ${plan.title} '
              '(${plan.paidInstallments + 1}/${plan.totalInstallments})',
        ),
      );
      await _store.markInstallmentPaid(plan.id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.isThai
                ? 'บันทึกค่างวดเป็นรายจ่ายแล้ว'
                : 'Installment payment saved as an expense.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.couldNotSaveTransaction)),
      );
    } finally {
      if (mounted) setState(() => _payingPlanId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return _SupportScaffold(
      status: 'LOCAL SETTINGS',
      smallLabel: strings.installments,
      title: strings.installments,
      action: IconButton(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF3268F6),
          foregroundColor: Colors.white,
        ),
      ),
      child: FutureBuilder<MoneySettingsSnapshot>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          final plans = snapshot.data?.installments ?? const [];
          final totalPlanned = plans.fold<double>(
            0,
            (sum, plan) => sum + plan.amount,
          );
          final totalRemaining = plans.fold<int>(
            0,
            (sum, plan) => sum + plan.remainingInstallments,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MascotTip(message: strings.installmentsHeroMessage),
              const SizedBox(height: 14),
              _HeroPanel(
                title: plans.isEmpty
                    ? strings.noInstallmentsYet
                    : '${plans.length} ${strings.activePlans}',
                message:
                    'Home shows active plans for the selected month. Marking paid updates the next due count.',
              ),
              const SizedBox(height: 16),
              _SupportStatStrip(
                children: [
                  _SupportStatCard(
                    label: 'Active',
                    value: '${plans.length}',
                    tone: _SupportTone.sky,
                  ),
                  _SupportStatCard(
                    label: 'Monthly load',
                    value: plans.isEmpty ? 'THB 0' : _formatMoney(totalPlanned),
                    tone: _SupportTone.rose,
                  ),
                  _SupportStatCard(
                    label: 'Remaining',
                    value: '$totalRemaining',
                    tone: _SupportTone.mint,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionCaption(
                title: 'Installment plans',
                subtitle:
                    'These plans are tracked separately from monthly budget setup.',
              ),
              const SizedBox(height: 10),
              if (plans.isEmpty)
                _SupportRow(
                  icon: Icons.event_available_rounded,
                  title: strings.noDueInstallment,
                  subtitle: strings.installmentHint,
                )
              else
                for (final plan in plans) ...[
                  _InstallmentTile(
                    plan: plan,
                    onEdit: () => _openEditor(plan),
                    onPaid: _payingPlanId == null
                        ? () => _markPaid(plan)
                        : null,
                    onDelete: () async {
                      await _store.deleteInstallment(plan.id);
                      _reload();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({required this.user, super.key});

  final AuthUser user;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _store = CustomCategoryStore.instance;
  late Future<List<CustomCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = _store.load(widget.user.uid);
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    var type = TransactionType.expense;
    final result = await showDialog<(String, TransactionType)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final strings = context.strings;
          return KimjodDialog(
            title: strings.isThai ? 'เพิ่มหมวดหมู่ใหม่' : 'Add category',
            icon: Icons.category_rounded,
            message: strings.isThai
                ? 'ตั้งชื่อและเลือกประเภทรายการ หมวดใหม่นี้จะใช้ได้ทันที'
                : 'Name it and choose a transaction type. It will be ready immediately.',
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KimjodDialogTextField(
                      controller: nameController,
                      hintText: strings.isThai
                          ? 'ชื่อหมวดหมู่'
                          : 'Category name',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x245D81AD)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TransactionType>(
                          value: type,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(18),
                          menuMaxHeight:
                              MediaQuery.sizeOf(context).height * 0.34,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF496582),
                          ),
                          style: const TextStyle(
                            color: Color(0xFF10233F),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                          items: TransactionType.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    _typeLabel(context, value),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => type = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              KimjodDialogAction(
                label: strings.isThai ? 'ยกเลิก' : 'Cancel',
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
              KimjodDialogAction(
                label: strings.isThai ? 'เพิ่ม' : 'Add',
                icon: Icons.add_rounded,
                isPrimary: true,
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(context).pop((name, type));
                  }
                },
              ),
            ],
          );
        },
      ),
    );
    unawaited(
      Future<void>.delayed(kThemeAnimationDuration, nameController.dispose),
    );
    if (result == null) return;
    await _store.add(userId: widget.user.uid, name: result.$1, type: result.$2);
    if (mounted) {
      setState(() {
        _future = _store.load(widget.user.uid);
      });
    }
  }

  Future<void> _deleteCategory(CustomCategory category) async {
    await _store.delete(widget.user.uid, category.id);
    if (mounted) {
      setState(() {
        _future = _store.load(widget.user.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final totalCategories =
        _expenseCategoryDefinitions.length + _incomeCategoryDefinitions.length;

    return _SupportScaffold(
      status: strings.isThai ? 'พร้อมใช้' : 'READY',
      smallLabel: strings.category,
      title: strings.manageCategories,
      child: FutureBuilder<List<CustomCategory>>(
        future: _future,
        builder: (context, snapshot) {
          final customCategories = snapshot.data ?? const [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MascotTip(message: strings.categoriesHeroMessage),
              const SizedBox(height: 14),
              _HeroPanel(
                title: strings.isThai
                    ? '$totalCategories หมวดหมู่พร้อมใช้งาน'
                    : '$totalCategories present categories',
                message: strings.isThai
                    ? 'ใช้กับรายการที่เพิ่มเองและนำเข้าจากสลิปได้ทันที ส่วนงบประมาณและรายการผ่อนจะติดตามแยกกัน'
                    : 'These categories are already used by manual entries and slip imports. Budget and installment usage is separated below.',
              ),
              const SizedBox(height: 16),
              _PrimaryActionButton(
                onPressed: _addCategory,
                icon: const Icon(Icons.add_rounded),
                label: strings.isThai
                    ? 'เพิ่มหมวดหมู่สำหรับทุกประเภทรายการ'
                    : 'Add a category for any transaction type',
              ),
              if (customCategories.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionCaption(
                  title: strings.isThai
                      ? 'หมวดหมู่ที่เพิ่มเอง'
                      : 'Custom categories',
                  subtitle: strings.isThai
                      ? 'ใช้ได้ทันทีในหน้าเพิ่มและแก้ไขรายการ'
                      : 'Available immediately when adding or editing transactions.',
                ),
                const SizedBox(height: 10),
                for (final category in customCategories) ...[
                  Container(
                    decoration: _cardDecoration(),
                    child: ListTile(
                      leading: Icon(categoryIconData(category.id)),
                      title: Text(category.name, style: _rowTitleStyle),
                      subtitle: Text(_typeLabel(context, category.type)),
                      trailing: IconButton(
                        onPressed: () => _deleteCategory(category),
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: strings.isThai
                            ? 'ลบหมวดหมู่'
                            : 'Delete category',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 16),
              _SupportStatStrip(
                children: [
                  _SupportStatCard(
                    label: strings.isThai ? 'รายจ่าย' : 'Expense',
                    value: '${_expenseCategoryDefinitions.length}',
                    tone: _SupportTone.sky,
                  ),
                  _SupportStatCard(
                    label: strings.isThai ? 'ใช้งบประมาณ' : 'Budget ready',
                    value: strings.isThai ? 'เฉพาะรายจ่าย' : 'Expense only',
                    tone: _SupportTone.mint,
                  ),
                  _SupportStatCard(
                    label: strings.isThai
                        ? 'ใช้กับรายการผ่อน'
                        : 'Installment ready',
                    value: strings.isThai
                        ? 'ติดตามแยกกัน'
                        : 'Tracked separately',
                    tone: _SupportTone.rose,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCaption(
                title: strings.isThai
                    ? 'หมวดหมู่รายจ่าย'
                    : 'Expense categories',
                subtitle: strings.isThai
                    ? 'ใช้บันทึกรายจ่าย จัดกลุ่มงบประมาณ และลงค่างวด'
                    : 'These are the present categories used for expense records, budget grouping, and installment payment posts.',
              ),
              const SizedBox(height: 10),
              for (final category in _expenseCategoryDefinitions) ...[
                _CategoryUsageTile(
                  definition: category,
                  subtitle: strings.defaultExpense,
                  tags: strings.isThai
                      ? const ['รายจ่าย', 'งบประมาณ', 'รายการผ่อน']
                      : const ['Expense', 'Budget', 'Installment'],
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              _SectionCaption(
                title: strings.isThai ? 'หมวดหมู่รายรับ' : 'Income categories',
                subtitle: strings.isThai
                    ? 'แยกจากงบประมาณและรายการผ่อน เพื่อให้ดูเงินเข้าได้ง่าย'
                    : 'Kept separate from budget and installments so money-in stays easy to scan.',
              ),
              const SizedBox(height: 10),
              for (final category in _incomeCategoryDefinitions) ...[
                _CategoryUsageTile(
                  definition: category,
                  subtitle: strings.isThai
                      ? 'หมวดหมู่รายรับพร้อมใช้'
                      : 'Present income category',
                  tags: strings.isThai ? const ['รายรับ'] : const ['Income'],
                ),
                const SizedBox(height: 10),
              ],
              _SoftNoteCard(
                icon: Icons.account_tree_rounded,
                title: strings.isThai
                    ? 'งบประมาณกับรายการผ่อน'
                    : 'Budget vs installment',
                message: strings.isThai
                    ? 'หน้างบประมาณใช้กำหนดวงเงิน หน้ารายการผ่อนใช้จัดการแผนชำระ ส่วนหมวดหมู่ใช้ระบุประเภทของรายการ'
                    : 'Budget page controls the limit. Installments page controls payment plans. Categories only label where each record belongs.',
              ),
            ],
          );
        },
      ),
    );
  }
}

String _typeLabel(BuildContext context, TransactionType type) {
  return switch (type) {
    TransactionType.expense => context.strings.expense,
    TransactionType.income => context.strings.income,
    TransactionType.internalTransfer => context.strings.internalTransfer,
  };
}

class _InstallmentEditor extends StatefulWidget {
  const _InstallmentEditor({this.plan});

  final InstallmentPlan? plan;

  @override
  State<_InstallmentEditor> createState() => _InstallmentEditorState();
}

class _InstallmentEditorState extends State<_InstallmentEditor> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _totalController = TextEditingController();
  final _paidController = TextEditingController();
  final _dueDayController = TextEditingController();

  late DateTime _startMonth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _titleController.text = plan?.title ?? '';
    _amountController.text = plan == null ? '' : _formatAmount(plan.amount);
    _totalController.text = '${plan?.totalInstallments ?? 12}';
    _paidController.text = '${plan?.paidInstallments ?? 0}';
    _dueDayController.text = '${plan?.dueDay ?? 1}';
    final now = DateTime.now();
    _startMonth = plan?.startMonth ?? DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _totalController.dispose();
    _paidController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  Future<void> _pickStartMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startMonth,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
      builder: kimjodDatePickerTheme,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startMonth = DateTime(picked.year, picked.month);
    });
  }

  void _setAmount(double amount) {
    setState(() {
      _amountController.text = _formatAmount(amount);
    });
  }

  void _setNumber(TextEditingController controller, int value) {
    setState(() {
      controller.text = '$value';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
    });

    final total = int.parse(_totalController.text);
    await MoneySettingsStore.instance.saveInstallment(
      InstallmentPlan(
        id: widget.plan?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        amount: _parseAmount(_amountController.text) ?? 0,
        totalInstallments: total,
        paidInstallments: int.parse(_paidController.text).clamp(0, total),
        startMonth: _startMonth,
        dueDay: int.parse(_dueDayController.text).clamp(1, 31),
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFEAFBFF),
                  Color(0xFFFFF4FA),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26305472),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0x2210233F),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const _IconBadge(icon: Icons.credit_card_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.plan == null
                                ? 'Add installment'
                                : 'Edit installment',
                            style: _pageTitleStyle.copyWith(fontSize: 24),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                            foregroundColor: const Color(0xFF10233F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InputCard(
                      label: 'Name',
                      child: TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Phone, laptop, card plan',
                          hintStyle: TextStyle(
                            color: Color(0x6665748B),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        validator: (value) =>
                            value?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InputCard(
                      label: strings.amount,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: const [_MoneyInputFormatter()],
                        decoration: InputDecoration.collapsed(
                          hintText: '${strings.amountPrefix}0',
                        ),
                        validator: (value) {
                          final amount = _parseAmount(value ?? '');
                          return amount == null || amount <= 0
                              ? strings.amountValidation
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final amount in const [500, 1000, 2000, 5000])
                          _QuickValueChip(
                            label: _formatMoney(amount.toDouble()),
                            onTap: () => _setAmount(amount.toDouble()),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _InputCard(
                            label: 'Total',
                            child: TextFormField(
                              controller: _totalController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration.collapsed(
                                hintText: '12',
                              ),
                              validator: (value) =>
                                  (int.tryParse(value ?? '') ?? 0) <= 0
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InputCard(
                            label: 'Paid',
                            child: TextFormField(
                              controller: _paidController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration.collapsed(
                                hintText: '0',
                              ),
                              validator: (value) =>
                                  int.tryParse(value ?? '') == null
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final total in const [
                          3,
                          6,
                          10,
                          12,
                          24,
                          36,
                          48,
                          60,
                        ])
                          _QuickValueChip(
                            label: '$total months',
                            onTap: () => _setNumber(_totalController, total),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final years in const [5, 10, 15, 20, 25, 30])
                          _QuickValueChip(
                            label: '$years years',
                            onTap: () =>
                                _setNumber(_totalController, years * 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _InputCard(
                            label: 'Start',
                            child: InkWell(
                              onTap: _pickStartMonth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  strings.formatMonthYear(_startMonth),
                                  style: _inputStyle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InputCard(
                            label: 'Due day',
                            child: TextFormField(
                              controller: _dueDayController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration.collapsed(
                                hintText: '1',
                              ),
                              validator: (value) {
                                final day = int.tryParse(value ?? '');
                                return day == null || day < 1 || day > 31
                                    ? '1-31'
                                    : null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final day in const [1, 5, 15, 25])
                          _QuickValueChip(
                            label: 'Day $day',
                            onTap: () => _setNumber(_dueDayController, day),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _saving ? strings.saving : strings.saveTransaction,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({
    required this.plan,
    required this.onEdit,
    required this.onPaid,
    required this.onDelete,
  });

  final InstallmentPlan plan;
  final VoidCallback onEdit;
  final VoidCallback? onPaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = '${plan.paidInstallments}/${plan.totalInstallments}';
    final ratio = plan.totalInstallments == 0
        ? 0.0
        : (plan.paidInstallments / plan.totalInstallments).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(icon: Icons.credit_card_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: _rowTitleStyle),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatMoney(plan.amount)} per cycle',
                      style: _mutedStyle,
                    ),
                  ],
                ),
              ),
              _CircleActionButton(
                icon: Icons.edit_rounded,
                tooltip: 'Edit installment',
                onPressed: onEdit,
              ),
              const SizedBox(width: 8),
              _CircleActionButton(
                icon: Icons.check_rounded,
                tooltip: 'Mark installment as paid',
                onPressed: onPaid,
                palette: _SupportTone.mint,
              ),
              const SizedBox(width: 8),
              _CircleActionButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete installment',
                onPressed: onDelete,
                palette: _SupportTone.rose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SupportStatStrip(
            children: [
              _SupportStatCard(
                label: 'Progress',
                value: progress,
                tone: _SupportTone.sky,
              ),
              _SupportStatCard(
                label: 'Due day',
                value: '${plan.dueDay}',
                tone: _SupportTone.mint,
              ),
              _SupportStatCard(
                label: 'Start',
                value: _formatMonthShort(plan.startMonth),
                tone: _SupportTone.rose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0x152F4B73),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1FC9DC)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportScaffold extends StatelessWidget {
  const _SupportScaffold({
    required this.status,
    required this.smallLabel,
    required this.title,
    required this.child,
    this.action,
  });

  final String status;
  final String smallLabel;
  final String title;
  final Widget child;
  final Widget? action;

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
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.72),
                        foregroundColor: const Color(0xFF10233F),
                      ),
                    ),
                    const Spacer(),
                    Text(status, style: _statusStyle),
                    if (action != null) ...[const SizedBox(width: 10), action!],
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _darkHeroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _heroTitleStyle),
          const SizedBox(height: 8),
          Text(message, style: _heroMessageStyle),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _mutedStyle),
          const SizedBox(height: 6),
          DefaultTextStyle(style: _inputStyle, child: child),
        ],
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _IconBadge(icon: icon),
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
        ],
      ),
    );
  }
}

class _CategoryUsageTile extends StatelessWidget {
  const _CategoryUsageTile({
    required this.definition,
    required this.subtitle,
    required this.tags,
  });

  final _CategoryDefinition definition;
  final String subtitle;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: categoryIconData(definition.id)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.label(context.strings),
                      style: _rowTitleStyle,
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: _mutedStyle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in tags) _TagChip(label: tag)],
          ),
        ],
      ),
    );
  }
}

class _SupportStatStrip extends StatelessWidget {
  const _SupportStatStrip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SupportStatCard extends StatelessWidget {
  const _SupportStatCard({
    required this.label,
    required this.value,
    this.tone = _SupportTone.sky,
  });

  final String label;
  final String value;
  final _SupportTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: tone.gradient),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _chipLabelStyle),
          const SizedBox(height: 6),
          Text(value, style: _statValueStyle),
        ],
      ),
    );
  }
}

class _SectionCaption extends StatelessWidget {
  const _SectionCaption({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _sectionTitleStyle),
        const SizedBox(height: 4),
        Text(subtitle, style: _mutedStyle),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x255D81AD)),
      ),
      child: Text(label, style: _chipLabelStyle),
    );
  }
}

class _QuickValueChip extends StatelessWidget {
  const _QuickValueChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x255D81AD)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 17, color: Color(0xFF145CC8)),
            const SizedBox(width: 6),
            Text(label, style: _chipLabelStyle),
          ],
        ),
      ),
    );
  }
}

class _SoftNoteCard extends StatelessWidget {
  const _SoftNoteCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FDFF), Color(0xFFFDF8FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x255D81AD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _rowTitleStyle),
                const SizedBox(height: 4),
                Text(message, style: _mutedStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x2E1FC9DC), Color(0x2E3268F6)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: const Color(0xFF145CC8), size: 22),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.78),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
  );
}

BoxDecoration _darkHeroDecoration() {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF084C61), Color(0xFF16697A)],
    ),
    borderRadius: BorderRadius.circular(28),
    boxShadow: const [
      BoxShadow(
        color: Color(0x2B16697A),
        blurRadius: 32,
        offset: Offset(0, 16),
      ),
    ],
  );
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1FC9DC), Color(0xFF3268F6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B1FC9DC),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: const Color(0xFF16345F),
        backgroundColor: Colors.white.withValues(alpha: 0.76),
        side: const BorderSide(color: Color(0x2E5D81AD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.palette = _SupportTone.sky,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final _SupportTone palette;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: palette.gradient),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
          ),
          child: Icon(icon, size: 20, color: palette.foreground),
        ),
      ),
    );
  }
}

const _pageTitleStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 30,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

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

const _heroTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 24,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _heroMessageStyle = TextStyle(
  color: Color(0xD9FFFFFF),
  fontSize: 14,
  fontWeight: FontWeight.w700,
  height: 1.45,
  letterSpacing: 0,
);

const _inputStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 18,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _sectionTitleStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 18,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _chipLabelStyle = TextStyle(
  color: Color(0xFF496582),
  fontSize: 11,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _statValueStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 16,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

double? _parseAmount(String value) {
  final parsed = double.tryParse(value.replaceAll(',', '').trim());
  return parsed == null || parsed <= 0 ? null : parsed;
}

String _formatAmount(double amount) {
  return formatOriginalNumber(amount);
}

String _formatMoney(double amount) {
  return 'THB ${_formatAmount(amount)}';
}

String _addThousandsSeparators(String digits) {
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

class _MoneyInputFormatter extends TextInputFormatter {
  const _MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    final parts = raw.split('.');
    var whole = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    if (whole.isEmpty) whole = '0';
    final decimalDigits = parts.length > 1
        ? parts.sublist(1).join().replaceAll(RegExp(r'[^0-9]'), '')
        : '';
    final limitedDecimalDigits = decimalDigits.length > 2
        ? decimalDigits.substring(0, 2)
        : decimalDigits;
    final decimal = parts.length > 1 ? '.$limitedDecimalDigits' : '';
    final formatted = '${_addThousandsSeparators(whole)}$decimal';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CategoryDefinition {
  const _CategoryDefinition(this.id);

  final String id;

  String label(AppStrings strings) {
    return switch (id) {
      'food' => strings.food,
      'drink' => strings.drink,
      'groceries' => strings.groceries,
      'transport' => strings.transport,
      'shopping' => strings.shopping,
      'bills' => strings.bills,
      'rent' => strings.rent,
      'health' => strings.health,
      'education' => strings.education,
      'entertainment' => strings.entertainment,
      'travel' => strings.travel,
      'family' => strings.family,
      'insurance' => strings.insurance,
      'tax' => strings.tax,
      'donation' => strings.donation,
      'transfer' => strings.transfer,
      'salary' => strings.salary,
      'side_job' => strings.sideJob,
      'business' => strings.business,
      'bonus' => strings.bonus,
      'investment' => strings.investment,
      'interest' => strings.interest,
      'sale' => strings.sale,
      'allowance' => strings.allowance,
      'gift' => strings.gift,
      'refund' => strings.refund,
      _ => strings.other,
    };
  }
}

enum _SupportTone {
  sky([Color(0xFFEAF7FF), Color(0xFFF6FBFF)], Color(0xFF135B9E)),
  mint([Color(0xFFEAFBF2), Color(0xFFF6FFF9)], Color(0xFF17785E)),
  rose([Color(0xFFFFF1F5), Color(0xFFFFFAFC)], Color(0xFFB5476A));

  const _SupportTone(this.gradient, this.foreground);

  final List<Color> gradient;
  final Color foreground;
}

String _formatMonthShort(DateTime date) {
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
  return '${months[date.month - 1]} ${date.year}';
}

const _expenseCategoryDefinitions = [
  _CategoryDefinition('food'),
  _CategoryDefinition('drink'),
  _CategoryDefinition('groceries'),
  _CategoryDefinition('transport'),
  _CategoryDefinition('shopping'),
  _CategoryDefinition('bills'),
  _CategoryDefinition('rent'),
  _CategoryDefinition('health'),
  _CategoryDefinition('education'),
  _CategoryDefinition('entertainment'),
  _CategoryDefinition('travel'),
  _CategoryDefinition('family'),
  _CategoryDefinition('insurance'),
  _CategoryDefinition('tax'),
  _CategoryDefinition('donation'),
  _CategoryDefinition('transfer'),
  _CategoryDefinition('other'),
];

const _incomeCategoryDefinitions = [
  _CategoryDefinition('salary'),
  _CategoryDefinition('side_job'),
  _CategoryDefinition('business'),
  _CategoryDefinition('bonus'),
  _CategoryDefinition('investment'),
  _CategoryDefinition('interest'),
  _CategoryDefinition('sale'),
  _CategoryDefinition('allowance'),
  _CategoryDefinition('gift'),
  _CategoryDefinition('refund'),
  _CategoryDefinition('other_income'),
];
