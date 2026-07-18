import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget kimjodDatePickerTheme(BuildContext context, Widget? child) {
  final baseTheme = Theme.of(context);
  return Theme(
    data: baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: const Color(0xFF3268F6),
        onPrimary: Colors.white,
        surface: const Color(0xFFF8FFFF),
        onSurface: const Color(0xFF10233F),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: const Color(0xFFF8FFFF),
        headerBackgroundColor: const Color(0xFF3268F6),
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        dayShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

class KimjodMascot extends StatelessWidget {
  const KimjodMascot({
    this.size = 88,
    this.mood = MascotMood.happy,
    this.scene = MascotScene.general,
    super.key,
  });

  final double size;
  final MascotMood mood;
  final MascotScene scene;

  @override
  Widget build(BuildContext context) {
    final resolvedScene =
        mood == MascotMood.calm && scene == MascotScene.general
        ? MascotScene.calm
        : scene;
    final decoration = _mascotDecoration(resolvedScene);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            bottom: size * 0.03,
            child: Container(
              width: size * 0.6,
              height: size * 0.6,
              decoration: BoxDecoration(
                color: decoration.backdrop.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: size * 0.04,
            child: Container(
              width: size * 0.5,
              height: size * 0.5,
              decoration: BoxDecoration(
                color: const Color(0xFFC8F6DD).withValues(alpha: 0.88),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: size * 0.78,
              height: size * 0.78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.25),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x29305472),
                    blurRadius: 18,
                    offset: Offset(0, 9),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.23),
                child: Image.asset(
                  'assets/branding/kimjod_sloth_icon.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
          Positioned(
            right: size * 0.01,
            top: size * 0.01,
            child: Container(
              width: size * 0.27,
              height: size * 0.27,
              decoration: BoxDecoration(
                color: decoration.badge,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: size * 0.025),
                boxShadow: const [
                  BoxShadow(color: Color(0x26305472), blurRadius: 8),
                ],
              ),
              child: Icon(
                decoration.icon,
                size: size * 0.16,
                color: decoration.iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum MascotMood { happy, calm }

enum MascotScene {
  general,
  welcome,
  home,
  transaction,
  history,
  settings,
  calm,
}

({Color backdrop, Color badge, Color iconColor, IconData icon})
_mascotDecoration(MascotScene scene) {
  return switch (scene) {
    MascotScene.welcome => (
      backdrop: const Color(0xFFFFD7E5),
      badge: const Color(0xFFFF9CB9),
      iconColor: Colors.white,
      icon: Icons.favorite_rounded,
    ),
    MascotScene.home => (
      backdrop: const Color(0xFFBFEDE1),
      badge: const Color(0xFFA8F2D7),
      iconColor: const Color(0xFF164B43),
      icon: Icons.home_rounded,
    ),
    MascotScene.transaction => (
      backdrop: const Color(0xFFFFE4A8),
      badge: const Color(0xFFFFCF68),
      iconColor: const Color(0xFF704B00),
      icon: Icons.add_card_rounded,
    ),
    MascotScene.history => (
      backdrop: const Color(0xFFD6E8FF),
      badge: const Color(0xFFAED2FF),
      iconColor: const Color(0xFF194F87),
      icon: Icons.receipt_long_rounded,
    ),
    MascotScene.settings => (
      backdrop: const Color(0xFFDAD7FF),
      badge: const Color(0xFFBDB7FF),
      iconColor: const Color(0xFF38306F),
      icon: Icons.settings_rounded,
    ),
    MascotScene.calm => (
      backdrop: const Color(0xFFE2DBFF),
      badge: const Color(0xFFCFC5FF),
      iconColor: const Color(0xFF4D427A),
      icon: Icons.bedtime_rounded,
    ),
    MascotScene.general => (
      backdrop: const Color(0xFFFFD7E5),
      badge: const Color(0xFFFFE59D),
      iconColor: const Color(0xFF765400),
      icon: Icons.auto_awesome_rounded,
    ),
  };
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

class KimjodDialog extends StatelessWidget {
  const KimjodDialog({
    required this.title,
    required this.icon,
    required this.actions,
    this.message,
    this.content,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFEAFBFF), Color(0xFFFFF4FA)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
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
                        colors: [Color(0x3320C997), Color(0x333268F6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: const Color(0xFF145CC8)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        title,
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
              if (message != null) ...[
                const SizedBox(height: 14),
                Text(
                  message!,
                  style: const TextStyle(
                    color: Color(0xFF65748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
              if (content != null) ...[const SizedBox(height: 14), content!],
              const SizedBox(height: 18),
              Row(children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class KimjodDialogAction extends StatelessWidget {
  const KimjodDialogAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = false,
    this.isDestructive = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final foreground = isDestructive
        ? const Color(0xFFB42318)
        : const Color(0xFF16345F);
    final background = isDestructive
        ? const Color(0xFFFFE4E0)
        : Colors.white.withValues(alpha: 0.8);
    final primaryBackground = isDestructive
        ? const Color(0xFFE6453D)
        : const Color(0xFF3268F6);

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 7)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0),
      ),
    );

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: isPrimary
            ? FilledButton(
                onPressed: onPressed,
                style: style.copyWith(
                  backgroundColor: WidgetStatePropertyAll(primaryBackground),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                ),
                child: child,
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: style.copyWith(
                  backgroundColor: WidgetStatePropertyAll(background),
                  foregroundColor: WidgetStatePropertyAll(foreground),
                  side: const WidgetStatePropertyAll(
                    BorderSide(color: Color(0x2E5D81AD)),
                  ),
                ),
                child: child,
              ),
      ),
    );
  }
}

class KimjodDialogTextField extends StatelessWidget {
  const KimjodDialogTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x245D81AD)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: const TextStyle(
          color: Color(0xFF10233F),
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        decoration: InputDecoration.collapsed(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0x8065748B),
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class MascotTip extends StatelessWidget {
  const MascotTip({
    required this.message,
    this.mood = MascotMood.happy,
    this.scene = MascotScene.general,
    super.key,
  });

  final String message;
  final MascotMood mood;
  final MascotScene scene;

  @override
  Widget build(BuildContext context) {
    return PastelHeroCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          KimjodMascot(size: 54, mood: mood, scene: scene),
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
