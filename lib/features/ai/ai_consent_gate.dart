import 'package:flutter/material.dart';

import '../../app/app_language.dart';
import 'ai_settings_screen.dart';
import 'ai_settings_store.dart';

Future<bool> ensureAiAllowed(BuildContext context) async {
  await AiSettingsStore.instance.load();
  if (AiSettingsStore.instance.aiConsent) return true;
  if (!context.mounted) return false;

  final openSettings = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6D5CE7)),
      title: Text(
        context.strings.isThai ? 'กรุณาเปิดใช้งาน AI ก่อน' : 'Enable AI first',
      ),
      content: Text(
        context.strings.isThai
            ? 'ฟีเจอร์นี้จะส่งข้อมูลที่จำเป็นไปยัง Kimjod AI เมื่อคุณสั่งใช้งานเท่านั้น เปิดสิทธิ์ได้ในหน้าตั้งค่า AI'
            : 'This feature sends the required data to Kimjod AI only when you use it. Enable permission in AI settings first.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.strings.isThai ? 'ไว้ก่อน' : 'Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.strings.isThai ? 'เปิดการตั้งค่า' : 'Open settings'),
        ),
      ],
    ),
  );
  if (openSettings == true && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => const AiSettingsScreen()),
    );
  }
  return AiSettingsStore.instance.aiConsent;
}
