import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_language.dart';
import '../../shared/formatters/money_formatter.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import 'category_icons.dart';
import 'create_transaction_input.dart';
import 'custom_category_store.dart';
import 'transaction_record.dart';
import 'transaction_repository.dart';
import 'transaction_source.dart';
import 'transaction_type.dart';
import 'update_transaction_input.dart';

class ManualTransactionSheet extends StatefulWidget {
  const ManualTransactionSheet({
    required this.user,
    required this.transactionRepository,
    this.source = TransactionSource.manual,
    this.title = 'Add transaction',
    this.description,
    this.initialType = TransactionType.expense,
    this.initialDate,
    this.initialDateText,
    this.initialAmount,
    this.initialNote,
    this.initialCategoryId,
    this.slipFingerprint,
    this.slipReference,
    this.existingRecord,
    this.onSaved,
    this.onDeleted,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final TransactionSource source;
  final String title;
  final String? description;
  final TransactionType initialType;
  final double? initialAmount;
  final String? initialNote;
  final String? initialCategoryId;
  final String? slipFingerprint;
  final String? slipReference;
  final VoidCallback? onSaved;
  final VoidCallback? onDeleted;
  final DateTime? initialDate;
  final String? initialDateText;
  final TransactionRecord? existingRecord;

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
          top: 28,
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
            initialAmount: widget.initialAmount,
            initialNote: widget.initialNote,
            initialCategoryId: widget.initialCategoryId,
            initialDate: widget.initialDate,
            initialDateText: widget.initialDateText,
            slipFingerprint: widget.slipFingerprint,
            slipReference: widget.slipReference,
            existingRecord: widget.existingRecord,
            onSaved: widget.onSaved ?? () => Navigator.of(context).pop(true),
            onDeleted:
                widget.onDeleted ?? () => Navigator.of(context).pop('deleted'),
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
    this.initialDate,
    this.initialDateText,
    this.description,
    this.initialAmount,
    this.initialNote,
    this.initialCategoryId,
    this.slipFingerprint,
    this.slipReference,
    this.existingRecord,
    this.onSaved,
    this.onDeleted,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final TransactionSource source;
  final String title;
  final String? description;
  final TransactionType initialType;
  final double? initialAmount;
  final String? initialNote;
  final String? initialCategoryId;
  final String? slipFingerprint;
  final String? slipReference;
  final VoidCallback? onSaved;
  final VoidCallback? onDeleted;
  final DateTime? initialDate;
  final String? initialDateText;
  final TransactionRecord? existingRecord;

  bool get isEditing => existingRecord != null;

  @override
  State<ManualTransactionForm> createState() => _ManualTransactionFormState();
}

class _ManualTransactionFormState extends State<ManualTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _type;
  late _CategoryOption _category;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _isDeleting = false;
  List<CustomCategory> _customCategories = const [];

  List<_CategoryOption> get _categories => [
    ..._categoriesFor(_type),
    ..._customCategories
        .where((category) => category.type == _type)
        .map(
          (category) => _CategoryOption(
            id: category.id,
            savedName: category.name,
            customLabel: category.name,
          ),
        ),
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.existingRecord?.type ?? widget.initialType;
    _selectedDate =
        widget.existingRecord?.transactionDate ??
        widget.initialDate ??
        DateTime.now();
    _category = _resolveInitialCategory();
    _applyInitialValues(force: true);
    _loadCustomCategories();
  }

  Future<void> _loadCustomCategories() async {
    final categories = await CustomCategoryStore.instance.load(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _customCategories = categories;
      final categoryId =
          widget.existingRecord?.categoryId ?? widget.initialCategoryId;
      if (categoryId != null) {
        for (final option in _categories) {
          if (option.id == categoryId) {
            _category = option;
            break;
          }
        }
      }
    });
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.strings.isThai ? 'เพิ่มหมวดหมู่ใหม่' : 'Add category',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: context.strings.isThai
                ? 'ชื่อหมวดหมู่'
                : 'Category name',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.strings.isThai ? 'ยกเลิก' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.strings.isThai ? 'เพิ่ม' : 'Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final category = await CustomCategoryStore.instance.add(
      userId: widget.user.uid,
      name: name,
      type: _type,
    );
    if (!mounted) return;
    final categories = await CustomCategoryStore.instance.load(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _customCategories = List.of(categories);
      _category = _CategoryOption(
        id: category.id,
        savedName: category.name,
        customLabel: category.name,
      );
    });
  }

  @override
  void didUpdateWidget(covariant ManualTransactionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existingRecord?.id != widget.existingRecord?.id ||
        oldWidget.initialType != widget.initialType ||
        oldWidget.initialAmount != widget.initialAmount ||
        oldWidget.initialNote != widget.initialNote ||
        oldWidget.initialDate != widget.initialDate) {
      _type = widget.existingRecord?.type ?? widget.initialType;
      _selectedDate =
          widget.existingRecord?.transactionDate ??
          widget.initialDate ??
          DateTime.now();
      _category = _resolveInitialCategory();
      _applyInitialValues(force: true);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  _CategoryOption _resolveInitialCategory() {
    final categoryId =
        widget.existingRecord?.categoryId ?? widget.initialCategoryId;
    if (categoryId != null) {
      for (final option in _categoriesFor(_type)) {
        if (option.id == categoryId) {
          return option;
        }
      }
    }
    return _categoriesFor(_type).first;
  }

  void _applyInitialValues({bool force = false}) {
    final existingRecord = widget.existingRecord;
    final initialAmount = existingRecord?.amount ?? widget.initialAmount;
    final initialNote = existingRecord?.note ?? widget.initialNote;

    if (force || _amountController.text.trim().isEmpty) {
      _amountController.text = initialAmount == null
          ? ''
          : _formatNumber(initialAmount);
    }

    if (force || _noteController.text.trim().isEmpty) {
      _noteController.text = initialNote?.trim() ?? '';
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      builder: kimjodDatePickerTheme,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _setType(TransactionType type) {
    setState(() {
      _type = type;
      _category = _categoriesFor(type).first;
    });
  }

  Future<void> _save({bool forceOverwrite = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final note = _noteController.text.trim();
    final amount = _parseAmount(_amountController.text);
    final transactionDateText = context.strings.formatDateTime(_selectedDate);

    try {
      if (widget.isEditing) {
        final existing = widget.existingRecord!;
        await widget.transactionRepository.updateTransaction(
          UpdateTransactionInput(
            transactionId: existing.id,
            userId: widget.user.uid,
            amount: amount,
            type: _type,
            categoryId: _category.id,
            categoryName: _category.savedName,
            transactionDate: _selectedDate,
            transactionDateText: transactionDateText,
            source: existing.source,
            note: note.isEmpty ? null : note,
            slipFingerprint: existing.slipFingerprint,
            slipReference: existing.slipReference,
            baseUpdatedAt: existing.updatedAt,
            forceOverwrite: forceOverwrite,
          ),
        );
      } else {
        await widget.transactionRepository.createManualTransaction(
          CreateTransactionInput(
            userId: widget.user.uid,
            amount: amount,
            type: _type,
            categoryId: _category.id,
            categoryName: _category.savedName,
            transactionDate: _selectedDate,
            transactionDateText: transactionDateText,
            source: widget.source,
            note: note.isEmpty ? null : note,
            slipFingerprint: widget.slipFingerprint,
            slipReference: widget.slipReference,
          ),
        );
      }

      if (mounted) {
        widget.onSaved?.call();
      }
    } on TransactionConflictException catch (conflict) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final overwrite = await _showConflictDialog(conflict);
      if (overwrite == true && mounted) {
        await _save(forceOverwrite: true);
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

  Future<bool?> _showConflictDialog(TransactionConflictException conflict) {
    final serverAmount = (conflict.serverData['amount'] as num?)?.toDouble();
    final serverNote = conflict.serverData['note']?.toString();
    final localAmount = _parseAmount(_amountController.text);
    final localNote = _noteController.text.trim();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.strings.isThai
              ? 'พบข้อมูลที่แก้จากอีกเครื่อง'
              : 'Cloud version changed',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.strings.isThai
                  ? 'เลือกว่าจะเก็บข้อมูลใด ระบบจะไม่เขียนทับให้เอง'
                  : 'Choose which version to keep. Nothing is overwritten automatically.',
            ),
            const SizedBox(height: 14),
            _ConflictVersion(
              label: context.strings.isThai ? 'ในเครื่องนี้' : 'This device',
              amount: localAmount,
              note: localNote,
            ),
            const SizedBox(height: 8),
            _ConflictVersion(
              label: context.strings.isThai ? 'บน cloud' : 'Cloud',
              amount: serverAmount,
              note: serverNote,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.strings.isThai ? 'เก็บข้อมูล cloud' : 'Keep cloud',
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              context.strings.isThai
                  ? 'ใช้ข้อมูลเครื่องนี้'
                  : 'Use this device',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final existing = widget.existingRecord;
    if (existing == null || _isDeleting || _isSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final strings = context.strings;
        return KimjodDialog(
          title: strings.isThai ? 'ลบรายการนี้?' : 'Delete transaction?',
          icon: Icons.delete_rounded,
          message: strings.isThai
              ? 'รายการนี้จะถูกลบถาวรและไม่สามารถย้อนกลับได้'
              : 'This will permanently remove this transaction.',
          actions: [
            KimjodDialogAction(
              label: strings.isThai ? 'ยกเลิก' : 'Cancel',
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            KimjodDialogAction(
              label: strings.isThai ? 'ลบ' : 'Delete',
              icon: Icons.delete_rounded,
              isPrimary: true,
              isDestructive: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await widget.transactionRepository.deleteTransaction(
        userId: widget.user.uid,
        transactionId: existing.id,
      );
      if (mounted) {
        widget.onDeleted?.call();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.couldNotSaveTransaction)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0x2210233F),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Color(0xFF10233F),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                          letterSpacing: 0,
                        ),
                      ),
                      if (widget.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.description!,
                          style: const TextStyle(
                            color: Color(0xFF65748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: KimjodMascot(size: 58, scene: MascotScene.transaction),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AmountField(controller: _amountController, enabled: !_isBusy),
          const SizedBox(height: 12),
          _TypeSelector(type: _type, enabled: !_isBusy, onChanged: _setType),
          if (_type == TransactionType.internalTransfer) ...[
            const SizedBox(height: 12),
            const _InternalTransferHintCard(),
          ],
          const SizedBox(height: 12),
          _CategoryField(
            categories: _categories,
            selected: _category,
            enabled: !_isBusy,
            onChanged: (category) {
              setState(() {
                _category = category;
              });
            },
            onAdd: _addCategory,
          ),
          const SizedBox(height: 12),
          _DateField(
            label: context.strings.date,
            value: context.strings.formatDate(_selectedDate),
            enabled: !_isBusy,
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          _DateField(
            label: context.strings.isThai ? 'เวลา' : 'Time',
            value: context.strings.formatTime(_selectedDate),
            enabled: !_isBusy,
            onTap: _pickTime,
          ),
          const SizedBox(height: 12),
          _TextFieldBlock(
            controller: _noteController,
            enabled: !_isBusy,
            label: context.strings.note,
            hint: context.strings.noteHint,
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: widget.isEditing
                ? (_isSaving ? context.strings.saving : 'Save changes')
                : (_isSaving
                      ? context.strings.saving
                      : context.strings.saveTransaction),
            onPressed: _isBusy ? null : _save,
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 10),
            _DangerButton(
              label: _isDeleting
                  ? context.strings.saving
                  : 'Delete transaction',
              onPressed: _isBusy ? null : _delete,
            ),
          ],
        ],
      ),
    );
  }

  bool get _isBusy => _isSaving || _isDeleting;
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
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [_AmountTextInputFormatter()],
        style: const TextStyle(
          color: Color(0xFF071844),
          fontSize: 42,
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
            fontWeight: FontWeight.w700,
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
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12305472),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Segment(
                  label: context.strings.expense,
                  icon: Icons.south_west_rounded,
                  selected: type == TransactionType.expense,
                  enabled: enabled,
                  palette: _SegmentPalette.expense,
                  onTap: () => onChanged(TransactionType.expense),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Segment(
                  label: context.strings.income,
                  icon: Icons.north_east_rounded,
                  selected: type == TransactionType.income,
                  enabled: enabled,
                  palette: _SegmentPalette.income,
                  onTap: () => onChanged(TransactionType.income),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Segment(
            label: context.strings.internalTransfer,
            icon: Icons.sync_alt_rounded,
            selected: type == TransactionType.internalTransfer,
            enabled: enabled,
            palette: _SegmentPalette.transfer,
            fullWidth: true,
            onTap: () => onChanged(TransactionType.internalTransfer),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.palette,
    required this.onTap,
    this.fullWidth = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final _SegmentPalette palette;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: BoxConstraints(
          minHeight: fullWidth ? 54 : 46,
          minWidth: fullWidth ? double.infinity : 0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: palette.selectedGradient)
              : null,
          color: selected ? null : palette.unselectedColor,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: selected ? palette.selectedBorder : palette.unselectedBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.glow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : palette.iconColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : palette.textColor,
                  fontSize: fullWidth ? 14 : 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return fullWidth ? child : child;
  }
}

class _SegmentPalette {
  const _SegmentPalette({
    required this.selectedGradient,
    required this.unselectedColor,
    required this.unselectedBorder,
    required this.selectedBorder,
    required this.textColor,
    required this.iconColor,
    required this.glow,
  });

  static const expense = _SegmentPalette(
    selectedGradient: [Color(0xFFE95E7A), Color(0xFFD94768)],
    unselectedColor: Color(0xFFFDF2F4),
    unselectedBorder: Color(0x33D94768),
    selectedBorder: Color(0x40FFFFFF),
    textColor: Color(0xFFAA3A58),
    iconColor: Color(0xFFD94768),
    glow: Color(0x29D94768),
  );

  static const income = _SegmentPalette(
    selectedGradient: [Color(0xFF34CDA2), Color(0xFF179E78)],
    unselectedColor: Color(0xFFF1FBF7),
    unselectedBorder: Color(0x33179E78),
    selectedBorder: Color(0x40FFFFFF),
    textColor: Color(0xFF197F62),
    iconColor: Color(0xFF179E78),
    glow: Color(0x29179E78),
  );

  static const transfer = _SegmentPalette(
    selectedGradient: [Color(0xFF1EB6D1), Color(0xFF167FBA)],
    unselectedColor: Color(0xFFF0FAFD),
    unselectedBorder: Color(0x33167FBA),
    selectedBorder: Color(0x40FFFFFF),
    textColor: Color(0xFF17698F),
    iconColor: Color(0xFF167FBA),
    glow: Color(0x29167FBA),
  );

  final List<Color> selectedGradient;
  final Color unselectedColor;
  final Color unselectedBorder;
  final Color selectedBorder;
  final Color textColor;
  final Color iconColor;
  final Color glow;
}

class _InternalTransferHintCard extends StatelessWidget {
  const _InternalTransferHintCard();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8FBFF), Color(0xFFF2FCFF), Color(0xFFF6FEFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33167FBA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x16167FBA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF167FBA)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.internalTransfer,
                  style: const TextStyle(
                    color: Color(0xFF0E5677),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.isThai
                      ? 'ใช้เมื่อเงินถูกย้ายระหว่างบัญชีของคุณเอง ไม่ใช่รายรับหรือรายจ่ายใหม่'
                      : 'Use this when money is moving between your own accounts, not new income or spending.',
                  style: const TextStyle(
                    color: Color(0xFF4F7489),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: 0,
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

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.categories,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.onAdd,
  });

  final List<_CategoryOption> categories;
  final _CategoryOption selected;
  final bool enabled;
  final ValueChanged<_CategoryOption> onChanged;
  final VoidCallback onAdd;

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
          _AddCategoryButton(enabled: enabled, onTap: onAdd),
        ],
      ),
    );
  }
}

class _AddCategoryButton extends StatelessWidget {
  const _AddCategoryButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: enabled ? onTap : null,
      avatar: const Icon(Icons.add_rounded, size: 18),
      label: Text(context.strings.isThai ? 'เพิ่มหมวด' : 'Add category'),
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
    final accent = categoryAccentColor(category.id);
    final foreground = selected ? accent : const Color(0xFF40524C);

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.36)
                  : const Color(0x1870807A),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.17 : 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIconData(category.id),
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
        maxLines: 3,
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
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

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
        onPressed: onPressed,
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
          label,
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

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: const Color(0xFFB4485D),
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        side: const BorderSide(color: Color(0x33B4485D)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
      ),
      label: Text(
        label,
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
  const _CategoryOption({
    required this.id,
    required this.savedName,
    this.customLabel,
  });

  final String id;
  final String savedName;
  final String? customLabel;

  String label(AppStrings strings) {
    if (customLabel != null) return customLabel!;
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
      'internal_transfer' => strings.internalTransfer,
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
  return switch (type) {
    TransactionType.expense => _expenseCategories,
    TransactionType.income => _incomeCategories,
    TransactionType.internalTransfer => _internalTransferCategories,
  };
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

const _internalTransferCategories = [
  _CategoryOption(id: 'internal_transfer', savedName: 'Internal Transfer'),
];

class _ConflictVersion extends StatelessWidget {
  const _ConflictVersion({
    required this.label,
    required this.amount,
    required this.note,
  });

  final String label;
  final double? amount;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            '${amount == null ? '-' : formatOriginalNumber(amount!)} THB · '
            '${(note?.trim().isNotEmpty ?? false) ? note!.trim() : '-'}',
          ),
        ],
      ),
    );
  }
}

double _parseAmount(String value) {
  return normalizeMoneyAmount(_tryParseAmount(value)!);
}

double? _tryParseAmount(String? value) {
  return double.tryParse((value ?? '').replaceAll(',', '').trim());
}

String _formatNumber(double amount) {
  return formatOriginalNumber(amount);
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
