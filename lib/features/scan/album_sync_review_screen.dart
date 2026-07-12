import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/category_localization.dart';
import '../transactions/create_transaction_input.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';
import 'external_ai_client.dart';
import 'slip_date_parser.dart';
import 'slip_fingerprint.dart';
import 'slip_scan_result.dart';
import 'slip_text_recognizer.dart';
import 'slip_transaction_resolver.dart';

class AlbumSyncReviewScreen extends StatefulWidget {
  const AlbumSyncReviewScreen({
    required this.user,
    required this.transactionRepository,
    required this.imagePaths,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final List<String> imagePaths;

  @override
  State<AlbumSyncReviewScreen> createState() => _AlbumSyncReviewScreenState();
}

class _AlbumSyncReviewScreenState extends State<AlbumSyncReviewScreen> {
  final _recognizer = SlipTextRecognizer();
  final _items = <_AlbumReviewItem>[];

  bool _isScanning = false;
  bool _isSaving = false;

  DateTime? _fallbackImageDate(String imagePath) {
    try {
      return File(imagePath).lastModifiedSync();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _items
        ..clear()
        ..addAll(
          widget.imagePaths.map(
            (path) => _AlbumReviewItem(
              path: path,
              status: _AlbumReviewStatus.reading,
            ),
          ),
        );
    });

    final activeFingerprints = await widget.transactionRepository
        .loadActiveSlipFingerprints(widget.user.uid);

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      try {
        final result = await _recognizer.scanImagePath(item.path);
        final fingerprint = await buildSlipFingerprint(
          imagePath: item.path,
          result: result,
        );
        final amount = result.amount;
        final decision = await _resolveDecision(result);

        var status = _AlbumReviewStatus.ready;
        if (activeFingerprints.contains(fingerprint)) {
          status = _AlbumReviewStatus.duplicate;
        } else if (amount == null || amount <= 0 || decision == null) {
          status = _AlbumReviewStatus.failed;
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _items[i] = item.copyWith(
            status: status,
            result: result,
            fingerprint: fingerprint,
            amount: amount,
            decision: decision,
          );
        });
      } catch (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _items[i] = item.copyWith(status: _AlbumReviewStatus.failed);
        });
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isScanning = false;
    });
  }

  Future<SlipTransactionDecision?> _resolveDecision(
    SlipScanResult result,
  ) async {
    final localDecision = resolveLocalSlipDecision(result);
    if (localDecision?.type == TransactionType.internalTransfer) {
      return localDecision;
    }

    final aiDecision = await ExternalAiClient.instance.analyzeSlip(
      result: result,
      allowedCategoryIds: kSlipAnalysisCategoryIds,
    );
    if (aiDecision == null) {
      return localDecision;
    }

    if (aiDecision.type == TransactionType.internalTransfer) {
      return SlipTransactionDecision(
        type: TransactionType.internalTransfer,
        categoryId: 'internal_transfer',
        categoryName: 'Internal Transfer',
        note: buildSlipNote(result, overrideNote: aiDecision.note),
      );
    }

    return SlipTransactionDecision(
      type: aiDecision.type,
      categoryId: aiDecision.categoryId,
      categoryName: savedCategoryNameForId(aiDecision.categoryId),
      note: buildSlipNote(result, overrideNote: aiDecision.note),
    );
  }

  Future<void> _saveAll() async {
    if (_isSaving || _isScanning) {
      return;
    }

    final readyItems = _items
        .where(
          (item) =>
              item.status == _AlbumReviewStatus.ready &&
              item.result != null &&
              item.amount != null &&
              item.fingerprint != null &&
              item.decision != null,
        )
        .toList();
    if (readyItems.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    var savedCount = 0;
    for (final item in readyItems) {
      try {
        final decision = item.decision!;
        final transactionDate = parseTransactionDateFrom(
          dateText: item.result!.dateText,
          timeText: item.result!.timeText,
          referenceText: item.result!.reference,
          rawText: item.result!.rawText,
          fallbackDate: _fallbackImageDate(item.path),
        );

        final localizedCategory = localizedCategoryName(
          strings: context.strings,
          categoryId: decision.categoryId,
          fallbackName: decision.categoryName,
        );

        await widget.transactionRepository.createManualTransaction(
          CreateTransactionInput(
            userId: widget.user.uid,
            amount: item.amount!,
            type: decision.type,
            categoryId: decision.categoryId,
            categoryName: localizedCategory,
            transactionDate: transactionDate,
            transactionDateText: context.strings.formatDate(transactionDate),
            source: TransactionSource.gallerySlip,
            note: decision.note,
            slipFingerprint: item.fingerprint,
            slipReference: item.result!.reference,
          ),
        );
        savedCount++;
      } catch (_) {
        // keep going; failed entries remain unsaved
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (savedCount > 0) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.couldNotSaveTransaction)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final readyCount = _items
        .where((item) => item.status == _AlbumReviewStatus.ready)
        .length;
    final duplicateCount = _items
        .where((item) => item.status == _AlbumReviewStatus.duplicate)
        .length;
    final failedCount = _items
        .where((item) => item.status == _AlbumReviewStatus.failed)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(strings.syncAlbumTitle),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MascotTip(
                  message: _isScanning
                      ? strings.readingSlip
                      : (strings.isThai
                            ? 'AI à¸ªà¸£à¸¸à¸›à¸ªà¸¥à¸´à¸›à¸—à¸±à¹‰à¸‡à¸­à¸±à¸¥à¸šà¸±à¸¡à¹à¸¥à¹‰à¸§ à¸à¸”à¸šà¸±à¸™à¸—à¸¶à¸à¹„à¸”à¹‰à¹€à¸¥à¸¢'
                            : 'AI finished scanning this album. You can save all now.'),
                  mood: MascotMood.calm,
                ),
                const SizedBox(height: 16),
                _AlbumSummaryCard(
                  totalCount: _items.length,
                  readyCount: readyCount,
                  duplicateCount: duplicateCount,
                  failedCount: failedCount,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _AlbumResultTile(item: _items[index]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: (_isScanning || _isSaving || readyCount == 0)
                      ? null
                      : _saveAll,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving
                        ? strings.saving
                        : (strings.isThai
                              ? 'à¸šà¸±à¸™à¸—à¸¶à¸à¸—à¸±à¹‰à¸‡à¸«à¸¡à¸”'
                              : 'Save all'),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
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

class _AlbumSummaryCard extends StatelessWidget {
  const _AlbumSummaryCard({
    required this.totalCount,
    required this.readyCount,
    required this.duplicateCount,
    required this.failedCount,
  });

  final int totalCount;
  final int readyCount;
  final int duplicateCount;
  final int failedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x2E5D81AD)),
      ),
      child: Row(
        children: [
          Expanded(child: _SummaryPill(label: 'Total', value: '$totalCount')),
          const SizedBox(width: 8),
          Expanded(child: _SummaryPill(label: 'Ready', value: '$readyCount')),
          const SizedBox(width: 8),
          Expanded(child: _SummaryPill(label: 'Dup', value: '$duplicateCount')),
          const SizedBox(width: 8),
          Expanded(child: _SummaryPill(label: 'Fail', value: '$failedCount')),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF10233F),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF65748B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumResultTile extends StatelessWidget {
  const _AlbumResultTile({required this.item});

  final _AlbumReviewItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (item.status) {
      _AlbumReviewStatus.reading => (
        Icons.document_scanner_rounded,
        const Color(0xFF3268F6),
        context.strings.readingSlip,
      ),
      _AlbumReviewStatus.ready => (
        Icons.check_circle_rounded,
        _decisionColor(item.decision?.type),
        item.decision == null
            ? (context.strings.isThai ? 'à¸žà¸£à¹‰à¸­à¸¡à¸šà¸±à¸™à¸—à¸¶à¸' : 'Ready')
            : localizedCategoryName(
                strings: context.strings,
                categoryId: item.decision!.categoryId,
                fallbackName: item.decision!.categoryName,
              ),
      ),
      _AlbumReviewStatus.duplicate => (
        Icons.remove_circle_rounded,
        const Color(0xFFB8942D),
        context.strings.skippedDuplicateSlip,
      ),
      _AlbumReviewStatus.failed => (
        Icons.error_rounded,
        const Color(0xFFB66A72),
        context.strings.couldNotReadSlip,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(item.path),
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 54,
                height: 54,
                color: const Color(0xFFE7EDF4),
                child: const Icon(Icons.image_not_supported_rounded),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.path.split(Platform.pathSeparator).last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF10233F),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.amount == null
                      ? label
                      : '${item.result?.bankDisplayName ?? 'Slip'}  •  ${item.amount!.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF65748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _decisionColor(TransactionType? type) {
  return switch (type) {
    TransactionType.income => const Color(0xFF1B8F73),
    TransactionType.expense => const Color(0xFFD94768),
    TransactionType.internalTransfer => const Color(0xFF168AA6),
    null => const Color(0xFF1B8F73),
  };
}

enum _AlbumReviewStatus { reading, ready, duplicate, failed }

class _AlbumReviewItem {
  const _AlbumReviewItem({
    required this.path,
    required this.status,
    this.result,
    this.fingerprint,
    this.amount,
    this.decision,
  });

  final String path;
  final _AlbumReviewStatus status;
  final SlipScanResult? result;
  final String? fingerprint;
  final double? amount;
  final SlipTransactionDecision? decision;

  _AlbumReviewItem copyWith({
    _AlbumReviewStatus? status,
    SlipScanResult? result,
    String? fingerprint,
    double? amount,
    SlipTransactionDecision? decision,
  }) {
    return _AlbumReviewItem(
      path: path,
      status: status ?? this.status,
      result: result ?? this.result,
      fingerprint: fingerprint ?? this.fingerprint,
      amount: amount ?? this.amount,
      decision: decision ?? this.decision,
    );
  }
}
