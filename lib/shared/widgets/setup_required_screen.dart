import 'package:flutter/material.dart';

import 'pastel_kit.dart';

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({required this.error, super.key});

  final String error;

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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: KimjodMascot(
                    size: 88,
                    mood: MascotMood.calm,
                    scene: MascotScene.settings,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Firebase setup required',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF071844),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add google-services.json for package com.kimjot.project, add SHA-1/SHA-256 in Firebase Console, and enable Google sign-in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF65748B), height: 1.45),
                ),
                const SizedBox(height: 18),
                SelectableText(
                  error,
                  style: const TextStyle(
                    color: Color(0xFF8F2440),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
