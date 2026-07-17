import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../auth/auth_user.dart';
import '../scan/external_ai_client.dart';
import '../transactions/home_summary.dart';
import '../transactions/transaction_repository.dart';
import 'ai_settings_screen.dart';
import 'ai_consent_gate.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    required this.user,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final TransactionRepository transactionRepository;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<FinancialChatMessage> _messages = [];
  List<String> _suggestions = const [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const AiSettingsScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _send([String? suggested]) async {
    final message = (suggested ?? _controller.text).trim();
    if (message.isEmpty || _sending) return;
    if (!await ensureAiAllowed(context)) return;
    if (!ExternalAiClient.instance.isConfigured) {
      await _openSettings();
      return;
    }

    final history = _messages.length <= 12
        ? List<FinancialChatMessage>.of(_messages)
        : _messages.sublist(_messages.length - 12);
    _controller.clear();
    setState(() {
      _messages.add(FinancialChatMessage(content: message, isUser: true));
      _suggestions = const [];
      _sending = true;
    });
    _scrollToBottom();

    final summary = await _loadSummary();

    final now = DateTime.now();
    final reply = await ExternalAiClient.instance.chat(
      message: message,
      history: history,
      context: <String, Object?>{
        'period': '${now.year}-${now.month.toString().padLeft(2, '0')}',
        'incomeTotal': summary.incomeTotal,
        'expenseTotal': summary.expenseTotal,
        'balance': summary.balance,
        'transactionCount': summary.transactionCount,
      },
    );
    if (!mounted) return;

    setState(() {
      _sending = false;
      if (reply == null) {
        _messages.add(
          FinancialChatMessage(
            content: context.strings.isThai
                ? 'ตอนนี้ติดต่อ AI ไม่สำเร็จ กรุณาตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง'
                : 'AI is unavailable. Check your connection and try again.',
            isUser: false,
          ),
        );
      } else {
        _messages.add(
          FinancialChatMessage(content: reply.answer, isUser: false),
        );
        _suggestions = reply.suggestions;
      }
    });
    _scrollToBottom();
  }

  Future<HomeSummary> _loadSummary() async {
    try {
      return await widget.transactionRepository
          .watchCurrentMonthSummary(widget.user.uid)
          .first
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return const HomeSummary.empty();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final thai = context.strings.isThai;
    final configured = ExternalAiClient.instance.isConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(thai ? 'คุยกับ Kimjot Gemini' : 'Chat with Kimjot Gemini'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
            tooltip: thai ? 'ตั้งค่า AI' : 'AI settings',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5EF), Color(0xFFEAF8F2), Color(0xFFFFF2EB)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: _ChatIntro(configured: configured, onSetup: _openSettings),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyChat(onSuggestion: _send)
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const _ThinkingBubble();
                        }
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            if (_suggestions.isNotEmpty)
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ActionChip(
                    label: Text(_suggestions[index]),
                    onPressed: _sending
                        ? null
                        : () => _send(_suggestions[index]),
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    side: const BorderSide(color: Color(0x267092BE)),
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: _Composer(
                  controller: _controller,
                  enabled: !_sending,
                  onSend: _send,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatIntro extends StatelessWidget {
  const _ChatIntro({required this.configured, required this.onSetup});

  final bool configured;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final thai = context.strings.isThai;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF172826),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30172826),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFCFF7E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF172826),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              configured
                  ? (thai
                        ? 'ถามเรื่องงบ รายรับรายจ่าย หรือวางแผนจากยอดรวมเดือนนี้ได้'
                        : 'Ask about budgets, spending, or this month’s totals.')
                  : (thai
                        ? 'Kimjod AI กำลังเชื่อมต่อ Gemini ให้อัตโนมัติ'
                        : 'Kimjod AI is connecting to Gemini automatically.'),
              style: const TextStyle(
                color: Colors.white,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!configured)
            TextButton(
              onPressed: onSetup,
              child: Text(thai ? 'ตั้งค่า' : 'Set up'),
            ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final thai = context.strings.isThai;
    final prompts = thai
        ? const [
            'เดือนนี้ใช้เงินเป็นอย่างไร',
            'ช่วยวางงบเดือนหน้า',
            'ควรลดรายจ่ายตรงไหน',
          ]
        : const [
            'How is my spending this month?',
            'Help plan next month’s budget',
            'Where can I cut spending?',
          ];
    return ListView(
      padding: KimjodLayout.horizontal(
        context,
        regular: 22,
        top: 30,
        bottom: 20,
      ),
      children: [
        const Icon(
          Icons.chat_bubble_outline_rounded,
          size: 48,
          color: Color(0xFF5F7D75),
        ),
        const SizedBox(height: 14),
        Text(
          thai ? 'เริ่มจากคำถามสั้น ๆ' : 'Start with a quick question',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF172826),
          ),
        ),
        const SizedBox(height: 16),
        for (final prompt in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: OutlinedButton(
              onPressed: () => onSuggestion(prompt),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.82),
                foregroundColor: const Color(0xFF172826),
                side: const BorderSide(color: Color(0x267092BE)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(prompt, textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final FinancialChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? const Color(0xFF172826)
              : Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 5),
            bottomRight: Radius.circular(message.isUser ? 5 : 20),
          ),
          border: message.isUser
              ? null
              : Border.all(color: const Color(0x207092BE)),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: message.isUser ? Colors.white : const Color(0xFF172826),
            fontSize: 15,
            height: 1.42,
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: const Color(0x25172826),
      borderRadius: BorderRadius.circular(24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: context.strings.isThai
                    ? 'ถาม Kimjod AI…'
                    : 'Ask Kimjod AI…',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(18, 13, 8, 13),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton.filled(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.arrow_upward_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF172826),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
