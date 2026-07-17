import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../scan/external_ai_client.dart';
import 'ai_models.dart';
import 'ai_settings_store.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  AiBackendStatus _status = AiBackendStatus.notConfigured;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AiSettingsStore.instance.load();
    await _checkConnection();
  }

  Future<void> _checkConnection() async {
    if (mounted) setState(() => _checking = true);
    final status = await ExternalAiClient.instance.checkStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final thai = context.strings.isThai;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(thai ? 'Gemini ของ Kimjot' : 'Kimjot Gemini'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5EF), Color(0xFFEAF8F2), Color(0xFFFFF2EB)],
          ),
        ),
        child: AnimatedBuilder(
          animation: AiSettingsStore.instance,
          builder: (context, _) => ListView(
            padding: KimjodLayout.horizontal(
              context,
              regular: 20,
              top: 10,
              bottom: 32,
            ),
            children: [
              _ConnectionCard(
                status: _status,
                checking: _checking,
                onRetry: _checkConnection,
                thai: thai,
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _SoftIcon(
                          icon: Icons.tune_rounded,
                          color: Color(0xFF0F766E),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                thai
                                    ? 'คุณภาพการวิเคราะห์'
                                    : 'Analysis quality',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                thai
                                    ? 'ใช้กับ Voice, Slip และสรุปการเงินจริง'
                                    : 'Used by Voice, Slip, and financial insights',
                                style: const TextStyle(
                                  color: Color(0xFF6D7975),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final mode in AiMode.values)
                      _ModeTile(
                        mode: mode,
                        selected: AiSettingsStore.instance.mode == mode,
                        thai: thai,
                        onTap: () => AiSettingsStore.instance.setMode(mode),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: AiSettingsStore.instance.aiConsent,
                  onChanged: AiSettingsStore.instance.setAiConsent,
                  secondary: const _SoftIcon(
                    icon: Icons.auto_awesome_rounded,
                    color: Color(0xFF6D5CE7),
                  ),
                  title: Text(
                    thai ? 'อนุญาตให้ใช้ฟีเจอร์ AI' : 'Allow AI features',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    thai
                        ? 'ต้องเปิดก่อนใช้ Voice, วิเคราะห์การเงิน, แชต และ AI อ่านสลิป'
                        : 'Required for Voice, financial analysis, chat, and AI slip reading.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: AiSettingsStore.instance.slipVisionConsent,
                  onChanged: AiSettingsStore.instance.aiConsent
                      ? AiSettingsStore.instance.setSlipVisionConsent
                      : null,
                  secondary: const _SoftIcon(
                    icon: Icons.document_scanner_rounded,
                    color: Color(0xFF3268F6),
                  ),
                  title: Text(
                    thai ? 'ให้ AI อ่านภาพสลิป' : 'AI slip vision',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    thai
                        ? 'ส่งภาพชั่วคราวเมื่อคุณกดตรวจด้วย AI เท่านั้น และไม่เก็บภาพบน backend'
                        : 'The image is sent transiently only when you request AI review.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PrivacyNote(thai: thai),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.status,
    required this.checking,
    required this.onRetry,
    required this.thai,
  });

  final AiBackendStatus status;
  final bool checking;
  final VoidCallback onRetry;
  final bool thai;

  @override
  Widget build(BuildContext context) {
    final ready = status == AiBackendStatus.ready;
    final title = checking
        ? (thai ? 'กำลังตรวจการเชื่อมต่อ…' : 'Checking connection…')
        : switch (status) {
            AiBackendStatus.ready =>
              thai ? 'Gemini พร้อมใช้งาน' : 'Gemini is ready',
            AiBackendStatus.missingApiKey =>
              thai
                  ? 'backend ยังไม่มี Gemini API key'
                  : 'Backend needs a Gemini API key',
            AiBackendStatus.unreachable =>
              thai ? 'ติดต่อ backend ไม่ได้' : 'Backend is unreachable',
            AiBackendStatus.notConfigured =>
              thai ? 'เชื่อม AI เพื่อเริ่มใช้งาน' : 'Connect AI to get started',
          };

    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SoftIcon(
                icon: ready ? Icons.check_rounded : Icons.link_rounded,
                color: ready
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFFF7968),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      thai
                          ? 'แอปเชื่อมต่อ Kimjod AI ให้อัตโนมัติ ไม่ต้องกรอก URL หรือ API key'
                          : 'Kimjod connects automatically. No URL or API key is required.',
                      style: const TextStyle(
                        color: Color(0xFF6D7975),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (checking)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          if (status == AiBackendStatus.missingApiKey) ...[
            const SizedBox(height: 12),
            Text(
              thai
                  ? 'ผู้ดูแลต้องใส่ GEMINI_API_KEY ใน Environment Variables ของ Vercel แล้ว Deploy ใหม่'
                  : 'Set GEMINI_API_KEY in the Vercel Environment Variables, then redeploy.',
              style: const TextStyle(
                color: Color(0xFF9A5B23),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.thai,
    required this.onTap,
  });

  final AiMode mode;
  final bool selected;
  final bool thai;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE5F6EF) : const Color(0xFFF7F8F7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0xFF83CBB5) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFA1AAA7),
                size: 21,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label(isThai: thai),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _modeDescription(mode, thai),
                      style: const TextStyle(
                        color: Color(0xFF6D7975),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.thai});

  final bool thai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF60706C), size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              thai
                  ? 'Gemini API key อยู่บน backend เท่านั้น แอปส่งข้อมูลผ่าน Firebase token และให้คุณยืนยันก่อนบันทึกทุกรายการ'
                  : 'The Gemini API key stays on the backend. Requests use Firebase auth and every transaction needs your confirmation.',
              style: const TextStyle(
                color: Color(0xFF60706C),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14172826),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _modeDescription(AiMode mode, bool thai) => switch (mode) {
  AiMode.auto =>
    thai
        ? 'เร็วในงานสั้น ละเอียดขึ้นเมื่อวิเคราะห์การเงิน'
        : 'Fast for short tasks, richer for financial insights',
  AiMode.fast =>
    thai
        ? 'ประหยัดและตอบไว เหมาะกับใช้ทุกวัน'
        : 'Lowest cost and latency for everyday use',
  AiMode.balanced =>
    thai ? 'แม่นขึ้นโดยยังรอไม่นาน' : 'More accuracy with moderate latency',
  AiMode.deep =>
    thai
        ? 'ละเอียดที่สุด แต่ช้ากว่าและใช้โควตามากกว่า'
        : 'Most thorough, slower, and uses more quota',
};
