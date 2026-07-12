import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../auth/auth_user.dart';
import '../transactions/create_transaction_input.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';
import 'slip_fingerprint.dart';
import 'slip_scan_result.dart';
import 'slip_review_screen.dart';
import 'slip_text_recognizer.dart';
import 'slip_amount_classifier.dart';

class ScanHubScreen extends StatefulWidget {
  const ScanHubScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  @override
  State<ScanHubScreen> createState() => _ScanHubScreenState();
}

class _ScanHubScreenState extends State<ScanHubScreen> {
  static const _galleryPermissionChannel = MethodChannel(
    'kimjod/gallery_permission',
  );

  final _recognizer = SlipTextRecognizer();
  final _selectedImages = <XFile>[];
  final _statusByPath = <String, _SlipSyncStatus>{};

  bool _isSyncing = false;

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  Future<void> _openSlipReview(
    BuildContext context, {
    required String imagePath,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SlipReviewScreen(
          user: widget.user,
          transactionRepository: widget.transactionRepository,
          imagePath: imagePath,
        ),
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.transactionSaved)));
    }
  }

  Future<void> _pickSlipFromGallery(BuildContext context) async {
    final hasPermission = await _requestGalleryPermission(context);
    if (!hasPermission || !context.mounted) {
      return;
    }

    XFile? image;

    try {
      final picker = ImagePicker();
      image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 96,
      );
    } on PlatformException {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.galleryPermissionDenied)),
      );
      return;
    }

    if (image == null || !context.mounted) {
      return;
    }

    await _openSlipReview(context, imagePath: image.path);
  }

  Future<void> _pickAlbumImages(BuildContext context) async {
    final hasPermission = await _requestGalleryPermission(context);
    if (!hasPermission || !context.mounted) {
      return;
    }

    try {
      final imagePaths = await _galleryPermissionChannel
          .invokeMethod<List<dynamic>>('pickImageFolder');
      final images = (imagePaths ?? const [])
          .whereType<String>()
          .map((path) => XFile(path))
          .toList();
      if (images.isEmpty || !context.mounted) {
        return;
      }

      setState(() {
        _selectedImages
          ..clear()
          ..addAll(images);
        _statusByPath
          ..clear()
          ..addEntries(
            images.map(
              (image) => MapEntry(image.path, _SlipSyncStatus.pending),
            ),
          );
      });
    } on PlatformException {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.galleryPermissionDenied)),
      );
    }
  }

  Future<void> _syncSelectedAlbum(BuildContext context) async {
    if (_selectedImages.isEmpty || _isSyncing) {
      return;
    }

    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSyncing = true;
    });

    var added = 0;
    var skipped = 0;
    var failed = 0;
    final activeFingerprints = await widget.transactionRepository
        .loadActiveSlipFingerprints(widget.user.uid);

    for (final image in _selectedImages) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusByPath[image.path] = _SlipSyncStatus.reading;
      });

      try {
        final result = await _recognizer.scanImagePath(image.path);
        final fingerprint = await buildSlipFingerprint(
          imagePath: image.path,
          result: result,
        );

        if (activeFingerprints.contains(fingerprint)) {
          skipped++;
          if (!mounted) {
            return;
          }

          setState(() {
            _statusByPath[image.path] = _SlipSyncStatus.duplicate;
          });
          continue;
        }

        final amount = result.amount;

        // If there's no amount or amount invalid, treat as failed
        if (amount == null || amount <= 0) {
          failed++;
          if (!mounted) {
            return;
          }

          setState(() {
            _statusByPath[image.path] = _SlipSyncStatus.failed;
          });
          continue;
        }

        // Use the detected category (income/expense). If unknown or detail, fall back to heuristics.
        TransactionType txType;
        if (result.category == SlipCategory.income) {
          txType = TransactionType.income;
        } else if (result.category == SlipCategory.expense) {
          txType = TransactionType.expense;
        } else {
          // Fallback: if it looks like a payment slip, treat as expense, otherwise skip
          if (!_looksLikePaymentSlip(result)) {
            failed++;
            if (!mounted) return;

            setState(() {
              _statusByPath[image.path] = _SlipSyncStatus.failed;
            });
            continue;
          }
          txType = TransactionType.expense;
        }

        await widget.transactionRepository.createManualTransaction(
          CreateTransactionInput(
            userId: widget.user.uid,
            amount: amount,
            type: txType,
            categoryId: 'transfer',
            categoryName: 'Transfer',
            transactionDate: DateTime.now(),
            source: TransactionSource.gallerySlip,
            note: _noteFromScan(result),
            slipFingerprint: fingerprint,
            slipReference: result.reference,
          ),
        );

        activeFingerprints.add(fingerprint);
        added++;
        if (!mounted) {
          return;
        }

        setState(() {
          _statusByPath[image.path] = _SlipSyncStatus.added;
        });
      } catch (_) {
        failed++;
        if (!mounted) {
          return;
        }

        setState(() {
          _statusByPath[image.path] = _SlipSyncStatus.failed;
        });
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSyncing = false;
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          strings.albumSyncComplete(
            added: added,
            skipped: skipped,
            failed: failed,
          ),
        ),
      ),
    );
  }

  Future<bool> _requestGalleryPermission(BuildContext context) async {
    try {
      final granted = await _galleryPermissionChannel.invokeMethod<bool>(
        'requestGalleryAccess',
      );

      if (granted == true) {
        return true;
      }
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.galleryPermissionDenied)),
    );
    return false;
  }

  String? _noteFromScan(SlipScanResult result) {
    final values = [
      result.bankName,
      result.recipient,
      result.reference,
    ].whereType<String>().where((value) => value.trim().isNotEmpty);
    final note = values.join(' / ');
    return note.isEmpty ? null : note;
  }

  bool _looksLikePaymentSlip(SlipScanResult result) {
    final text = result.rawText.toLowerCase();
    return result.bankName != null ||
        result.reference != null ||
        text.contains('k plus') ||
        text.contains('scb') ||
        text.contains('transfer') ||
        text.contains('payment') ||
        text.contains('transaction') ||
        text.contains('โอน') ||
        text.contains('ชำระ') ||
        text.contains('พร้อมเพย์') ||
        text.contains('เลขที่') ||
        text.contains('อ้างอิง') ||
        text.contains('จำนวนเงิน');
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(strings.scanHub),
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
                const SizedBox(height: 12),
                MascotTip(message: strings.scanHubTip, mood: MascotMood.calm),
                const SizedBox(height: 16),
                _ScanOption(
                  icon: Icons.photo_library_rounded,
                  title: strings.importFromGallery,
                  subtitle: strings.chooseSlipFromGallery,
                  onTap: () => _pickSlipFromGallery(context),
                ),
                const SizedBox(height: 12),
                _ScanOption(
                  icon: Icons.collections_rounded,
                  title: strings.syncAlbumTitle,
                  subtitle: strings.syncAlbumSubtitle,
                  onTap: () => _pickAlbumImages(context),
                ),
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AlbumSyncPanel(
                    images: _selectedImages,
                    statusByPath: _statusByPath,
                    isSyncing: _isSyncing,
                    onSync: () => _syncSelectedAlbum(context),
                    onTrain: () => _trainSelectedImages(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _trainSelectedImages(BuildContext context) async {
    if (_selectedImages.isEmpty) return;

    // Prompt user to enter comma-separated amounts corresponding to selected images
    final controller = TextEditingController();
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          strings.isThai ? 'ฝึกตัวอ่านจำนวนเงิน' : 'Train amount classifier',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.isThai
                  ? 'กรอกจำนวนเงินแยกด้วยคอมม่า ตามลำดับของภาพที่เลือก'
                  : 'Enter comma-separated amounts for the selected images in order.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g. 40,396.00,15.00,25.00',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.isThai ? 'ยกเลิก' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.isThai ? 'ฝึก' : 'Train'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final raw = controller.text.trim();
    if (raw.isEmpty) return;
    final parts = raw
        .split(RegExp(r'[ ,;]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length != _selectedImages.length) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            strings.isThai
                ? 'จำนวนค่าไม่ตรงกับจำนวนรูปที่เลือก'
                : 'Amount count does not match selected images.',
          ),
        ),
      );
      return;
    }

    final amounts = <double>[];
    for (final p in parts) {
      final v = double.tryParse(p.replaceAll(',', ''));
      if (v == null) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Invalid number: $p')));
        return;
      }
      amounts.add(v);
    }

    setState(() {
      _isSyncing = true;
    });

    for (var i = 0; i < _selectedImages.length; i++) {
      final image = _selectedImages[i];
      setState(() {
        _statusByPath[image.path] = _SlipSyncStatus.reading;
      });

      try {
        final result = await _recognizer.scanImagePath(image.path);
        final lines = result.rawText
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        final candidates = AmountClassifier.instance.extractCandidates(
          result.rawText,
        );
        if (candidates.isEmpty) {
          setState(() {
            _statusByPath[image.path] = _SlipSyncStatus.failed;
          });
          continue;
        }

        await AmountClassifier.instance.trainOnLabeledText(
          rawText: result.rawText,
          lines: lines,
          candidates: candidates,
          expectedAmount: amounts[i],
        );

        setState(() {
          _statusByPath[image.path] = _SlipSyncStatus.added;
        });
      } catch (_) {
        setState(() {
          _statusByPath[image.path] = _SlipSyncStatus.failed;
        });
      }
    }

    setState(() {
      _isSyncing = false;
    });

    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Training complete')));
  }
}

enum _SlipSyncStatus { pending, reading, added, duplicate, failed }

class _AlbumSyncPanel extends StatelessWidget {
  const _AlbumSyncPanel({
    required this.images,
    required this.statusByPath,
    required this.isSyncing,
    required this.onSync,
    this.onTrain,
  });

  final List<XFile> images;
  final Map<String, _SlipSyncStatus> statusByPath;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback? onTrain;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x2E5D81AD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.selectedSlipCount(images.length),
            style: const TextStyle(
              color: Color(0xFF071844),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          for (final image in images.take(8)) ...[
            _AlbumImageStatusRow(
              image: image,
              status: statusByPath[image.path] ?? _SlipSyncStatus.pending,
            ),
            const SizedBox(height: 8),
          ],
          if (images.length > 8) ...[
            Text(
              strings.moreSlipImages(images.length - 8),
              style: const TextStyle(
                color: Color(0xFF65748B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isSyncing ? null : onSync,
                  icon: isSyncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    isSyncing ? strings.syncingAlbum : strings.syncAlbum,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (onTrain != null)
                FilledButton.icon(
                  onPressed: isSyncing ? null : onTrain,
                  icon: const Icon(Icons.school_rounded),
                  label: Text(strings.isThai ? 'ฝึก' : 'Train'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlbumImageStatusRow extends StatelessWidget {
  const _AlbumImageStatusRow({required this.image, required this.status});

  final XFile image;
  final _SlipSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final (icon, color, label) = switch (status) {
      _SlipSyncStatus.pending => (
        Icons.schedule_rounded,
        const Color(0xFF65748B),
        strings.waitingToSync,
      ),
      _SlipSyncStatus.reading => (
        Icons.document_scanner_rounded,
        const Color(0xFF3268F6),
        strings.readingSlip,
      ),
      _SlipSyncStatus.added => (
        Icons.check_circle_rounded,
        const Color(0xFF1B8F73),
        strings.addedFromAlbum,
      ),
      _SlipSyncStatus.duplicate => (
        Icons.remove_circle_rounded,
        const Color(0xFFB8942D),
        strings.skippedDuplicateSlip,
      ),
      _SlipSyncStatus.failed => (
        Icons.error_rounded,
        const Color(0xFFB66A72),
        strings.couldNotReadSlip,
      ),
    };

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            image.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF10233F),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ScanOption extends StatelessWidget {
  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF3268F6), size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF071844),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF65748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF65748B)),
            ],
          ),
        ),
      ),
    );
  }
}
