import 'dart:math' as math;

import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({required this.message, super.key});

  final String message;

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
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final value = Curves.easeInOut.transform(_controller.value);
                  return Transform.translate(
                    offset: Offset(0, -5 * math.sin(value * math.pi)),
                    child: Transform.rotate(
                      angle: (value - 0.5) * 0.035,
                      child: Transform.scale(
                        scale: 0.98 + (value * 0.025),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      key: const ValueKey('loading-sloth-icon'),
                      width: 122,
                      height: 122,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x363268F6),
                            blurRadius: 34,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(34),
                        child: Image.asset(
                          'assets/branding/kimjod_sloth_icon.png',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    const Positioned(
                      right: -13,
                      top: 8,
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF83A7),
                        size: 27,
                      ),
                    ),
                    const Positioned(
                      left: -15,
                      bottom: 13,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFFFC84D),
                        size: 29,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF0F766E),
                  backgroundColor: Color(0x5574DCC0),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF31506F),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
