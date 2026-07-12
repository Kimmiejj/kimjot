import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/category_localization.dart';
import '../transactions/create_transaction_input.dart';
import '../transactions/manual_transaction_sheet.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';
import 'slip_date_parser.dart';
import 'slip_fingerprint.dart';
import 'slip_scan_result.dart';
import 'slip_text_recognizer.dart';
import 'slip_transaction_resolver.dart';

class SlipReviewScreen extends StatefulWidget {
  const SlipReviewScreen({
    required this.user,
    required this.transactionRepository,
    this.imagePath,
    this.imagePaths,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final String? imagePath;
  final List<String>? imagePaths;

  @override
  State<SlipReviewScreen> createState() => _SlipReviewScreenState();
}

class _SlipReviewScreenState extends State<SlipReviewScreen> {
  final _recognizer = SlipTextRecognizer();

  int _currentIndex = 0;
  SlipScanResult? _scanResult;
  String? _slipFingerprint;
  bool _isReading = false;
  String? _scanError;

  List<String> get _imagePaths {
    final imagePaths = widget.imagePaths;
    if (imagePaths != null && imagePaths.isNotEmpty) {
      return imagePaths;
    }

    final imagePath = widget.imagePath;
    return imagePath == null ? const [] : [imagePath];
  }

  String? get _currentImagePath {
    final paths = _imagePaths;
    if (paths.isEmpty || _currentIndex < 0 || _currentIndex >= paths.length) {
      return null;
    }
    return paths[_currentIndex];
  }

  bool get _hasMultipleImages => _imagePaths.length > 1;

  @override
  void initState() {
    super.initState();
    final imagePath = _currentImagePath;
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
      _scanResult = null;
      _slipFingerprint = null;
      _isReading = true;
      _scanError = null;
    });

    try {
      final result = await _recognizer.scanImagePath(imagePath);
      final fingerprint = await buildSlipFingerprint(
        imagePath: imagePath,
        result: result,
      );
      if (!mounted) return;

      setState(() {
        _scanResult = result;
        _slipFingerprint = fingerprint;
        _isReading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _scanError = context.strings.noSlipDataFound;
        _isReading = false;
      });
    }
  }

  Future<void> _moveToImage(int index) async {
    if (index < 0 || index >= _imagePaths.length || index == _currentIndex) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
    final imagePath = _currentImagePath;
    if (imagePath != null) await _scanSlip(imagePath);
  }

  Future<void> _handleSaved() async {
    if (_currentIndex < _imagePaths.length - 1) {
      await _moveToImage(_currentIndex + 1);
      return;
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  DateTime? _fallbackImageDate(String? imagePath) {
    if (imagePath == null) {
      return null;
    }

    try {
      return File(imagePath).lastModifiedSync();
    } catch (_) {
      return null;
    }
  }

  Future<void> _autoAcceptTransaction(SlipScanResult result) async {
    final imagePath = _currentImagePath;
    if (!mounted || imagePath == null) return;
    final fingerprint = await buildSlipFingerprint(
      imagePath: imagePath,
      result: result,
    );
    if (!mounted) return;

    final decision = resolveLocalSlipDecision(result);
    if (decision == null) {
      return;
    }

    try {
      final transactionDate = parseTransactionDateFrom(
        dateText: result.dateText,
        timeText: result.timeText,
        referenceText: result.reference,
        rawText: result.rawText,
        fallbackDate: _fallbackImageDate(imagePath),
      );

      final localizedCategory = localizedCategoryName(
        strings: context.strings,
        categoryId: decision.categoryId,
        fallbackName: decision.categoryName,
      );

      await widget.transactionRepository.createManualTransaction(
        CreateTransactionInput(
          userId: widget.user.uid,
          amount: result.amount ?? 0,
          type: decision.type,
          categoryId: decision.categoryId,
          categoryName: localizedCategory,
          transactionDate: transactionDate,
          transactionDateText: context.strings.formatDate(transactionDate),
          source: TransactionSource.gallerySlip,
          note: decision.note,
          slipFingerprint: fingerprint,
          slipReference: result.reference,
        ),
      );

      if (mounted) await _handleSaved();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.couldNotSaveTransaction)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scanResult = _scanResult;
    final currentImagePath = _currentImagePath;
    final decision = scanResult == null
        ? null
        : resolveLocalSlipDecision(scanResult);

    final parsedDate = parseTransactionDateFrom(
      dateText: scanResult?.dateText,
      timeText: scanResult?.timeText,
      referenceText: scanResult?.reference,
      rawText: scanResult?.rawText,
      fallbackDate: _fallbackImageDate(currentImagePath),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          _hasMultipleImages
              ? '${strings.slipReview} ${_currentIndex + 1}/${_imagePaths.length}'
              : strings.slipReview,
        ),
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
                MascotTip(message: strings.slipReviewTip, mood: MascotMood.calm),
                if (currentImagePath != null) ...[
                  const SizedBox(height: 14),
                  _SlipImagePreview(imagePath: currentImagePath),
                  const SizedBox(height: 14),
                ],
                if (_hasMultipleImages) ...[
                  _ReviewQueueCard(
                    currentIndex: _currentIndex,
                    totalCount: _imagePaths.length,
                    onPrevious: _currentIndex > 0
                        ? () => _moveToImage(_currentIndex - 1)
                        : null,
                    onNext: _currentIndex < _imagePaths.length - 1
                        ? () => _moveToImage(_currentIndex + 1)
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_isReading) ...[
                  _ReadingCard(message: strings.readingSlip),
                  const SizedBox(height: 14),
                ] else if (scanResult != null) ...[
                  _SlipSummaryCard(result: scanResult),
                  const SizedBox(height: 14),
                  if (scanResult.amountConfidence != null &&
                      scanResult.amountConfidence! > 0.85 &&
                      decision != null)
                    _HighConfidenceCard(
                      amount: scanResult.amount,
                      confidence: scanResult.amountConfidence!,
                      onAutoAccept: () => _autoAcceptTransaction(scanResult),
                    ),
                  if (scanResult.amountConfidence != null &&
                      scanResult.amountConfidence! > 0.85 &&
                      decision != null)
                    const SizedBox(height: 14),
                ] else if (_scanError != null) ...[
                  _ReadingCard(message: _scanError!),
                  const SizedBox(height: 14),
                ],
                ManualTransactionForm(
                  key: ValueKey(currentImagePath),
                  user: widget.user,
                  transactionRepository: widget.transactionRepository,
                  source: TransactionSource.gallerySlip,
                  title: strings.reviewSlip,
                  description: strings.slipReviewDescription,
                  initialType: decision?.type ?? TransactionType.expense,
                  initialAmount: scanResult?.amount,
                  initialNote: scanResult == null
                      ? null
                      : (decision?.note ?? buildSlipNote(scanResult)),
                  initialDate: parsedDate,
                  initialDateText: context.strings.formatDate(parsedDate),
                  slipFingerprint: _slipFingerprint,
                  slipReference: scanResult?.reference,
                  onSaved: _handleSaved,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewQueueCard extends StatelessWidget {
  const _ReviewQueueCard({
    required this.currentIndex,
    required this.totalCount,
    this.onPrevious,
    this.onNext,
  });

  final int currentIndex;
  final int totalCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _summaryDecoration(),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: strings.previousMonth,
          ),
          Expanded(
            child: Text(
              strings.isThai
                  ? 'à¸ªà¸¥à¸´à¸› ${currentIndex + 1} à¸ˆà¸²à¸ $totalCount'
                  : 'Slip ${currentIndex + 1} of $totalCount',
              textAlign: TextAlign.center,
              style: _summaryValueStyle,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: strings.nextMonth,
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: _summaryValueStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: _summaryValueStyle)),
        ],
      ),
    );
  }
}

BoxDecoration _summaryDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

const TextStyle _summaryValueStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 14,
  fontWeight: FontWeight.w800,
  height: 1.35,
  letterSpacing: 0,
);

const TextStyle _summaryTitleStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 16,
  fontWeight: FontWeight.w900,
);

String _formatMoneyValue(double value) {
  return value.toStringAsFixed(2);
}

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
            strings.isThai ? 'AI à¸¡à¸±à¹ˆà¸™à¹ƒà¸ˆà¸ªà¸¹à¸‡' : 'High Confidence',
            style: const TextStyle(
              color: Color(0xFF1B8F73),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.isThai
                ? 'à¸£à¸°à¸šà¸šà¸­à¹ˆà¸²à¸™à¸ªà¸¥à¸´à¸›à¹„à¸”à¹‰ $confidencePercent% â€” à¸ªà¸²à¸¡à¸²à¸£à¸–à¸šà¸±à¸™à¸—à¸¶à¸à¸­à¸±à¸•à¹‚à¸™à¸¡à¸±à¸•à¸´à¹„à¸”à¹‰'
                : 'AI detected amount with $confidencePercent% confidence â€” auto-save available',
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
            label: Text(
              strings.isThai ? 'à¸¢à¸­à¸¡à¸£à¸±à¸š & à¸šà¸±à¸™à¸—à¸¶à¸' : 'Accept & Save',
            ),
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
