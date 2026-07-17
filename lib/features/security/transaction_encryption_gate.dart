import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_language.dart';
import '../auth/auth_user.dart';
import 'biometric_recovery_key_store.dart';
import 'transaction_encryption_manager.dart';
import 'transaction_payload_cipher.dart';

class TransactionEncryptionGate extends StatefulWidget {
  const TransactionEncryptionGate({
    required this.user,
    required this.controller,
    required this.child,
    this.biometricKeyStore,
    super.key,
  });

  final AuthUser user;
  final TransactionEncryptionController controller;
  final Widget child;
  final BiometricRecoveryKeyStore? biometricKeyStore;

  @override
  State<TransactionEncryptionGate> createState() =>
      _TransactionEncryptionGateState();
}

class _TransactionEncryptionGateState extends State<TransactionEncryptionGate>
    with WidgetsBindingObserver {
  static const _automaticBiometricDelay = Duration(milliseconds: 300);

  final _recoveryController = TextEditingController();
  final _newRecoveryController = TextEditingController();
  final _confirmRecoveryController = TextEditingController();

  TransactionEncryptionAccess? _access;
  String? _newRecoveryKey;
  String? _error;
  var _busy = false;
  var _savedRecoveryKey = false;
  var _rememberRecoveryKey = false;
  var _hasBiometricKey = false;
  var _autoBiometricRequested = false;

  late final BiometricRecoveryKeyStore _biometricKeyStore =
      widget.biometricKeyStore ?? DeviceBiometricRecoveryKeyStore();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepare();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleAutomaticBiometricUnlock();
    }
  }

  @override
  void didUpdateWidget(TransactionEncryptionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      widget.controller.clearEncryptionKey();
      _access = null;
      _newRecoveryKey = null;
      _savedRecoveryKey = false;
      _rememberRecoveryKey = false;
      _hasBiometricKey = false;
      _autoBiometricRequested = false;
      _prepare();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recoveryController.dispose();
    _newRecoveryController.dispose();
    _confirmRecoveryController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final access = await widget.controller.prepareEncryption(widget.user.uid);
      final hasBiometricKey =
          access == TransactionEncryptionAccess.recoveryKeyRequired &&
          await _biometricKeyStore.hasSavedKey(widget.user.uid);
      if (mounted) {
        setState(() {
          _access = access;
          _hasBiometricKey = hasBiometricKey;
        });
        _scheduleAutomaticBiometricUnlock();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  void _scheduleAutomaticBiometricUnlock() {
    if (!mounted ||
        !_hasBiometricKey ||
        _autoBiometricRequested ||
        _access != TransactionEncryptionAccess.recoveryKeyRequired) {
      return;
    }
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    _autoBiometricRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(_automaticBiometricDelay);
      if (!mounted) return;
      final currentLifecycleState = WidgetsBinding.instance.lifecycleState;
      if (currentLifecycleState != null &&
          currentLifecycleState != AppLifecycleState.resumed) {
        _autoBiometricRequested = false;
        return;
      }
      await _unlockWithBiometrics();
    });
  }

  Future<void> _createRecoveryKey(String requestedRecoveryKey) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final recoveryKey = await widget.controller.createRecoveryKey(
        widget.user.uid,
        recoveryKey: requestedRecoveryKey,
      );
      try {
        await _biometricKeyStore.deleteKey(widget.user.uid);
      } catch (_) {
        // A newly created key must not reuse stale device credentials.
      }
      if (mounted) {
        setState(() {
          _newRecoveryKey = recoveryKey;
          _hasBiometricKey = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _useEnteredRecoveryKey() {
    final recoveryKey = TransactionPayloadCipher.normalizeRecoveryKey(
      _newRecoveryController.text,
    );
    final confirmation = TransactionPayloadCipher.normalizeRecoveryKey(
      _confirmRecoveryController.text,
    );
    if (recoveryKey.length <
        TransactionPayloadCipher.minimumRecoveryKeyLength) {
      setState(() {
        _error = context.strings.isThai
            ? 'คีย์ต้องยาวอย่างน้อย 12 ตัวอักษร'
            : 'Key must be at least 12 characters.';
      });
      return;
    }
    if (recoveryKey != confirmation) {
      setState(() {
        _error = context.strings.isThai
            ? 'คีย์ทั้งสองช่องไม่ตรงกัน'
            : 'The keys do not match.';
      });
      return;
    }
    _createRecoveryKey(_newRecoveryController.text.trim());
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final unlocked = await widget.controller.unlockWithRecoveryKey(
      widget.user.uid,
      _recoveryController.text,
    );
    if (!mounted) return;
    if (unlocked && _rememberRecoveryKey) {
      try {
        await _biometricKeyStore.saveKey(
          widget.user.uid,
          _recoveryController.text,
        );
      } catch (_) {
        // Unlocking should still succeed if secure storage is unavailable.
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (unlocked) {
        _access = TransactionEncryptionAccess.unlocked;
      } else {
        _error = context.strings.isThai
            ? 'คีย์ไม่ถูกต้องหรือไม่ใช่ของบัญชี Google นี้'
            : 'The key is incorrect or belongs to another account.';
      }
    });
  }

  Future<void> _unlockWithBiometrics() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final recoveryKey = await _biometricKeyStore.authenticateAndReadKey(
        userId: widget.user.uid,
        isThai: context.strings.isThai,
      );
      if (recoveryKey == null) return;

      final unlocked = await widget.controller.unlockWithRecoveryKey(
        widget.user.uid,
        recoveryKey,
      );
      if (!mounted) return;
      if (unlocked) {
        setState(() => _access = TransactionEncryptionAccess.unlocked);
        return;
      }

      try {
        await _biometricKeyStore.deleteKey(widget.user.uid);
      } catch (_) {
        // The unlock result is more important than removing a stale key.
      }
      if (!mounted) return;
      setState(() {
        _hasBiometricKey = false;
        _error = context.strings.isThai
            ? 'คีย์ที่จำไว้ใช้ไม่ได้ กรุณากรอกคีย์ใหม่'
            : 'The saved key no longer works. Enter your key again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.strings.isThai
            ? 'ปลดล็อกไม่สำเร็จ กรุณาลองใหม่'
            : 'Could not unlock. Try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendRecoveryEmail() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = await widget.controller.sendRecoveryKeyEmail(
        widget.user.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.isThai
                ? 'ส่งคีย์ไปที่ $email แล้ว'
                : 'Key sent to $email.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _recoveryEmailError(error, context.strings.isThai);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _recoveryEmailError(Object error, bool isThai) {
    final code = error.toString();
    if (code.contains('recovery_email_rate_limited')) {
      return isThai
          ? 'เพิ่งส่งอีเมลไป กรุณารอ 5 นาทีแล้วลองใหม่'
          : 'An email was just sent. Wait 5 minutes and try again.';
    }
    if (code.contains('recovery_key_not_found')) {
      return isThai
          ? 'ยังไม่มีคีย์สำรองสำหรับบัญชีนี้ กรุณาติดต่อผู้ดูแลระบบ'
          : 'No recovery-key backup exists for this account.';
    }
    return isThai
        ? 'ส่งอีเมลไม่สำเร็จ กรุณาลองใหม่ภายหลัง'
        : 'Could not send the recovery email. Try again later.';
  }

  @override
  Widget build(BuildContext context) {
    if (_access == TransactionEncryptionAccess.unlocked) {
      return widget.child;
    }
    if (_access == null && _error == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isThai = context.strings.isThai;
    final needsSetup = _access == TransactionEncryptionAccess.setupRequired;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE7FFF4),
                    Color(0xFFEAFBFF),
                    Color(0xFFF7F4FF),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 84,
                  color: Color(0x334A6FA5),
                ),
              ),
            ),
            const ModalBarrier(dismissible: false, color: Color(0x520F172A)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Dialog(
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFFFFF),
                              Color(0xFFEAFBFF),
                              Color(0xFFFFF4FA),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26305472),
                              blurRadius: 30,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0x3320C997),
                                        Color(0x333268F6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.enhanced_encryption_rounded,
                                    color: Color(0xFF145CC8),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      needsSetup
                                          ? (isThai
                                                ? 'ตั้งคีย์ก่อนเข้าใช้งาน'
                                                : 'Create a key to continue')
                                          : (isThai
                                                ? 'ต้องใส่คีย์ก่อนเข้าใช้งาน'
                                                : 'Encryption key required'),
                                      style: const TextStyle(
                                        color: Color(0xFF10233F),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        height: 1.16,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              needsSetup
                                  ? (isThai
                                        ? 'บัญชีนี้ยังไม่เคยตั้งคีย์ ให้สร้างคีย์ของคุณเองตอนนี้และจำไว้'
                                        : 'This account has no key yet. Create and remember your own key now.')
                                  : (isThai
                                        ? 'กรอกคีย์ที่คุณสร้างเองสำหรับบัญชี Google นี้ จึงจะเข้าใช้งานได้'
                                        : 'Enter the key you created for this Google account to continue.'),
                              style: const TextStyle(
                                color: Color(0xFF65748B),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (needsSetup)
                              ..._buildSetup(isThai)
                            else
                              ..._buildUnlock(isThai),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE8E5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFB42318),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    height: 1.35,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSetup(bool isThai) {
    if (_newRecoveryKey == null) {
      return [
        _RecoveryKeyField(
          fieldKey: const ValueKey('new-recovery-key'),
          controller: _newRecoveryController,
          isThai: isThai,
          label: isThai ? 'ตั้งคีย์ของคุณ' : 'Create your key',
          helperText: isThai
              ? 'อย่างน้อย 12 ตัวอักษร · ห้ามใช้อีเมล'
              : 'At least 12 characters · do not use your email',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _RecoveryKeyField(
          fieldKey: const ValueKey('confirm-recovery-key'),
          controller: _confirmRecoveryController,
          isThai: isThai,
          label: isThai ? 'ยืนยันคีย์อีกครั้ง' : 'Confirm your key',
          helperText: isThai
              ? 'ต้องตรงกับช่องแรก'
              : 'Must match the first field',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_busy) _useEnteredRecoveryKey();
          },
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _useEnteredRecoveryKey,
          icon: const Icon(Icons.lock_rounded),
          style: _primaryButtonStyle,
          label: Text(
            _busy
                ? (isThai ? 'กำลังตั้งค่าคีย์...' : 'Setting up key...')
                : (isThai ? 'ใช้คีย์นี้' : 'Use this key'),
          ),
        ),
      ];
    }

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F7F2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            SelectableText(
              _newRecoveryKey!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _newRecoveryKey!));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isThai ? 'คัดลอกแล้ว' : 'Copied')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(isThai ? 'คัดลอกคีย์' : 'Copy key'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _savedRecoveryKey,
        onChanged: (value) {
          setState(() => _savedRecoveryKey = value ?? false);
        },
        title: Text(
          isThai
              ? 'ฉันเก็บคีย์ไว้ในที่ปลอดภัยแล้ว'
              : 'I saved the key somewhere safe',
        ),
        subtitle: Text(
          isThai
              ? 'ระบบเก็บสำเนาที่เข้ารหัสไว้เพื่อส่งไปยังอีเมล Google เมื่อคุณร้องขอ'
              : 'An encrypted backup is kept so it can be emailed to your Google address on request.',
        ),
      ),
      const SizedBox(height: 6),
      FilledButton(
        onPressed: !_savedRecoveryKey
            ? null
            : () {
                setState(() {
                  _newRecoveryKey = null;
                  _access = TransactionEncryptionAccess.unlocked;
                });
              },
        style: _primaryButtonStyle,
        child: Text(isThai ? 'ไปต่อ' : 'Continue'),
      ),
    ];
  }

  List<Widget> _buildUnlock(bool isThai) {
    return [
      if (_hasBiometricKey) ...[
        FilledButton.icon(
          key: const ValueKey('biometric-unlock'),
          onPressed: _busy ? null : _unlockWithBiometrics,
          icon: const Icon(Icons.fingerprint_rounded),
          style: _primaryButtonStyle,
          label: Text(
            isThai
                ? 'ยืนยันด้วยใบหน้าหรือลายนิ้วมือ'
                : 'Unlock with face or fingerprint',
          ),
        ),
        const SizedBox(height: 14),
      ],
      _RecoveryKeyField(
        fieldKey: const ValueKey('unlock-recovery-key'),
        controller: _recoveryController,
        isThai: isThai,
        label: isThai ? 'คีย์ของคุณ' : 'Your key',
        helperText: isThai
            ? 'กรอกคีย์ที่ตั้งไว้กับบัญชีนี้'
            : 'Enter the key created for this account',
        onSubmitted: (_) {
          if (!_busy) _unlock();
        },
      ),
      CheckboxListTile(
        key: const ValueKey('remember-recovery-key'),
        contentPadding: EdgeInsets.zero,
        value: _rememberRecoveryKey,
        onChanged: _busy
            ? null
            : (value) {
                setState(() => _rememberRecoveryKey = value ?? false);
              },
        secondary: const Icon(Icons.fingerprint_rounded),
        title: Text(
          isThai ? 'จำคีย์บนเครื่องนี้' : 'Remember the key on this device',
        ),
        subtitle: Text(
          isThai
              ? 'ครั้งต่อไปใช้ใบหน้าหรือลายนิ้วมือแทนการกรอกคีย์'
              : 'Use face or fingerprint recognition instead of entering the key next time.',
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _busy ? null : _unlock,
        icon: const Icon(Icons.lock_open_rounded),
        style: _primaryButtonStyle,
        label: Text(
          _busy
              ? (isThai ? 'กำลังตรวจสอบ...' : 'Checking...')
              : (isThai ? 'ปลดล็อก' : 'Unlock'),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _sendRecoveryEmail,
        icon: const Icon(Icons.mark_email_read_outlined),
        style: _secondaryButtonStyle,
        label: Text(
          isThai
              ? 'ลืมคีย์? ส่งไปยังอีเมล Google'
              : 'Forgot key? Send it to Google email',
        ),
      ),
    ];
  }
}

class _RecoveryKeyField extends StatefulWidget {
  const _RecoveryKeyField({
    required this.fieldKey,
    required this.controller,
    required this.isThai,
    required this.label,
    required this.helperText,
    this.textInputAction,
    this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final bool isThai;
  final String label;
  final String helperText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_RecoveryKeyField> createState() => _RecoveryKeyFieldState();
}

class _RecoveryKeyFieldState extends State<_RecoveryKeyField> {
  var _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final count = TransactionPayloadCipher.normalizeRecoveryKey(
          value.text,
        ).characters.length;
        final meetsMinimum =
            count >= TransactionPayloadCipher.minimumRecoveryKeyLength;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              obscureText: _obscureText,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: widget.textInputAction,
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
                labelText: widget.label,
                suffixIcon: IconButton(
                  key: ValueKey('${widget.fieldKey}-visibility'),
                  tooltip: _obscureText
                      ? (widget.isThai ? 'แสดงคีย์' : 'Show key')
                      : (widget.isThai ? 'ซ่อนคีย์' : 'Hide key'),
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
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.82),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                labelStyle: const TextStyle(
                  color: Color(0xFF65748B),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Color(0xFF145CC8),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0x245D81AD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: Color(0xFF3268F6),
                    width: 1.8,
                  ),
                ),
              ),
              onSubmitted: widget.onSubmitted,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.helperText,
                    style: const TextStyle(
                      color: Color(0xFF65748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.isThai ? '$count ตัวอักษร' : '$count characters',
                  key: ValueKey(
                    '${widget.fieldKey.toString()}-character-count',
                  ),
                  style: TextStyle(
                    color: meetsMinimum
                        ? const Color(0xFF138A68)
                        : const Color(0xFF65748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

final _primaryButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  backgroundColor: const Color(0xFF3268F6),
  foregroundColor: Colors.white,
  disabledBackgroundColor: const Color(0x663268F6),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  textStyle: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  ),
);

final _secondaryButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(48),
  backgroundColor: Colors.white.withValues(alpha: 0.72),
  foregroundColor: const Color(0xFF16345F),
  side: const BorderSide(color: Color(0x2E5D81AD)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  textStyle: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  ),
);
