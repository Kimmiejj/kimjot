import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/formatters/money_formatter.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/category_localization.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_type.dart';
import 'album_sync_ai_analyzer.dart';
import 'album_sync_background_service.dart';
import 'album_sync_job_actions.dart';
import 'slip_fingerprint.dart';
import 'slip_scan_result.dart';
import 'slip_text_recognizer.dart';
import 'slip_transaction_resolver.dart';

class AlbumSyncReviewScreen extends StatefulWidget {
  const AlbumSyncReviewScreen({
    required this.user,
    required this.transactionRepository,
    required this.imagePaths,
    this.scanImagePath,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final List<String> imagePaths;
  final Future<SlipScanResult> Function(String imagePath)? scanImagePath;

  @override
  State<AlbumSyncReviewScreen> createState() => _AlbumSyncReviewScreenState();
}

class _AlbumSyncReviewScreenState extends State<AlbumSyncReviewScreen> {
  final _recognizer = SlipTextRecognizer();
  final _items = <_AlbumReviewItem>[];
  StreamSubscription<AlbumSyncJobSnapshot>? _jobSubscription;

  bool _isScanning = false;
  bool _isSaving = false;
  bool _isCancelling = false;
  bool _cancelRequested = false;
  bool _wasCancelled = false;

  @override
  void initState() {
    super.initState();
    if (widget.scanImagePath == null &&
        (Platform.isAndroid || Platform.isIOS)) {
      _jobSubscription = AlbumSyncBackgroundService.jobUpdates.listen(
        _applyBackgroundSnapshot,
        onError: (_) {},
      );
    }
    _startScan();
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _recognizer.close();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (widget.scanImagePath == null) {
      await _startBackgroundScan();
      return;
    }

    await _startLocalScan();
  }

  Future<void> _startBackgroundScan() async {
    if (_isScanning) {
      return;
    }

    final existingSnapshot = await AlbumSyncBackgroundService.loadJob();
    if (existingSnapshot != null &&
        existingSnapshot.userId == widget.user.uid &&
        (widget.imagePaths.isEmpty ||
            _sameImagePaths(existingSnapshot.imagePaths, widget.imagePaths))) {
      _applyBackgroundSnapshot(existingSnapshot);
      if (existingSnapshot.items.isNotEmpty) {
        return;
      }
    }

    if (widget.imagePaths.isEmpty) {
      return;
    }

    setState(() {
      _isScanning = true;
      _cancelRequested = false;
      _wasCancelled = false;
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
    final snapshot = await AlbumSyncBackgroundService.requestStart(
      userId: widget.user.uid,
      imagePaths: widget.imagePaths,
      activeFingerprints: activeFingerprints,
    );

    if (!mounted) {
      return;
    }

    _applyBackgroundSnapshot(snapshot);
  }

  Future<void> _startLocalScan() async {
    if (_isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _cancelRequested = false;
      _wasCancelled = false;
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
    if (_cancelRequested) {
      return;
    }

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      try {
        final scanImagePath = widget.scanImagePath;
        final scannedResult = await (scanImagePath == null
            ? _recognizer.scanImagePath(item.path)
            : scanImagePath(item.path));
        if (_cancelRequested || !mounted) {
          return;
        }
        final analysis = await analyzeAlbumSyncSlip(
          result: scannedResult,
          imagePath: item.path,
        );
        if (_cancelRequested || !mounted) {
          return;
        }
        final result = analysis.result;
        final fingerprint = await buildSlipFingerprint(
          imagePath: item.path,
          result: result,
        );
        if (_cancelRequested || !mounted) {
          return;
        }
        final amount = result.amount;
        final decision = analysis.decision;

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
      } catch (error, stackTrace) {
        debugPrint('Album sync failed for ${item.path}: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (_cancelRequested) {
          return;
        }
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

  Future<void> _cancelSync() async {
    if (!_isScanning || _isCancelling) {
      return;
    }

    setState(() {
      _cancelRequested = true;
      _isCancelling = true;
      _isScanning = false;
      _wasCancelled = true;
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].status == _AlbumReviewStatus.reading) {
          _items[i] = _items[i].copyWith(
            status: _AlbumReviewStatus.cancelled,
          );
        }
      }
    });

    if (widget.scanImagePath == null) {
      final snapshot = await AlbumSyncBackgroundService.requestCancel();
      if (snapshot != null && mounted) {
        _applyBackgroundSnapshot(snapshot);
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isCancelling = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.albumSyncCancelled)));
  }

  void _applyBackgroundSnapshot(AlbumSyncJobSnapshot snapshot) {
    if (!mounted || snapshot.userId != widget.user.uid) {
      return;
    }

    if (widget.imagePaths.isNotEmpty &&
        !_sameImagePaths(snapshot.imagePaths, widget.imagePaths)) {
      return;
    }

    setState(() {
      _isScanning = snapshot.isScanning;
      _wasCancelled = snapshot.state == AlbumSyncJobState.cancelled;
      _items
        ..clear()
        ..addAll(snapshot.items.map(_itemFromBackgroundSnapshot));
    });
  }

  bool _sameImagePaths(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  _AlbumReviewItem _itemFromBackgroundSnapshot(AlbumSyncItemSnapshot item) {
    var decision = item.decision;
    final result = item.result;
    if (result != null) {
      final localDecision = resolveBestEffortSlipDecision(result);
      if (localDecision?.type == TransactionType.internalTransfer) {
        decision = localDecision;
      }
    }
    return _AlbumReviewItem(
      path: item.path,
      status: switch (item.status) {
        AlbumSyncItemStatus.reading => _AlbumReviewStatus.reading,
        AlbumSyncItemStatus.ready => _AlbumReviewStatus.ready,
        AlbumSyncItemStatus.duplicate => _AlbumReviewStatus.duplicate,
        AlbumSyncItemStatus.failed => _AlbumReviewStatus.failed,
        AlbumSyncItemStatus.cancelled => _AlbumReviewStatus.cancelled,
      },
      result: item.result,
      fingerprint: item.fingerprint,
      amount: item.amount,
      decision: decision,
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

    final savedCount = await saveAlbumSyncItems(
      user: widget.user,
      transactionRepository: widget.transactionRepository,
      strings: context.strings,
      items: readyItems.map(
        (item) => AlbumSyncItemSnapshot(
          path: item.path,
          status: AlbumSyncItemStatus.ready,
          result: item.result,
          fingerprint: item.fingerprint,
          amount: item.amount,
          decision: item.decision,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (savedCount > 0) {
      await AlbumSyncBackgroundService.clearFinishedJob();
      if (!mounted) {
        return;
      }
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
    final cancelledCount = _items
        .where((item) => item.status == _AlbumReviewStatus.cancelled)
        .length;
    final completedCount =
        readyCount + duplicateCount + failedCount + cancelledCount;

    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(strings.syncAlbumTitle),
        leading: const BackButton(),
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
                      : _wasCancelled
                      ? strings.albumSyncCancelled
                      : strings.isThai
                      ? '\u0E2A\u0E41\u0E01\u0E19\u0E2D\u0E31\u0E25\u0E1A\u0E31\u0E49\u0E21\u0E40\u0E2A\u0E23\u0E47\u0E08\u0E41\u0E25\u0E49\u0E27 \u0E01\u0E14\u0E1A\u0E31\u0E19\u0E17\u0E36\u0E01\u0E17\u0E31\u0E49\u0E07\u0E2B\u0E21\u0E14\u0E44\u0E14\u0E49\u0E40\u0E25\u0E22'
                      : 'Album scan complete. Review it or save everything now.',
                  mood: MascotMood.calm,
                ),
                const SizedBox(height: 16),
                _AlbumSummaryCard(
                  totalCount: _items.length,
                  completedCount: completedCount,
                  readyCount: readyCount,
                  duplicateCount: duplicateCount,
                  failedCount: failedCount,
                  cancelledCount: cancelledCount,
                  isScanning: _isScanning,
                  wasCancelled: _wasCancelled,
                ),
                if (_isScanning) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isCancelling ? null : _cancelSync,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(strings.cancelAlbumSync),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD94768),
                      side: const BorderSide(color: Color(0xFFD94768)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ],
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
                _SaveAllButton(
                  isSaving: _isSaving,
                  readyCount: readyCount,
                  onPressed: (_isScanning || _isSaving || readyCount == 0)
                      ? null
                      : _saveAll,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveAllButton extends StatelessWidget {
  const _SaveAllButton({
    required this.isSaving,
    required this.readyCount,
    required this.onPressed,
  });

  final bool isSaving;
  final int readyCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final enabled = onPressed != null;
    final label = isSaving
        ? strings.saving
        : strings.isThai
        ? 'บันทึกทั้งหมด'
        : 'Save all';
    final countLabel = readyCount > 0 ? '$readyCount' : '0';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                colors: [Color(0xFF1FC9DC), Color(0xFF3268F6)],
              )
            : null,
        color: enabled ? null : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: enabled
              ? Colors.white.withValues(alpha: 0.82)
              : const Color(0x2E5D81AD),
        ),
        boxShadow: enabled
            ? const [
                BoxShadow(
                  color: Color(0x3D1FC9DC),
                  blurRadius: 32,
                  offset: Offset(0, 16),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(21),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 22,
                  child: Center(
                    child: isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.save_alt_rounded,
                            color: enabled
                                ? Colors.white
                                : const Color(0xFF65748B),
                            size: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? Colors.white : const Color(0xFF65748B),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 30,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: enabled
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFFE7EDF4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    countLabel,
                    style: TextStyle(
                      color: enabled ? Colors.white : const Color(0xFF65748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
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
    required this.completedCount,
    required this.readyCount,
    required this.duplicateCount,
    required this.failedCount,
    required this.cancelledCount,
    required this.isScanning,
    required this.wasCancelled,
  });

  final int totalCount;
  final int completedCount;
  final int readyCount;
  final int duplicateCount;
  final int failedCount;
  final int cancelledCount;
  final bool isScanning;
  final bool wasCancelled;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0
        ? 0.0
        : (completedCount / totalCount).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x2E5D81AD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                isScanning
                    ? (context.strings.isThai
                          ? '\u0E01\u0E33\u0E25\u0E31\u0E07\u0E2D\u0E48\u0E32\u0E19\u0E2A\u0E25\u0E34\u0E1B'
                          : 'Reading slips')
                    : wasCancelled
                    ? context.strings.albumSyncCancelled
                    : (context.strings.isThai
                          ? '\u0E2D\u0E48\u0E32\u0E19\u0E40\u0E2A\u0E23\u0E47\u0E08\u0E41\u0E25\u0E49\u0E27'
                          : 'Scan complete'),
                style: const TextStyle(
                  color: Color(0xFF10233F),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFE6EDF2),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF28B78D)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(label: 'Total', value: '$totalCount'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryPill(
                  label: 'Ready',
                  value: '$readyCount',
                  tint: const Color(0xFFEAF8F1),
                  valueColor: const Color(0xFF1B8F73),
                  labelColor: const Color(0xFF1B8F73),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryPill(
                  label: 'Dup',
                  value: '$duplicateCount',
                  tint: const Color(0xFFFFF6DD),
                  valueColor: const Color(0xFFB8942D),
                  labelColor: const Color(0xFFB8942D),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryPill(
                  label: cancelledCount > 0 ? 'Stop' : 'Fail',
                  value: cancelledCount > 0
                      ? '$cancelledCount'
                      : '$failedCount',
                  tint: const Color(0xFFFFEFF1),
                  valueColor: const Color(0xFFD94768),
                  labelColor: const Color(0xFFD94768),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    this.tint = const Color(0xFFF4FBFF),
    this.valueColor = const Color(0xFF10233F),
    this.labelColor = const Color(0xFF65748B),
  });

  final String label;
  final String value;
  final Color tint;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
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
    final categoryLabel = item.decision == null
        ? null
        : localizedCategoryName(
            strings: context.strings,
            categoryId: item.decision!.categoryId,
            fallbackName: item.decision!.categoryName,
          );
    final (icon, color, label, chipTint) = switch (item.status) {
      _AlbumReviewStatus.reading => (
        Icons.document_scanner_rounded,
        const Color(0xFF3268F6),
        context.strings.readingSlip,
        const Color(0xFFEAF1FF),
      ),
      _AlbumReviewStatus.ready => (
        Icons.check_circle_rounded,
        const Color(0xFF1B8F73),
        'Done',
        const Color(0xFFEAF8F1),
      ),
      _AlbumReviewStatus.duplicate => (
        Icons.remove_circle_rounded,
        const Color(0xFFB8942D),
        'Dup',
        const Color(0xFFFFF6DD),
      ),
      _AlbumReviewStatus.failed => (
        Icons.error_rounded,
        const Color(0xFFD94768),
        'Fail',
        const Color(0xFFFFEFF1),
      ),
      _AlbumReviewStatus.cancelled => (
        Icons.stop_circle_rounded,
        const Color(0xFFD94768),
        context.strings.isThai
            ? '\u0E22\u0E01\u0E40\u0E25\u0E34\u0E01'
            : 'Stopped',
        const Color(0xFFFFEFF1),
      ),
    };
    final detailText = item.amount == null
        ? switch (item.status) {
            _AlbumReviewStatus.reading => context.strings.readingSlip,
            _AlbumReviewStatus.ready => categoryLabel ?? 'Done',
            _AlbumReviewStatus.duplicate =>
              context.strings.skippedDuplicateSlip,
            _AlbumReviewStatus.failed => context.strings.couldNotReadSlip,
            _AlbumReviewStatus.cancelled =>
              context.strings.albumSyncCancelled,
          }
        : '${item.result?.bankDisplayName ?? 'Slip'}  •  ${formatOriginalNumber(item.amount!)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x245D81AD)),
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EDF4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Icon(icon, color: color, size: 22)),
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
                  detailText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF65748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                if (categoryLabel != null &&
                    item.status == _AlbumReviewStatus.ready) ...[
                  const SizedBox(height: 4),
                  Text(
                    categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF10233F),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: chipTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
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

enum _AlbumReviewStatus { reading, ready, duplicate, failed, cancelled }

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
