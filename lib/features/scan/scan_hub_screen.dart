// ignore_for_file: unused_element

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../auth/auth_user.dart';
import '../transactions/create_transaction_input.dart';
import '../transactions/category_localization.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/transaction_source.dart';
import '../transactions/transaction_type.dart';
import 'album_sync_ai_analyzer.dart';
import 'album_sync_review_screen.dart';
import 'slip_fingerprint.dart';
import 'slip_scan_result.dart';
import 'slip_review_screen.dart';
import 'slip_text_recognizer.dart';
import 'slip_date_parser.dart';
import 'slip_amount_classifier.dart';

class ScanHubScreen extends StatefulWidget {
  const ScanHubScreen({
    required this.user,
    required this.transactionRepository,
    this.showBackButton = true,
    this.onReturnHome,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;
  final bool showBackButton;
  final VoidCallback? onReturnHome;

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

  DateTime? _fallbackImageDate(String imagePath) {
    try {
      return File(imagePath).lastModifiedSync();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  Future<void> _openSlipReview(
    BuildContext context, {
    required String imagePath,
    List<String>? imagePaths,
  }) async {
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SlipReviewScreen(
          user: widget.user,
          transactionRepository: widget.transactionRepository,
          imagePath: imagePath,
          imagePaths: imagePaths,
        ),
      ),
    );

    if (saved == true && context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(strings.transactionSaved)));
    }
  }

  Future<void> _pickSlipFromGallery(BuildContext context) async {
    final hasPermission = await _requestGalleryPermission(context);
    if (!hasPermission || !context.mounted) {
      return;
    }

    XFile? image;

    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);

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

      messenger.showSnackBar(
        SnackBar(content: Text(strings.galleryPermissionDenied)),
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

    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);

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

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => AlbumSyncReviewScreen(
            user: widget.user,
            transactionRepository: widget.transactionRepository,
            imagePaths: images.map((image) => image.path).toList(),
          ),
        ),
      );

      if (!mounted) return;

      widget.onReturnHome?.call();

      if (saved == true) {
        messenger.showSnackBar(
          SnackBar(content: Text(strings.transactionSaved)),
        );
      }

      setState(() {
        _selectedImages.clear();
        _statusByPath.clear();
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
        final scannedResult = await _recognizer.scanImagePath(image.path);
        final analysis = await analyzeAlbumSyncSlip(
          result: scannedResult,
          imagePath: image.path,
        );
        final result = analysis.result;
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
        final decision = analysis.decision;
        if (decision == null) {
          failed++;
          if (!mounted) return;

          setState(() {
            _statusByPath[image.path] = _SlipSyncStatus.failed;
          });
          continue;
        }

        // ✅ Resolve category from AI analysis
        // ✅ Parse transaction date from slip
        final transactionDate = parseTransactionDateFrom(
          dateText: result.dateText,
          timeText: result.timeText,
          referenceText: result.reference,
          rawText: result.rawText,
          fallbackDate: _fallbackImageDate(image.path),
        );

        final localizedCategory = localizedCategoryName(
          strings: strings,
          categoryId: decision.categoryId,
          fallbackName: decision.categoryName,
        );

        await widget.transactionRepository.createManualTransaction(
          CreateTransactionInput(
            userId: widget.user.uid,
            amount: amount,
            type: decision.type,
            categoryId: decision.categoryId,
            categoryName: localizedCategory,
            transactionDate: transactionDate,
            transactionDateText: strings.formatDateTime(transactionDate),
            source: TransactionSource.gallerySlip,
            note: decision.note,
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

  ({String categoryId, String categoryName}) _resolveCategoryFromAI(
    SlipScanResult result,
  ) {
    final type = result.category == SlipCategory.income
        ? TransactionType.income
        : TransactionType.expense;
    final text = result.rawText.toLowerCase();

    if (type == TransactionType.income) {
      if (text.contains('salary') || text.contains('เงินเดือน')) {
        return (categoryId: 'salary', categoryName: 'Salary');
      }
      if (text.contains('bonus') || text.contains('โบนัส')) {
        return (categoryId: 'bonus', categoryName: 'Bonus');
      }
      if (text.contains('interest') || text.contains('ดอกเบี้ย')) {
        return (categoryId: 'interest', categoryName: 'Interest / Dividend');
      }
      return (categoryId: 'salary', categoryName: 'Salary');
    }

    if (type == TransactionType.expense) {
      if (_looksLikePaymentSlip(result) || result.reference != null) {
        return (categoryId: 'transfer', categoryName: 'Transfer');
      }
      if (text.contains('food') ||
          text.contains('restaurant') ||
          text.contains('อาหาร')) {
        return (categoryId: 'food', categoryName: 'Food');
      }
      if (text.contains('transport') ||
          text.contains('taxi') ||
          text.contains('grab')) {
        return (categoryId: 'transport', categoryName: 'Transport');
      }
      if (text.contains('health') ||
          text.contains('hospital') ||
          text.contains('โรงพยาบาล')) {
        return (categoryId: 'health', categoryName: 'Health');
      }
      if (text.contains('education') ||
          text.contains('school') ||
          text.contains('โรงเรียน')) {
        return (categoryId: 'education', categoryName: 'Education');
      }
      if (text.contains('entertainment') ||
          text.contains('movie') ||
          text.contains('บันเทิง')) {
        return (categoryId: 'entertainment', categoryName: 'Entertainment');
      }
      if (text.contains('travel') ||
          text.contains('hotel') ||
          text.contains('ท่องเที่ยว')) {
        return (categoryId: 'travel', categoryName: 'Travel');
      }
      if (text.contains('bill') ||
          text.contains('electricity') ||
          text.contains('ค่า')) {
        return (categoryId: 'bills', categoryName: 'Bills');
      }
      if (text.contains('rent') ||
          text.contains('apartment') ||
          text.contains('เช่า')) {
        return (categoryId: 'rent', categoryName: 'Rent / Home');
      }
      return (categoryId: 'shopping', categoryName: 'Shopping');
    }

    return (categoryId: 'other', categoryName: 'Other');
  }

  // Replaced by shared parser in slip_date_parser.dart

  // Date parsing is centralized in `slip_date_parser.dart` (parseTransactionDateFrom)

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: widget.showBackButton,
        title: Text(strings.scanHub),
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5EF), Color(0xFFEAF8F2), Color(0xFFFFF4ED)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: KimjodLayout.horizontal(
              context,
              regular: 20,
              top: 12,
              bottom: widget.showBackButton ? 24 : 104,
            ),
            children: [
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
      builder: (ctx) => KimjodDialog(
        title: strings.isThai
            ? 'ฝึกตัวอ่านจำนวนเงิน'
            : 'Train amount classifier',
        icon: Icons.psychology_alt_rounded,
        message: strings.isThai
            ? 'กรอกจำนวนเงินตามลำดับรูปที่เลือก แยกแต่ละรูปด้วยคอมม่า'
            : 'Enter amounts for the selected images in order, separated by commas.',
        content: KimjodDialogTextField(
          controller: controller,
          hintText: '40, 396.00, 15.00, 25.00',
          keyboardType: TextInputType.text,
        ),
        actions: [
          KimjodDialogAction(
            label: strings.isThai ? 'ยกเลิก' : 'Cancel',
            icon: Icons.close_rounded,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          KimjodDialogAction(
            label: strings.isThai ? 'ฝึก' : 'Train',
            icon: Icons.auto_fix_high_rounded,
            isPrimary: true,
            onPressed: () => Navigator.of(ctx).pop(true),
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

        final contexts = AmountClassifier.instance.extractCandidateContexts(
          result.rawText,
          lines: lines,
        );
        if (contexts.isEmpty) {
          setState(() {
            _statusByPath[image.path] = _SlipSyncStatus.failed;
          });
          continue;
        }

        await AmountClassifier.instance.trainOnLabeledContexts(
          rawText: result.rawText,
          lines: lines,
          contexts: contexts,
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
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: Row(
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
                  ),
                ),
                const SizedBox(width: 8),
                if (onTrain != null)
                  FilledButton.icon(
                    onPressed: isSyncing ? null : onTrain,
                    icon: const Icon(Icons.school_rounded),
                    label: Text(strings.isThai ? 'ฝึก' : 'Train'),
                  ),
              ],
            ),
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
    final compact = KimjodLayout.isCompact(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: Row(
            children: [
              Container(
                width: compact ? 46 : 52,
                height: compact ? 46 : 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF172826),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: const Color(0xFFCFF7E9), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF172826),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6D7975),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF6D7975)),
            ],
          ),
        ),
      ),
    );
  }
}
