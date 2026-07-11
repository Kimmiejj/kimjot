import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/app_language.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/pastel_kit.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.authService, super.key});

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorMessage = error.message ?? context.strings.googleSignInFailed;
      });
    } on GoogleSignInException catch (error) {
      setState(() {
        _errorMessage = _googleSignInErrorMessage(error);
      });
    } catch (error) {
      setState(() {
        _errorMessage = context.strings.googleSetupFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  String _googleSignInErrorMessage(GoogleSignInException error) {
    final description = error.description;
    if (description != null &&
        description.contains('serverClientId must be provided')) {
      return context.strings.missingGoogleClientId;
    }

    return description ?? context.strings.androidOauthFailed;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final strings = context.strings;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFD7FFF0),
              Color(0xFFE7FBFF),
              Color(0xFFF4F0FF),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 52,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: KimjodMascot(size: 96)),
                      const SizedBox(height: 14),
                      const BrandMark(),
                      const SizedBox(height: 28),
                      Text(
                        strings.loginHeadline,
                        textAlign: TextAlign.center,
                        style: textTheme.displaySmall?.copyWith(
                          color: const Color(0xFF071844),
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        strings.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF65748B),
                          height: 1.45,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 34),
                      _LoginCard(
                        isSigningIn: _isSigningIn,
                        onSignIn: _isSigningIn ? null : _signIn,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _InlineError(message: _errorMessage!),
                      ],
                      const SizedBox(height: 28),
                      const _PrivacyNote(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.isSigningIn, required this.onSignIn});

  final bool isSigningIn;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24305472),
            blurRadius: 44,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onSignIn,
            icon: isSigningIn
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.g_mobiledata_rounded, size: 32),
            label: Text(isSigningIn ? strings.signingIn : strings.continueWithGoogle),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.74),
              foregroundColor: const Color(0xFF14305F),
              disabledForegroundColor: const Color(0xFF65748B),
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(21),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TrustTile(
                  label: 'OCR',
                  value: strings.onDevice,
                  icon: Icons.document_scanner_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TrustTile(
                  label: strings.storage,
                  value: strings.noSlipImage,
                  icon: Icons.cloud_off_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustTile extends StatelessWidget {
  const _TrustTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x1F5D81AD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: const Color(0xFF3268F6), size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF65748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF10233F),
                  fontSize: 15,
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

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2353).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.strings.privacyNote,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB9C8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFD94768)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8F2440),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
