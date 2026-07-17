import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/formatters/money_formatter.dart';
import '../auth/auth_user.dart';
import '../scan/external_ai_client.dart';
import '../transactions/category_icons.dart';
import '../transactions/category_localization.dart';
import '../transactions/create_transaction_input.dart';
import '../transactions/manual_add_screen.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';

class VoiceTransactionReviewScreen extends StatefulWidget {
  const VoiceTransactionReviewScreen({
    required this.user,
    required this.transactionRepository,
    required this.transcript,
    required this.drafts,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final String transcript;
  final List<VoiceTransactionDraft> drafts;

  @override
  State<VoiceTransactionReviewScreen> createState() =>
      _VoiceTransactionReviewScreenState();
}

class _VoiceTransactionReviewScreenState
    extends State<VoiceTransactionReviewScreen> {
  late final List<bool> _saved;
  final Set<int> _saving = <int>{};

  int get _savedCount => _saved.where((saved) => saved).length;

  @override
  void initState() {
    super.initState();
    _saved = List<bool>.filled(widget.drafts.length, false);
  }

  Future<void> _save(int index) async {
    if (_saved[index] || _saving.contains(index)) return;
    final draft = widget.drafts[index];
    setState(() => _saving.add(index));
    try {
      final categoryName = localizedCategoryName(
        strings: context.strings,
        categoryId: draft.categoryId,
        fallbackName: draft.categoryName,
      );
      await widget.transactionRepository.createManualTransaction(
        CreateTransactionInput(
          userId: widget.user.uid,
          amount: draft.amount,
          type: draft.type,
          categoryId: draft.categoryId,
          categoryName: categoryName,
          transactionDate: draft.transactionDate,
          transactionDateText: context.strings.formatDateTime(
            draft.transactionDate,
          ),
          source: TransactionSource.manual,
          note: draft.note,
        ),
      );
      if (!mounted) return;
      setState(() => _saved[index] = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.isThai
                ? '\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e44\u0e21\u0e48\u0e2a\u0e33\u0e40\u0e23\u0e47\u0e08 \u0e25\u0e2d\u0e07\u0e43\u0e2b\u0e21\u0e48\u0e2d\u0e35\u0e01\u0e04\u0e23\u0e31\u0e49\u0e07'
                : 'Could not save this transaction. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(index));
    }
  }

  Future<void> _editAndSave(int index) async {
    if (_saved[index] || _saving.contains(index)) return;
    final draft = widget.drafts[index];
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ManualAddScreen(
          user: widget.user,
          transactionRepository: widget.transactionRepository,
          initialType: draft.type,
          initialDate: draft.transactionDate,
          initialAmount: draft.amount,
          initialNote: draft.note,
          initialCategoryId: draft.categoryId,
        ),
      ),
    );
    if (saved == true && mounted) setState(() => _saved[index] = true);
  }

  void _close() => Navigator.of(context).pop(_savedCount > 0);

  @override
  Widget build(BuildContext context) {
    final thai = context.strings.isThai;
    final total = widget.drafts.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _close,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          thai
              ? '\u0e15\u0e23\u0e27\u0e08\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e08\u0e32\u0e01\u0e40\u0e2a\u0e35\u0e22\u0e07'
              : 'Review voice transactions',
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5EF), Color(0xFFE7F8F0), Color(0xFFFFEFE7)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  children: [
                    Text(
                      thai
                          ? 'AI \u0e41\u0e22\u0e01\u0e44\u0e14\u0e49 $total \u0e23\u0e32\u0e22\u0e01\u0e32\u0e23'
                          : 'AI found $total ${total == 1 ? 'transaction' : 'transactions'}',
                      style: const TextStyle(
                        color: Color(0xFF172826),
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      thai
                          ? '\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e41\u0e22\u0e01\u0e17\u0e35\u0e25\u0e30\u0e43\u0e1a \u0e2b\u0e23\u0e37\u0e2d\u0e41\u0e01\u0e49\u0e44\u0e02\u0e01\u0e48\u0e2d\u0e19\u0e44\u0e14\u0e49'
                          : 'Save each card separately, or edit it first.',
                      style: const TextStyle(
                        color: Color(0xFF60706C),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        '\u201c${widget.transcript}\u201d',
                        style: const TextStyle(
                          color: Color(0xFF50635D),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (var index = 0; index < total; index++) ...[
                      _VoiceDraftCard(
                        draft: widget.drafts[index],
                        saved: _saved[index],
                        saving: _saving.contains(index),
                        onSave: () => _save(index),
                        onEdit: () => _editAndSave(index),
                      ),
                      if (index < total - 1) const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              if (_savedCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: FilledButton.icon(
                    onPressed: _close,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      thai
                          ? '\u0e40\u0e2a\u0e23\u0e47\u0e08\u0e41\u0e25\u0e49\u0e27 ($_savedCount/$total)'
                          : 'Done ($_savedCount/$total)',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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

class _VoiceDraftCard extends StatelessWidget {
  const _VoiceDraftCard({
    required this.draft,
    required this.saved,
    required this.saving,
    required this.onSave,
    required this.onEdit,
  });

  final VoiceTransactionDraft draft;
  final bool saved;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final thai = context.strings.isThai;
    final accent = categoryAccentColor(draft.categoryId);
    final categoryName = localizedCategoryName(
      strings: context.strings,
      categoryId: draft.categoryId,
      fallbackName: draft.categoryName,
    );
    final note = draft.note?.trim();
    final title = note == null || note.isEmpty ? categoryName : note;
    final typeLabel = switch (draft.type) {
      TransactionType.income =>
        thai ? '\u0e23\u0e32\u0e22\u0e23\u0e31\u0e1a' : 'Income',
      TransactionType.internalTransfer =>
        thai
            ? '\u0e42\u0e2d\u0e19\u0e20\u0e32\u0e22\u0e43\u0e19'
            : 'Internal transfer',
      TransactionType.expense =>
        thai ? '\u0e23\u0e32\u0e22\u0e08\u0e48\u0e32\u0e22' : 'Expense',
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: saved ? const Color(0xFFE8F7EF) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: saved
              ? const Color(0xFF78C6A3)
              : accent.withValues(alpha: 0.22),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12172826),
            blurRadius: 22,
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(categoryIconData(draft.categoryId), color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172826),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$typeLabel \u00b7 $categoryName',
                      style: const TextStyle(
                        color: Color(0xFF697873),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\u0e3f${formatOriginalNumber(draft.amount)}',
                style: TextStyle(
                  color: draft.type.isIncome
                      ? const Color(0xFF1B8F73)
                      : const Color(0xFF172826),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.strings.formatDate(draft.transactionDate),
            style: const TextStyle(
              color: Color(0xFF87948F),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saved || saving ? null : onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(thai ? '\u0e41\u0e01\u0e49\u0e44\u0e02' : 'Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: saved || saving ? null : onSave,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(saved ? Icons.check_rounded : Icons.save_rounded),
                  label: Text(
                    saved
                        ? (thai
                              ? '\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e41\u0e25\u0e49\u0e27'
                              : 'Saved')
                        : (thai
                              ? '\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01'
                              : 'Save'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    disabledBackgroundColor: saved
                        ? const Color(0xFF78C6A3)
                        : const Color(0xFF9DB5AD),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
