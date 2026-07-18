import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_language.dart';

class AppExitAnimation extends StatefulWidget {
  const AppExitAnimation({super.key});

  static const duration = Duration(milliseconds: 1900);

  @override
  State<AppExitAnimation> createState() => _AppExitAnimationState();
}

class _AppExitAnimationState extends State<AppExitAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppExitAnimation.duration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Material(
      color: const Color(0xFFF7F5EF),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD9FFF0), Color(0xFFE7FBFF), Color(0xFFFFF1F7)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final value = _controller.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  ..._buildBackgroundBubbles(value),
                  _buildMascot(value),
                  ..._buildTransactionPills(value),
                  _buildWallet(value),
                  ..._buildCuteParticles(value),
                  _buildSavedCheck(value),
                  _buildFarewellBubble(
                    value,
                    title: strings.isThai
                        ? '\u0E40\u0E01\u0E47\u0E1A\u0E43\u0E2B\u0E49\u0E40\u0E23\u0E35\u0E22\u0E1A\u0E23\u0E49\u0E2D\u0E22\u0E41\u0E25\u0E49\u0E27\u0E19\u0E49\u0E32'
                        : 'All tucked away!',
                    subtitle: strings.isThai
                        ? '\u0E44\u0E27\u0E49\u0E40\u0E08\u0E2D\u0E01\u0E31\u0E19\u0E43\u0E2B\u0E21\u0E48\u0E19\u0E30'
                        : 'See you soon',
                  ),
                  _buildAppIcon(value),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundBubbles(double value) {
    return [
      _PastelBubble(
        alignment: const Alignment(-1.05, -0.88),
        size: 170,
        color: const Color(0xFFBDF5D8),
        offset: Offset(0, math.sin(value * math.pi * 2) * 9),
      ),
      _PastelBubble(
        alignment: const Alignment(1.12, -0.28),
        size: 144,
        color: const Color(0xFFCFE9FF),
        offset: Offset(0, math.cos(value * math.pi * 2) * 8),
      ),
      _PastelBubble(
        alignment: const Alignment(-1.0, 0.92),
        size: 190,
        color: const Color(0xFFFFDCE9),
        offset: Offset(math.sin(value * math.pi) * 8, 0),
      ),
    ];
  }

  Widget _buildMascot(double value) {
    final enter = Curves.elasticOut.transform(_interval(value, 0.00, 0.24));
    final leave = Curves.easeInBack.transform(_interval(value, 0.76, 0.90));
    final opacity = (_interval(value, 0.00, 0.08) - leave).clamp(0.0, 1.0);
    final bounce = math.sin(_interval(value, 0.24, 0.74) * math.pi * 4) * 3;
    final wave = math.sin(_interval(value, 0.48, 0.76) * math.pi * 6) * 0.025;

    return Align(
      alignment: const Alignment(0, -0.16),
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, (58 * (1 - enter)) - (30 * leave) + bounce),
          child: Transform.rotate(
            angle: (-0.045 * (1 - enter)) + wave,
            child: Transform.scale(
              scale: (0.58 + (0.42 * enter)) * (1 - (leave * 0.28)),
              child: Container(
                key: const ValueKey('exit-sloth-mascot'),
                width: 224,
                height: 224,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(66),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.92),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26305472),
                      blurRadius: 36,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(59),
                  child: Image.asset(
                    'assets/branding/kimjod_sloth_mascot.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTransactionPills(double value) {
    return [
      _TransactionPill(
        icon: Icons.local_cafe_rounded,
        color: const Color(0xFFFF8E79),
        alignment: const Alignment(-0.70, -0.42),
        progress: _interval(value, 0.06, 0.48),
      ),
      _TransactionPill(
        icon: Icons.shopping_bag_rounded,
        color: const Color(0xFF7868E8),
        alignment: const Alignment(0.70, -0.28),
        progress: _interval(value, 0.12, 0.51),
      ),
      _TransactionPill(
        icon: Icons.savings_rounded,
        color: const Color(0xFFE4A728),
        alignment: const Alignment(-0.60, 0.07),
        progress: _interval(value, 0.18, 0.54),
      ),
    ];
  }

  Widget _buildWallet(double value) {
    final enter = Curves.easeOutBack.transform(_interval(value, 0.22, 0.38));
    final leave = Curves.easeInCubic.transform(_interval(value, 0.70, 0.82));

    return Align(
      alignment: const Alignment(0, 0.30),
      child: Opacity(
        opacity: (enter - leave).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: (0.72 + (0.28 * enter)) * (1 - (leave * 0.18)),
          child: Container(
            key: const ValueKey('exit-wallet'),
            width: 98,
            height: 66,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF62E4B6), Color(0xFF1FC9DC)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3320BFA9),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCuteParticles(double value) {
    return [
      _CuteParticle(
        icon: Icons.favorite_rounded,
        color: const Color(0xFFFF7FA3),
        target: const Alignment(-0.56, -0.52),
        progress: _interval(value, 0.31, 0.67),
        rotation: -0.18,
      ),
      _CuteParticle(
        icon: Icons.star_rounded,
        color: const Color(0xFFFFC84D),
        target: const Alignment(0.58, -0.54),
        progress: _interval(value, 0.36, 0.70),
        rotation: 0.22,
      ),
      _CuteParticle(
        icon: Icons.favorite_rounded,
        color: const Color(0xFFFFA7BE),
        target: const Alignment(0.72, 0.04),
        progress: _interval(value, 0.42, 0.74),
        rotation: 0.16,
      ),
      _CuteParticle(
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF7C6CE7),
        target: const Alignment(-0.68, -0.02),
        progress: _interval(value, 0.39, 0.73),
        rotation: -0.20,
      ),
    ];
  }

  Widget _buildSavedCheck(double value) {
    final enter = Curves.elasticOut.transform(_interval(value, 0.44, 0.56));
    final leave = Curves.easeIn.transform(_interval(value, 0.66, 0.76));

    return Align(
      alignment: const Alignment(0.23, 0.22),
      child: Opacity(
        opacity: (enter - leave).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: 0.10 * (1 - enter),
          child: Transform.scale(
            scale: enter * (1 - (leave * 0.22)),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF0F766E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x330F766E),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFarewellBubble(
    double value, {
    required String title,
    required String subtitle,
  }) {
    final enter = Curves.easeOutBack.transform(_interval(value, 0.45, 0.57));
    final leave = Curves.easeInCubic.transform(_interval(value, 0.73, 0.84));

    return Align(
      alignment: const Alignment(0, 0.70),
      child: Opacity(
        opacity: (enter - leave).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (18 * (1 - enter)) - (10 * leave)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 292),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F305472),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF7FA3),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        key: const ValueKey('exit-title'),
                        style: const TextStyle(
                          color: Color(0xFF172826),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF65748B),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.waving_hand_rounded,
                  color: Color(0xFFE9A93A),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon(double value) {
    final progress = Curves.elasticOut.transform(_interval(value, 0.79, 1.00));

    return Align(
      alignment: const Alignment(0, -0.04),
      child: Opacity(
        opacity: _interval(value, 0.79, 0.88),
        child: Transform.rotate(
          angle: -0.10 * (1 - progress),
          child: Transform.scale(
            scale: 0.52 + (0.48 * progress),
            child: Container(
              key: const ValueKey('exit-app-icon'),
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(31),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x403268F6),
                    blurRadius: 40,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(29),
                child: Image.asset(
                  'assets/branding/kimjod_sloth_icon.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _interval(double value, double begin, double end) {
    return ((value - begin) / (end - begin)).clamp(0.0, 1.0);
  }
}

class _PastelBubble extends StatelessWidget {
  const _PastelBubble({
    required this.alignment,
    required this.size,
    required this.color,
    required this.offset,
  });

  final Alignment alignment;
  final double size;
  final Color color;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.46),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TransactionPill extends StatelessWidget {
  const _TransactionPill({
    required this.icon,
    required this.color,
    required this.alignment,
    required this.progress,
  });

  final IconData icon;
  final Color color;
  final Alignment alignment;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final enter = Curves.easeOutBack.transform((progress * 2).clamp(0.0, 1.0));
    final collect = Curves.easeInCubic.transform(
      ((progress - 0.5) * 2).clamp(0.0, 1.0),
    );
    final currentAlignment = Alignment.lerp(
      alignment,
      const Alignment(0, 0.30),
      collect,
    )!;

    return Align(
      alignment: currentAlignment,
      child: Opacity(
        opacity: (enter * (1 - collect)).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: (1 - collect) * 0.08,
          child: Transform.scale(
            scale: enter * (1 - (collect * 0.70)),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F305472),
                    blurRadius: 18,
                    offset: Offset(0, 9),
                  ),
                ],
              ),
              child: Icon(icon, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _CuteParticle extends StatelessWidget {
  const _CuteParticle({
    required this.icon,
    required this.color,
    required this.target,
    required this.progress,
    required this.rotation,
  });

  final IconData icon;
  final Color color;
  final Alignment target;
  final double progress;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final travel = Curves.easeOutCubic.transform(progress);
    final opacity = math.sin(progress * math.pi).clamp(0.0, 1.0);
    final alignment = Alignment.lerp(
      const Alignment(0, -0.08),
      target,
      travel,
    )!;

    return Align(
      alignment: alignment,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rotation * travel,
          child: Transform.scale(
            scale: 0.55 + (0.45 * math.sin(progress * math.pi)),
            child: Icon(icon, color: color, size: 30),
          ),
        ),
      ),
    );
  }
}
