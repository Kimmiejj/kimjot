import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? strings.saving : 'Save budget'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        _budgetController.clear();
                        await _save();
                      },
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear budget'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({super.key});

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  final _store = MoneySettingsStore.instance;
  late Future<MoneySettingsSnapshot> _settingsFuture;

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
                    onPaid: () async {
                      await _store.markInstallmentPaid(plan.id);
                      _reload();
                    },
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

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return _SupportScaffold(
      status: 'READY',
      smallLabel: strings.category,
      title: strings.manageCategories,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MascotTip(message: strings.categoriesHeroMessage),
          const SizedBox(height: 14),
          _HeroPanel(
            title: strings.defaultCategoriesReady,
            message:
                'These categories are already used by manual entries, slip imports, budgets, and summaries.',
          ),
          const SizedBox(height: 16),
          _SupportRow(
            icon: Icons.restaurant_rounded,
            title: strings.food,
            subtitle: strings.defaultExpense,
          ),
          const SizedBox(height: 10),
          _SupportRow(
            icon: Icons.directions_bus_rounded,
            title: strings.transport,
            subtitle: strings.defaultExpense,
          ),
          const SizedBox(height: 10),
          _SupportRow(
            icon: Icons.receipt_long_rounded,
            title: strings.bills,
            subtitle: strings.defaultExpense,
          ),
          const SizedBox(height: 10),
          _SupportRow(
            icon: Icons.more_horiz_rounded,
            title: strings.other,
            subtitle: strings.defaultCategory,
          ),
        ],
      ),
    );
  }
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
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startMonth = DateTime(picked.year, picked.month);
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.plan == null
                        ? 'Add installment'
                        : 'Edit installment',
                    style: _pageTitleStyle.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 14),
                  _InputCard(
                    label: 'Name',
                    child: TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration.collapsed(
                        hintText: 'Phone, laptop, card plan',
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
                  Row(
                    children: [
                      Expanded(
                        child: _InputCard(
                          label: 'Start',
                          child: InkWell(
                            onTap: _pickStartMonth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _saving ? strings.saving : strings.saveTransaction,
                    ),
                  ),
                ],
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
  final VoidCallback onPaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final progress = '${plan.paidInstallments}/${plan.totalInstallments}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
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
                  '${_formatMoney(plan.amount)} - $progress - due day ${plan.dueDay}',
                  style: _mutedStyle,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'paid') onPaid();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'paid', child: Text(strings.markAsPaid)),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
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

double? _parseAmount(String value) {
  final parsed = double.tryParse(value.replaceAll(',', '').trim());
  return parsed == null || parsed <= 0 ? null : parsed;
}

String _formatAmount(double amount) {
  final fixed = amount.toStringAsFixed(
    amount == amount.roundToDouble() ? 0 : 2,
  );
  final parts = fixed.split('.');
  final whole = parts.first;
  final decimal = parts.length > 1 ? '.${parts[1]}' : '';
  return '${_addThousandsSeparators(whole)}$decimal';
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
    final decimal = parts.length > 1
        ? '.${parts.sublist(1).join().replaceAll(RegExp(r'[^0-9]'), '')}'
        : '';
    final formatted = '${_addThousandsSeparators(whole)}$decimal';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
