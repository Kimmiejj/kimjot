import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/create_transaction_input.dart';
import '../transactions/manual_transaction_sheet.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';
import 'slip_fingerprint.dart';
import 'slip_scan_result.dart';
import 'slip_text_recognizer.dart';

class SlipReviewScreen extends StatefulWidget {
  const SlipReviewScreen({
    required this.user,
    required this.transactionRepository,
    this.imagePath,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final String? imagePath;

  @override
  State<SlipReviewScreen> createState() => _SlipReviewScreenState();
}

class _SlipReviewScreenState extends State<SlipReviewScreen> {
  final _recognizer = SlipTextRecognizer();

  SlipScanResult? _scanResult;
  String? _slipFingerprint;
  bool _isReading = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    final imagePath = widget.imagePath;
    if (imagePath != null) {
      _scanSlip(imagePath);
    }
  }

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  Future<void> _scanSlip(String imagePath) async {
    setState(() {
      _isReading = true;
      _scanError = null;
    });

    try {
      final result = await _recognizer.scanImagePath(imagePath);
      final fingerprint = await buildSlipFingerprint(
        imagePath: imagePath,
        result: result,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _scanResult = result;
        _slipFingerprint = fingerprint;
        _isReading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _scanError = context.strings.noSlipDataFound;
        _isReading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scanResult = _scanResult;

    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(strings.slipReview),
        elevation: 0,
      ),
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
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MascotTip(
                  message: strings.slipReviewTip,
                  mood: MascotMood.calm,
                ),
                if (widget.imagePath != null) ...[
                  const SizedBox(height: 14),
                  _SlipImagePreview(imagePath: widget.imagePath!),
                  const SizedBox(height: 14),
                ],
                if (_isReading) ...[
                  _ReadingCard(message: strings.readingSlip),
                  const SizedBox(height: 14),
                ] else if (scanResult != null) ...[
                  _SlipSummaryCard(result: scanResult),
                  const SizedBox(height: 14),
                  if (scanResult.amountConfidence != null &&
                      scanResult.amountConfidence! > 0.85)
                    _HighConfidenceCard(
                      amount: scanResult.amount,
                      confidence: scanResult.amountConfidence!,
                      onAutoAccept: () => _autoAcceptTransaction(scanResult),
                    ),
                  if (scanResult.amountConfidence != null &&
                      scanResult.amountConfidence! > 0.85)
                    const SizedBox(height: 14),
                ] else if (_scanError != null) ...[
                  _ReadingCard(message: _scanError!),
                  const SizedBox(height: 14),
                ],
                ManualTransactionForm(
                  user: widget.user,
                  transactionRepository: widget.transactionRepository,
                  source: TransactionSource.gallerySlip,
                  title: strings.reviewSlip,
                  description: strings.slipReviewDescription,
                  initialType: TransactionType.expense,
                  initialAmount: scanResult?.amount,
                  initialNote: _noteFromScan(scanResult),
                  slipFingerprint: _slipFingerprint,
                  slipReference: scanResult?.reference,
                  onSaved: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _noteFromScan(SlipScanResult? result) {
    if (result == null) {
      return null;
    }

    final values = [
      result.bankName,
      result.recipient,
      result.reference,
    ].whereType<String>().where((value) => value.trim().isNotEmpty);
    final note = values.join(' / ');
    return note.isEmpty ? null : note;
  }

  Future<void> _autoAcceptTransaction(SlipScanResult result) async {
    if (!mounted || widget.imagePath == null) return;
    final fingerprint = await buildSlipFingerprint(
      imagePath: widget.imagePath!,
      result: result,
    );
    if (!mounted) return;
    try {
      await widget.transactionRepository.createManualTransaction(
        CreateTransactionInput(
          userId: widget.user.uid,
          amount: result.amount ?? 0,
          type: result.category == SlipCategory.income
              ? TransactionType.income
              : TransactionType.expense,
          categoryId: 'transfer',
          categoryName: 'Transfer',
          transactionDate: DateTime.now(),
          source: TransactionSource.gallerySlip,
          note: _noteFromScan(result),
          slipFingerprint: fingerprint,
          slipReference: result.reference,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.couldNotSaveTransaction)),
        );
      }
    }
  }
}

class _SlipImagePreview extends StatelessWidget {
  const _SlipImagePreview({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.file(
        File(imagePath),
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 120,
            color: Colors.white.withValues(alpha: 0.78),
            alignment: Alignment.center,
            child: Icon(
              Icons.image_not_supported_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _summaryDecoration(),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: _summaryValueStyle)),
        ],
      ),
    );
  }
}

class _SlipSummaryCard extends StatelessWidget {
  const _SlipSummaryCard({required this.result});

  final SlipScanResult result;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final amount = result.amount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _summaryDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.slipSummary, style: _summaryTitleStyle),
          const SizedBox(height: 12),
          _SummaryRow(label: strings.bank, value: result.bankDisplayName),
          if (amount != null)
            _SummaryRow(
              label: strings.amount,
              value: '${strings.amountPrefix}${_formatMoneyValue(amount)}',
            ),
          if (result.dateText != null)
            _SummaryRow(label: strings.date, value: result.dateText!),
          if (result.timeText != null)
            _SummaryRow(label: strings.time, value: result.timeText!),
          if (result.recipient != null)
            _SummaryRow(label: strings.recipient, value: result.recipient!),
          if (result.sender != null)
            _SummaryRow(label: strings.sender, value: result.sender!),
          if (result.reference != null)
            _SummaryRow(label: strings.reference, value: result.reference!),
          if (!result.hasUsefulData)
            Text(strings.noSlipDataFound, style: _summaryValueStyle),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 94, child: Text(label, style: _summaryLabelStyle)),
          Expanded(child: Text(value, style: _summaryValueStyle)),
        ],
      ),
    );
  }
}

BoxDecoration _summaryDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.82),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0x2E5D81AD)),
  );
}

String _formatMoneyValue(double amount) {
  return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
}

const _summaryTitleStyle = TextStyle(
  color: Color(0xFF071844),
  fontSize: 18,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _summaryLabelStyle = TextStyle(
  color: Color(0xFF65748B),
  fontSize: 13,
  fontWeight: FontWeight.w800,
  letterSpacing: 0,
);

const _summaryValueStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 14,
  fontWeight: FontWeight.w800,
  height: 1.35,
  letterSpacing: 0,
);

class _HighConfidenceCard extends StatelessWidget {
  const _HighConfidenceCard({
    required this.amount,
    required this.confidence,
    required this.onAutoAccept,
  });

  final double? amount;
  final double confidence;
  final VoidCallback onAutoAccept;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final confidencePercent = (confidence * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.isThai ? 'AI มั่นใจสูง' : 'High Confidence',
            style: const TextStyle(
              color: Color(0xFF1B8F73),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.isThai
                ? 'ระบบอ่านสลิปได้ $confidencePercent% — สามารถบันทึกอัตโนมัติได้'
                : 'AI detected amount with $confidencePercent% confidence — auto-save available',
            style: const TextStyle(
              color: Color(0xFF10233F),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAutoAccept,
            icon: const Icon(Icons.check_rounded),
            label: Text(strings.isThai ? 'ยอมรับ & บันทึก' : 'Accept & Save'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
