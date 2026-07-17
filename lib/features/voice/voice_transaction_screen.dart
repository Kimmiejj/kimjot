import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../ai/ai_models.dart';
import '../ai/ai_settings_screen.dart';
import '../ai/ai_settings_store.dart';
import '../ai/ai_consent_gate.dart';
import '../auth/auth_user.dart';
import '../scan/external_ai_client.dart';
import '../transactions/transaction_repository.dart';
import 'device_audio_bridge.dart';
import 'voice_transaction_review_screen.dart';

class VoiceTransactionScreen extends StatefulWidget {
  const VoiceTransactionScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  @override
  State<VoiceTransactionScreen> createState() => _VoiceTransactionScreenState();
}

class _VoiceTransactionScreenState extends State<VoiceTransactionScreen> {
  Timer? _timer;
  bool _recording = false;
  bool _processing = false;
  int _seconds = 0;
  String? _transcript;
  String? _error;
  List<VoiceTransactionDraft> _drafts = const [];

  @override
  void initState() {
    super.initState();
    unawaited(AiSettingsStore.instance.load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) unawaited(DeviceAudioBridge.instance.stopRecording());
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_processing) return;
    if (!await ensureAiAllowed(context)) return;
    if (!mounted) return;
    if (!ExternalAiClient.instance.isConfigured) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (context) => const AiSettingsScreen()),
      );
      if (mounted) setState(() {});
      return;
    }
    if (_recording) {
      await _finishRecording();
    } else {
      await _beginRecording();
    }
  }

  Future<void> _beginRecording() async {
    HapticFeedback.mediumImpact();
    final started = await DeviceAudioBridge.instance.startRecording();
    if (!mounted) return;
    if (!started) {
      setState(() {
        _error = context.strings.isThai
            ? 'ไม่สามารถใช้ไมโครโฟนได้ กรุณาอนุญาตสิทธิ์แล้วลองอีกครั้ง'
            : 'Microphone access is unavailable. Allow permission and try again.';
      });
      return;
    }

    _timer?.cancel();
    setState(() {
      _recording = true;
      _seconds = 0;
      _drafts = const [];
      _transcript = null;
      _error = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= 60) unawaited(_finishRecording());
    });
  }

  Future<void> _finishRecording() async {
    if (!_recording) return;
    final thai = context.strings.isThai;
    _timer?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _recording = false;
      _processing = true;
      _error = null;
    });

    final path = await DeviceAudioBridge.instance.stopRecording();
    if (path == null) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = thai
              ? 'เสียงสั้นเกินไป ลองพูดใหม่อีกครั้ง'
              : 'The recording was too short. Please try again.';
        });
      }
      return;
    }

    final language = thai ? 'th' : 'en';
    final transcript = await ExternalAiClient.instance.transcribeVoice(
      path,
      language: language,
    );
    unawaited(File(path).delete().catchError((_) => File(path)));
    final drafts = transcript == null
        ? const <VoiceTransactionDraft>[]
        : await ExternalAiClient.instance.parseVoiceTransactions(transcript);
    if (!mounted) return;
    setState(() {
      _processing = false;
      _transcript = transcript;
      _drafts = drafts;
      if (drafts.isEmpty) {
        _error = thai
            ? 'AI ยังแยกรายการนี้ไม่ได้ ลองพูดยอดและรายการให้ชัดขึ้น'
            : 'AI could not build this draft. Say the amount and item clearly.';
      }
    });
    if (drafts.isNotEmpty) await _reviewDrafts();
  }

  Future<void> _reviewDrafts() async {
    final transcript = _transcript;
    if (_drafts.isEmpty || transcript == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VoiceTransactionReviewScreen(
          user: widget.user,
          transactionRepository: widget.transactionRepository,
          transcript: transcript,
          drafts: _drafts,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final thai = context.strings.isThai;
    final compact = KimjodLayout.isCompact(context);
    final configured = ExternalAiClient.instance.isConfigured;
    final stateText = !configured
        ? (thai ? 'เชื่อม AI ก่อนเริ่มใช้งาน' : 'Connect AI to get started')
        : _recording
        ? (thai
              ? 'กำลังฟัง · ${_formatDuration(_seconds)}'
              : 'Listening · ${_formatDuration(_seconds)}')
        : _processing
        ? (thai
              ? 'กำลังถอดเสียงและสร้างร่าง…'
              : 'Transcribing and building a draft…')
        : (thai ? 'แตะเพื่อเริ่มพูด' : 'Tap to start speaking');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5EF), Color(0xFFE7F8F0), Color(0xFFFFEFE7)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: KimjodLayout.horizontal(
              context,
              regular: 20,
              top: 10,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: AiSettingsStore.instance,
                      builder: (context, _) => _ModePill(
                        label: AiSettingsStore.instance.mode.label(
                          isThai: thai,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  thai
                      ? 'เล่าให้ฟัง เดี๋ยวจัดให้'
                      : 'Say it. We’ll sort it out.',
                  style: const TextStyle(
                    color: Color(0xFF172826),
                    fontSize: 31,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  thai
                      ? 'เช่น “KFC 200 แล้วซื้อต้นไม้ 129” — AI จะแยกเป็นการ์ดให้บันทึกทีละรายการ'
                      : 'Try “KFC 200, then a tree 129.” AI separates each transaction into its own card.',
                  style: const TextStyle(
                    color: Color(0xFF60706C),
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 22,
                    compact ? 22 : 28,
                    compact ? 18 : 22,
                    compact ? 18 : 22,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1E172826),
                        blurRadius: 36,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      InkResponse(
                        onTap: _toggleRecording,
                        radius: 68,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          width: _recording ? 124 : 112,
                          height: _recording ? 124 : 112,
                          decoration: BoxDecoration(
                            gradient: configured
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _recording
                                        ? const [
                                            Color(0xFFFF8B75),
                                            Color(0xFFEF5E68),
                                          ]
                                        : const [
                                            Color(0xFF1C8C78),
                                            Color(0xFF172826),
                                          ],
                                  )
                                : null,
                            color: configured ? null : const Color(0xFFD9DEDB),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x30172826),
                                blurRadius: 28,
                                offset: Offset(0, 13),
                              ),
                            ],
                          ),
                          child: _processing
                              ? const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFCFF7E9),
                                    strokeWidth: 3,
                                  ),
                                )
                              : Icon(
                                  _recording
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  color: configured
                                      ? const Color(0xFFCFF7E9)
                                      : const Color(0xFF87948F),
                                  size: 46,
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        stateText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF172826),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_recording) ...[
                        const SizedBox(height: 6),
                        Text(
                          thai
                              ? 'แตะอีกครั้งเพื่อหยุด · สูงสุด 60 วินาที'
                              : 'Tap again to stop · 60 seconds max',
                          style: const TextStyle(
                            color: Color(0xFF7A8883),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_transcript != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7F3),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            '“$_transcript”',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF50635D),
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB7484E),
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_drafts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _reviewDrafts,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      thai
                          ? 'ตรวจ ${_drafts.length} รายการ'
                          : 'Review ${_drafts.length} ${_drafts.length == 1 ? 'draft' : 'drafts'}',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 15,
            color: Color(0xFF0F766E),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}
