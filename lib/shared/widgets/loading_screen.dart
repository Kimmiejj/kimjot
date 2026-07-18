import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_language.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    required this.message,
    this.completed = false,
    super.key,
  });

  final String message;
  final bool completed;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.completed) {
      _controller.value = 0.86;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD9FFF0), Color(0xFFE7FBFF), Color(0xFFFFF1F7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _LaunchMovie(
                      progress: _controller.value,
                      readyLabel: context.strings.isThai
                          ? 'Kimjod พร้อมแล้ว!'
                          : 'Kimjod is ready!',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF31506F),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        width: 176,
                        height: 6,
                        child: LinearProgressIndicator(
                          value: widget.completed ? 1 : _controller.value,
                          color: const Color(0xFF42BFA3),
                          backgroundColor: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchMovie extends StatelessWidget {
  const _LaunchMovie({required this.progress, required this.readyLabel});

  final double progress;
  final String readyLabel;

  @override
  Widget build(BuildContext context) {
    final mascotIn = _interval(progress, 0, 0.28, Curves.elasticOut);
    final collect = _interval(progress, 0.3, 0.66, Curves.easeInOutCubic);
    final walletIn = _interval(progress, 0.34, 0.58, Curves.easeOutBack);
    final success = _interval(progress, 0.65, 0.88, Curves.elasticOut);
    final sparkle = _interval(progress, 0.7, 0.98, Curves.easeOut);

    return SizedBox(
      key: const ValueKey('two-second-launch-movie'),
      width: 310,
      height: 292,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 55,
            top: 24,
            child: Transform.scale(
              scale: 0.2 + (mascotIn * 0.8),
              child: Transform.rotate(
                angle: (1 - mascotIn) * -0.18,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFFFFFFF), Color(0x66FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 91,
            top: 42 - (mascotIn * 8),
            child: Transform.scale(
              scale: mascotIn.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: math.sin(progress * math.pi * 2) * 0.025,
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(39),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x303268F6),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Image.asset(
                      'assets/branding/kimjod_sloth_icon.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      cacheWidth: 512,
                      cacheHeight: 512,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _FlyingItem(
            icon: Icons.local_cafe_rounded,
            color: const Color(0xFFFFB2C8),
            start: const Offset(12, 96),
            end: const Offset(121, 198),
            progress: collect,
          ),
          _FlyingItem(
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFAEDBFF),
            start: const Offset(251, 82),
            end: const Offset(148, 198),
            progress: collect,
          ),
          _FlyingItem(
            icon: Icons.savings_rounded,
            color: const Color(0xFFFFDD83),
            start: const Offset(35, 190),
            end: const Offset(176, 198),
            progress: collect,
          ),
          Positioned(
            left: 102,
            top: 182,
            child: Transform.scale(
              scale: walletIn.clamp(0.0, 1.0),
              child: Container(
                width: 106,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFBDF4DD),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x24305472), blurRadius: 16),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF176B5E),
                  size: 40,
                ),
              ),
            ),
          ),
          Positioned(
            left: 183,
            top: 170,
            child: Transform.scale(
              scale: success.clamp(0.0, 1.0),
              child: Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFF34B89B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white),
              ),
            ),
          ),
          _Sparkle(
            icon: Icons.favorite_rounded,
            left: 242,
            top: 25,
            color: const Color(0xFFFF83A7),
            scale: sparkle,
          ),
          _Sparkle(
            icon: Icons.auto_awesome_rounded,
            left: 56,
            top: 26,
            color: const Color(0xFFFFC84D),
            scale: sparkle,
          ),
          _Sparkle(
            icon: Icons.star_rounded,
            left: 245,
            top: 210,
            color: const Color(0xFF8E83F5),
            scale: sparkle,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: success.clamp(0.0, 1.0),
              child: Text(
                readyLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF173D45),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlyingItem extends StatelessWidget {
  const _FlyingItem({
    required this.icon,
    required this.color,
    required this.start,
    required this.end,
    required this.progress,
  });

  final IconData icon;
  final Color color;
  final Offset start;
  final Offset end;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final position = Offset.lerp(start, end, progress)!;
    final fade = 1 - _interval(progress, 0.78, 1, Curves.easeIn);
    return Positioned(
      left: position.dx,
      top: position.dy - (math.sin(progress * math.pi) * 28),
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: (1 - progress) * -0.16,
          child: Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x22305472), blurRadius: 12),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF28485A), size: 25),
          ),
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({
    required this.icon,
    required this.left,
    required this.top,
    required this.color,
    required this.scale,
  });

  final IconData icon;
  final double left;
  final double top;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Transform.scale(
        scale: scale.clamp(0.0, 1.0),
        child: Icon(icon, color: color, size: 27),
      ),
    );
  }
}

double _interval(double value, double begin, double end, Curve curve) {
  if (value <= begin) return 0;
  if (value >= end) return 1;
  return curve.transform((value - begin) / (end - begin));
}
