import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/pastel_kit.dart';
import 'biometric_recovery_key_store.dart';
import 'transaction_encryption_manager.dart';
import 'transaction_payload_cipher.dart';

class ChangeRecoveryKeyScreen extends StatefulWidget {
  const ChangeRecoveryKeyScreen({
    required this.userId,
    required this.controller,
    this.biometricKeyStore,
    super.key,
  });

  final String userId;
  final TransactionEncryptionController controller;
  final BiometricRecoveryKeyStore? biometricKeyStore;

  @override
  State<ChangeRecoveryKeyScreen> createState() =>
      _ChangeRecoveryKeyScreenState();
}

class _ChangeRecoveryKeyScreenState extends State<ChangeRecoveryKeyScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _error;
  var _busy = false;

  late final BiometricRecoveryKeyStore _biometricKeyStore =
      widget.biometricKeyStore ?? DeviceBiometricRecoveryKeyStore();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changeKey() async {
    final isThai = context.strings.isThai;
    final current = TransactionPayloadCipher.normalizeRecoveryKey(
      _currentController.text,
    );
    final next = TransactionPayloadCipher.normalizeRecoveryKey(
      _newController.text,
    );
    final confirmation = TransactionPayloadCipher.normalizeRecoveryKey(
      _confirmController.text,
    );
    if (current.isEmpty) {
      setState(() {
        _error = isThai
            ? 'กรุณาใส่ recovery key ปัจจุบัน'
            : 'Enter your current recovery key.';
      });
      return;
    }
    if (next.length < TransactionPayloadCipher.minimumRecoveryKeyLength) {
      setState(() {
        _error = isThai
            ? 'Recovery key ใหม่ต้องยาวอย่างน้อย 12 ตัวอักษร'
            : 'The new recovery key must be at least 12 characters.';
      });
      return;
    }
    if (next != confirmation) {
      setState(() {
        _error = isThai
            ? 'Recovery key ใหม่ทั้งสองช่องไม่ตรงกัน'
            : 'The new recovery keys do not match.';
      });
      return;
    }
    if (current == next) {
      setState(() {
        _error = isThai
            ? 'Recovery key ใหม่ต้องไม่ซ้ำกับคีย์ปัจจุบัน'
            : 'The new recovery key must differ from the current key.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final changed = await widget.controller.changeRecoveryKey(
        userId: widget.userId,
        currentRecoveryKey: _currentController.text,
        newRecoveryKey: _newController.text,
      );
      if (!mounted) return;
      if (!changed) {
        setState(() {
          _error = isThai
              ? 'Recovery key ปัจจุบันไม่ถูกต้อง'
              : 'The current recovery key is incorrect.';
        });
        return;
      }
      try {
        await _biometricKeyStore.deleteKey(widget.userId);
      } catch (_) {
        // The key change succeeded even if device secure storage is unavailable.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isThai
                ? 'เปลี่ยน recovery key สำเร็จ'
                : 'Recovery key changed successfully.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = isThai
            ? 'เปลี่ยนคีย์ไม่สำเร็จ กรุณาลองใหม่ภายหลัง'
            : 'Could not change the key. Try again later.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = context.strings.isThai;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7FFF4), Color(0xFFEAFBFF), Color(0xFFF7F4FF)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.72),
                      foregroundColor: const Color(0xFF10233F),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x245D81AD)),
                    ),
                    child: Text(
                      isThai ? 'ความปลอดภัย' : 'SECURITY',
                      style: const TextStyle(
                        color: Color(0xFF145CC8),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                isThai ? 'ความปลอดภัยของข้อมูล' : 'Data security',
                style: const TextStyle(
                  color: Color(0xFF65748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isThai ? 'เปลี่ยน Recovery key' : 'Change recovery key',
                style: const TextStyle(
                  color: Color(0xFF10233F),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 14),
              MascotTip(
                mood: MascotMood.calm,
                message: isThai
                    ? 'ต้องยืนยันคีย์ปัจจุบันก่อน ข้อมูลเดิมจะยังเข้ารหัสอยู่และเปลี่ยนเฉพาะคีย์ที่ใช้ปลดล็อก'
                    : 'Confirm the current key first. Existing data stays encrypted; only the unlock key changes.',
              ),
              const SizedBox(height: 14),
              PastelHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel(
                      icon: Icons.lock_outline_rounded,
                      step: '01',
                    ),
                    const SizedBox(height: 14),
                    _RecoveryKeyField(
                      key: const ValueKey('current-recovery-key'),
                      controller: _currentController,
                      label: isThai
                          ? 'Recovery key ปัจจุบัน'
                          : 'Current recovery key',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PastelHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel(icon: Icons.key_rounded, step: '02'),
                    const SizedBox(height: 8),
                    Text(
                      isThai
                          ? 'ตั้งคีย์ใหม่อย่างน้อย 12 ตัวอักษร และกรอกให้ตรงกันทั้งสองช่อง'
                          : 'Use at least 12 characters and enter the same new key twice.',
                      style: const TextStyle(
                        color: Color(0xFF65748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _RecoveryKeyField(
                      key: const ValueKey('new-recovery-key'),
                      controller: _newController,
                      label: isThai ? 'Recovery key ใหม่' : 'New recovery key',
                    ),
                    const SizedBox(height: 14),
                    _RecoveryKeyField(
                      key: const ValueKey('confirm-new-recovery-key'),
                      controller: _confirmController,
                      label: isThai
                          ? 'ยืนยัน Recovery key ใหม่'
                          : 'Confirm new key',
                      onSubmitted: (_) {
                        if (!_busy) _changeKey();
                      },
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9E5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x33E6453D)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFB42318),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFF8F241D),
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1FC9DC), Color(0xFF3268F6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2B1FC9DC),
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _changeKey,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.key_rounded),
                  label: Text(
                    _busy
                        ? (isThai ? 'กำลังเปลี่ยนคีย์...' : 'Changing key...')
                        : (isThai
                              ? 'เปลี่ยน Recovery key'
                              : 'Change recovery key'),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.step});

  final IconData icon;
  final String step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0x3320C997), Color(0x333268F6)],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: const Color(0xFF145CC8), size: 21),
        ),
        const Spacer(),
        Text(
          step,
          style: const TextStyle(
            color: Color(0x8065748B),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _RecoveryKeyField extends StatefulWidget {
  const _RecoveryKeyField({
    required this.controller,
    required this.label,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_RecoveryKeyField> createState() => _RecoveryKeyFieldState();
}

class _RecoveryKeyFieldState extends State<_RecoveryKeyField> {
  var _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isThai = context.strings.isThai;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final count = TransactionPayloadCipher.normalizeRecoveryKey(
          value.text,
        ).characters.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: Color(0xFF496582),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x245D81AD)),
              ),
              child: TextField(
                controller: widget.controller,
                obscureText: _obscureText,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                maxLength: 256,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
                style: const TextStyle(
                  color: Color(0xFF10233F),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                  hintText: isThai ? 'กรอกคีย์ที่นี่' : 'Enter key here',
                  hintStyle: const TextStyle(
                    color: Color(0x6665748B),
                    fontWeight: FontWeight.w700,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _obscureText
                        ? (isThai ? 'แสดงคีย์' : 'Show key')
                        : (isThai ? 'ซ่อนคีย์' : 'Hide key'),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F1FF),
                      foregroundColor: const Color(0xFF145CC8),
                    ),
                    onPressed: () {
                      setState(() => _obscureText = !_obscureText);
                    },
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onSubmitted: widget.onSubmitted,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                isThai ? '$count ตัวอักษร' : '$count characters',
                style: TextStyle(
                  color:
                      count >= TransactionPayloadCipher.minimumRecoveryKeyLength
                      ? const Color(0xFF138A68)
                      : const Color(0x8065748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
