import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import 'category_icons.dart';
import 'create_transaction_input.dart';
import 'transaction_repository.dart';
import 'transaction_source.dart';
import 'transaction_type.dart';

class ManualAddScreen extends StatefulWidget {
  const ManualAddScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  @override
  State<ManualAddScreen> createState() => _ManualAddScreenState();
}

class _ManualAddScreenState extends State<ManualAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _detailController = TextEditingController();

  var _type = TransactionType.expense;
  var _category = _expenseCategories.first;
  late DateTime _selectedDate;
  var _isSaving = false;

  List<_CategoryOption> get _categories =>
      _type == TransactionType.expense ? _expenseCategories : _incomeCategories;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3268F6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF10233F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _setType(TransactionType type) {
    setState(() {
      _type = type;
      _category = _categoriesFor(type).first;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final notes = [
      _noteController.text.trim(),
      _detailController.text.trim(),
    ].where((value) => value.isNotEmpty).join(' / ');

    try {
      await widget.transactionRepository.createManualTransaction(
        CreateTransactionInput(
          userId: widget.user.uid,
          amount: _parseAmount(_amountController.text),
          type: _type,
          categoryId: _category.id,
          categoryName: _category.savedName,
          transactionDate: _selectedDate,
          source: TransactionSource.manual,
          note: notes,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.couldNotSaveTransaction)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final strings = context.strings;

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
            padding: EdgeInsets.fromLTRB(22, 18, 22, bottomInset + 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusRow(onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 24),
                  Text(
                    strings.addTransaction,
                    style: const TextStyle(
                      color: Color(0xFF10233F),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: KimjodMascot(size: 68),
                  ),
                  const SizedBox(height: 12),
                  MascotTip(message: strings.addTransactionTip),
                  const SizedBox(height: 22),
                  _FormSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AmountField(
                          controller: _amountController,
                          enabled: !_isSaving,
                        ),
                        const SizedBox(height: 12),
                        _TypeSelector(
                          type: _type,
                          enabled: !_isSaving,
                          onChanged: _setType,
                        ),
                        const SizedBox(height: 12),
                        _CategoryField(
                          categories: _categories,
                          selected: _category,
                          enabled: !_isSaving,
                          onChanged: (category) {
                            setState(() {
                              _category = category;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _DateField(
                          label: strings.date,
                          value: strings.formatDate(_selectedDate),
                          enabled: !_isSaving,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 12),
                        _TextFieldBlock(
                          controller: _noteController,
                          enabled: !_isSaving,
                          label: strings.note,
                          hint: strings.noteHint,
                        ),
                        const SizedBox(height: 12),
                        _TextFieldBlock(
                          controller: _detailController,
                          enabled: !_isSaving,
                          label: strings.details,
                          hint: strings.detailsHint,
                        ),
                        const SizedBox(height: 12),
                        _PrimaryButton(isSaving: _isSaving, onPressed: _save),
                        const SizedBox(height: 12),
                        _SecondaryButton(enabled: !_isSaving),
                      ],
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: const Color(0xFF10233F),
          tooltip: context.strings.back,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _FormSurface extends StatelessWidget {
  const _FormSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: child,
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x291FC9DC), Color(0x1F6A4DF4)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14305472),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        autofocus: false,
        showCursor: false,
        inputFormatters: const [_AmountTextInputFormatter()],
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          color: Color(0xFF071844),
          fontSize: 46,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          labelText: context.strings.amount,
          floatingLabelAlignment: FloatingLabelAlignment.center,
          prefixText: context.strings.amountPrefix,
          hintText: '0',
          border: InputBorder.none,
          labelStyle: const TextStyle(
            color: Color(0xFF10233F),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          hintStyle: const TextStyle(color: Color(0x6610233F)),
        ),
        validator: (value) {
          final amount = _tryParseAmount(value);
          if (amount == null || amount <= 0) {
            return context.strings.amountValidation;
          }

          return null;
        },
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.type,
    required this.enabled,
    required this.onChanged,
  });

  final TransactionType type;
  final bool enabled;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
      ),
      child: Row(
        children: [
          _Segment(
            label: context.strings.expense,
            selected: type == TransactionType.expense,
            enabled: enabled,
            onTap: () => onChanged(TransactionType.expense),
          ),
          _Segment(
            label: context.strings.income,
            selected: type == TransactionType.income,
            enabled: enabled,
            onTap: () => onChanged(TransactionType.income),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 46),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF1FC9DC), Color(0xFF3268F6)],
                  )
                : null,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF65748B),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.categories,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<_CategoryOption> categories;
  final _CategoryOption selected;
  final bool enabled;
  final ValueChanged<_CategoryOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: context.strings.category,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in categories)
            _CategoryIconButton(
              category: category,
              selected: selected.id == category.id,
              enabled: enabled,
              onTap: () => onChanged(category),
            ),
        ],
      ),
    );
  }
}

class _CategoryIconButton extends StatelessWidget {
  const _CategoryIconButton({
    required this.category,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _CategoryOption category;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = category.label(context.strings);
    final color = selected ? Colors.white : const Color(0xFF1D3C6C);

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF1FC9DC), Color(0xFF3268F6)],
                    )
                  : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.82)
                    : const Color(0x2E5D81AD),
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x241FC9DC),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(categoryIconData(category.id), color: color, size: 21),
                const SizedBox(width: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF10233F),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF3268F6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextFieldBlock extends StatelessWidget {
  const _TextFieldBlock({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        minLines: 1,
        maxLines: 2,
        style: const TextStyle(
          color: Color(0xFF10233F),
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0x8065748B),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF65748B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.isSaving, required this.onPressed});

  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1FC9DC), Color(0xFF3268F6)],
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D1FC9DC),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: isSaving ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21),
          ),
        ),
        child: Text(
          isSaving ? context.strings.saving : context.strings.saveTransaction,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? () {} : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        foregroundColor: const Color(0xFF16345F),
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        side: const BorderSide(color: Color(0x2E5D81AD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
      ),
      child: Text(
        context.strings.saveAsInstallment,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption({required this.id, required this.savedName});

  final String id;
  final String savedName;

  String label(AppStrings strings) {
    return switch (id) {
      'food' => strings.food,
      'drink' => strings.drink,
      'groceries' => strings.groceries,
      'transport' => strings.transport,
      'bills' => strings.bills,
      'shopping' => strings.shopping,
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

List<_CategoryOption> _categoriesFor(TransactionType type) {
  return type == TransactionType.expense
      ? _expenseCategories
      : _incomeCategories;
}

const _expenseCategories = [
  _CategoryOption(id: 'food', savedName: 'Food'),
  _CategoryOption(id: 'drink', savedName: 'Drinks'),
  _CategoryOption(id: 'groceries', savedName: 'Groceries'),
  _CategoryOption(id: 'transport', savedName: 'Transport'),
  _CategoryOption(id: 'shopping', savedName: 'Shopping'),
  _CategoryOption(id: 'bills', savedName: 'Bills'),
  _CategoryOption(id: 'rent', savedName: 'Rent / Home'),
  _CategoryOption(id: 'health', savedName: 'Health'),
  _CategoryOption(id: 'education', savedName: 'Education'),
  _CategoryOption(id: 'entertainment', savedName: 'Entertainment'),
  _CategoryOption(id: 'travel', savedName: 'Travel'),
  _CategoryOption(id: 'family', savedName: 'Family'),
  _CategoryOption(id: 'insurance', savedName: 'Insurance'),
  _CategoryOption(id: 'tax', savedName: 'Tax / Fees'),
  _CategoryOption(id: 'donation', savedName: 'Donation'),
  _CategoryOption(id: 'transfer', savedName: 'Transfer'),
  _CategoryOption(id: 'other', savedName: 'Other'),
];

const _incomeCategories = [
  _CategoryOption(id: 'salary', savedName: 'Salary'),
  _CategoryOption(id: 'side_job', savedName: 'Side Job'),
  _CategoryOption(id: 'business', savedName: 'Business'),
  _CategoryOption(id: 'bonus', savedName: 'Bonus'),
  _CategoryOption(id: 'investment', savedName: 'Investment'),
  _CategoryOption(id: 'interest', savedName: 'Interest / Dividend'),
  _CategoryOption(id: 'sale', savedName: 'Sale'),
  _CategoryOption(id: 'allowance', savedName: 'Allowance'),
  _CategoryOption(id: 'gift', savedName: 'Gift'),
  _CategoryOption(id: 'refund', savedName: 'Refund'),
  _CategoryOption(id: 'other_income', savedName: 'Other'),
];

double _parseAmount(String value) {
  return _tryParseAmount(value)!;
}

double? _tryParseAmount(String? value) {
  return double.tryParse((value ?? '').replaceAll(',', '').trim());
}

class _AmountTextInputFormatter extends TextInputFormatter {
  const _AmountTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final parts = raw.split('.');
    var whole = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    if (whole.isEmpty) {
      whole = '0';
    }

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
