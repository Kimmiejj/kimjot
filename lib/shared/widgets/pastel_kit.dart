import 'package:flutter/material.dart';

class KimjodMascot extends StatelessWidget {
  const KimjodMascot({this.size = 88, this.mood = MascotMood.happy, super.key});

  final double size;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    final faceSize = size * 0.74;
    final cheekSize = size * 0.12;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: size * 0.02,
            bottom: size * 0.02,
            child: Container(
              width: size * 0.58,
              height: size * 0.58,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD7E5).withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: size * 0.02,
            top: size * 0.06,
            child: Container(
              width: size * 0.46,
              height: size * 0.46,
              decoration: BoxDecoration(
                color: const Color(0xFFC8F6DD).withValues(alpha: 0.84),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: faceSize,
              height: faceSize,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFE8FCFF),
                    Color(0xFFFFEFF7),
                  ],
                ),
                borderRadius: BorderRadius.circular(size * 0.28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F305472),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: faceSize * 0.25,
                    top: faceSize * 0.34,
                    child: _Eye(size: size),
                  ),
                  Positioned(
                    right: faceSize * 0.25,
                    top: faceSize * 0.34,
                    child: _Eye(size: size),
                  ),
                  Positioned(
                    left: faceSize * 0.22,
                    top: faceSize * 0.56,
                    child: _Cheek(size: cheekSize),
                  ),
                  Positioned(
                    right: faceSize * 0.22,
                    top: faceSize * 0.56,
                    child: _Cheek(size: cheekSize),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.26),
                    child: Icon(
                      mood == MascotMood.calm
                          ? Icons.horizontal_rule_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: const Color(0xFF173054),
                      size: size * 0.23,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: size * 0.05,
            top: size * 0.05,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE59D),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: size * 0.14,
                color: const Color(0xFF9A6A00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum MascotMood { happy, calm }

class _Eye extends StatelessWidget {
  const _Eye({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.07,
      height: size * 0.09,
      decoration: BoxDecoration(
        color: const Color(0xFF173054),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _Cheek extends StatelessWidget {
  const _Cheek({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.62,
      decoration: BoxDecoration(
        color: const Color(0xFFFFAFC6).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class PastelHeroCard extends StatelessWidget {
  const PastelHeroCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xEFFFFFFF), Color(0xE8E8FCFF), Color(0xEFFFF4FA)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C305472),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MascotTip extends StatelessWidget {
  const MascotTip({
    required this.message,
    this.mood = MascotMood.happy,
    super.key,
  });

  final String message;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    return PastelHeroCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          KimjodMascot(size: 54, mood: mood),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF31506F),
                fontSize: 13,
                fontWeight: FontWeight.w800,
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
