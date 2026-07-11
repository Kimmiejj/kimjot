import 'package:flutter/material.dart';

import 'pastel_kit.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7FFF4), Color(0xFFEAFBFF), Color(0xFFF7F4FF)],
          ),
        ),
        child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KimjodMascot(size: 82, mood: MascotMood.calm),
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
      ),
    );
  }
}
