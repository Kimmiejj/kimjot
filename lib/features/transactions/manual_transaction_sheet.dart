import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../auth/auth_user.dart';
import 'create_transaction_input.dart';
import 'transaction_repository.dart';
import 'transaction_source.dart';
import 'transaction_type.dart';

class ManualTransactionSheet extends StatefulWidget {
  const ManualTransactionSheet({
    required this.user,
    required this.transactionRepository,
    this.source = TransactionSource.manual,
    this.title = 'Add transaction',
    this.description,
    this.initialType = TransactionType.expense,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final TransactionSource source;
  final String title;
  final String? description;
  final TransactionType initialType;

  @override
  State<ManualTransactionSheet> createState() => _ManualTransactionSheetState();
}

class _ManualTransactionSheetState extends State<ManualTransactionSheet> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: ManualTransactionForm(
            user: widget.user,
            transactionRepository: widget.transactionRepository,
            source: widget.source,
            title: widget.title,
            description: widget.description,
            initialType: widget.initialType,
            onSaved: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    );
  }
}

class ManualTransactionForm extends StatefulWidget {
  const ManualTransactionForm({
    required this.user,
    required this.transactionRepository,
    required this.source,
    required this.title,
    required this.initialType,
    this.description,
    this.onSaved,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final TransactionSource source;
  final String title;
  final String? description;
  final TransactionType initialType;
  final VoidCallback? onSaved;

  @override
  State<ManualTransactionForm> createState() => _ManualTransactionFormState();
}

class _ManualTransactionFormState extends State<ManualTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _type;
  late _CategoryOption _category;
  bool _isSaving = false;

  List<_CategoryOption> get _categories {
    return _type == TransactionType.expense
        ? _expenseCategories
        : _incomeCategories;
  }

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = _categories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.parse(_amountController.text.trim());

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.transactionRepository.createManualTransaction(
        CreateTransactionInput(
          userId: widget.user.uid,
          amount: amount,
          type: _type,
          categoryId: _category.id,
          categoryName: _category.name,
          transactionDate: DateTime.now(),
          source: widget.source,
          note: _noteController.text,
        ),
      );

      if (mounted) {
        widget.onSaved?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.couldNotSaveTransaction)),
        );
      }
    }
  }

  void _setType(TransactionType type) {
    setState(() {
      _type = type;
      _category = _categories.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Form(
      key: _formKey,
      child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFF071844),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.description!,
                    style: const TextStyle(
                      color: Color(0xFF65748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SegmentedButton<TransactionType>(
                  segments: [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text(strings.expense),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text(strings.income),
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: _isSaving
                      ? null
                      : (selection) => _setType(selection.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: strings.amount,
                    prefixText: strings.amountPrefix,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) {
                      return strings.amountValidation;
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in _categories)
                      ChoiceChip(
                        label: Text(category.label(strings)),
                        selected: _category.id == category.id,
                        onSelected: _isSaving
                            ? null
                            : (_) {
                                setState(() {
                                  _category = category;
                                });
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  enabled: !_isSaving,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: strings.note,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving ? strings.saving : strings.saveTransaction,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ],
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption({required this.id, required this.name});

  final String id;
  final String name;

  String label(AppStrings strings) {
    return switch (id) {
      'food' => strings.food,
      'transport' => strings.transport,
      'shopping' => strings.shopping,
      'bills' => strings.bills,
      'transfer' => strings.transfer,
      'salary' => strings.salary,
      'side_job' => strings.sideJob,
      'gift' => strings.gift,
      'refund' => strings.refund,
      _ => strings.other,
    };
  }
}

const _expenseCategories = [
  _CategoryOption(id: 'food', name: 'Food'),
  _CategoryOption(id: 'transport', name: 'Transport'),
  _CategoryOption(id: 'shopping', name: 'Shopping'),
  _CategoryOption(id: 'bills', name: 'Bills'),
  _CategoryOption(id: 'transfer', name: 'Transfer'),
  _CategoryOption(id: 'other', name: 'Other'),
];

const _incomeCategories = [
  _CategoryOption(id: 'salary', name: 'Salary'),
  _CategoryOption(id: 'side_job', name: 'Side Job'),
  _CategoryOption(id: 'gift', name: 'Gift'),
  _CategoryOption(id: 'refund', name: 'Refund'),
  _CategoryOption(id: 'other_income', name: 'Other'),
];
