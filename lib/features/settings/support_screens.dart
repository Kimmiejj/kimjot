import 'package:flutter/material.dart';

import '../../shared/widgets/pastel_kit.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SupportScreen(
      status: 'PENDING SYNC',
      smallLabel: 'Budget',
      title: 'คุมงบรายเดือน',
      heroTitle: 'ยังไม่มีงบประมาณ',
      heroMessage: 'เมื่อสร้างงบรายเดือนหรือแยกหมวด ระบบจะแสดง progress จริงจาก Firestore ที่นี่',
      rows: [
        _SupportRowData(icon: 'TT', title: 'งบรวมรายเดือน', subtitle: 'ยังไม่ได้ตั้งค่า'),
        _SupportRowData(icon: 'CT', title: 'งบแยกหมวด', subtitle: 'ยังไม่ได้ตั้งค่า'),
      ],
    );
  }
}

class InstallmentsScreen extends StatelessWidget {
  const InstallmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SupportScreen(
      status: 'USER CONFIRMS',
      smallLabel: 'Installments',
      title: 'รายการผ่อน',
      heroTitle: 'ยังไม่มีรายการผ่อน',
      heroMessage: 'เมื่อเพิ่มแผนผ่อน ระบบจะแสดงงวดที่ต้องจ่ายและให้ผู้ใช้กดยืนยันเอง ไม่มีการสร้าง transaction อัตโนมัติ',
      rows: [
        _SupportRowData(icon: 'AC', title: 'Active plans', subtitle: '0 รายการ'),
        _SupportRowData(icon: 'PA', title: 'Mark as paid', subtitle: 'รอรายการผ่อนจริง'),
      ],
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SupportScreen(
      status: 'SCHEMA SAFE',
      smallLabel: 'Categories',
      title: 'จัดหมวดหมู่',
      heroTitle: 'หมวดเริ่มต้นพร้อมใช้',
      heroMessage: 'Food, Transport, Bills และ Other ถูกใช้กับ transaction จริงแล้ว ส่วน custom category จะต่อกับ Firestore ในขั้นถัดไป',
      rows: [
        _SupportRowData(icon: 'FD', title: 'Food', subtitle: 'default expense'),
        _SupportRowData(icon: 'TR', title: 'Transport', subtitle: 'default expense'),
        _SupportRowData(icon: 'BL', title: 'Bills', subtitle: 'default expense'),
        _SupportRowData(icon: 'OT', title: 'Other', subtitle: 'default'),
      ],
    );
  }
}

class _SupportScreen extends StatelessWidget {
  const _SupportScreen({
    required this.status,
    required this.smallLabel,
    required this.title,
    required this.heroTitle,
    required this.heroMessage,
    required this.rows,
  });

  final String status;
  final String smallLabel;
  final String title;
  final String heroTitle;
  final String heroMessage;
  final List<_SupportRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7FFF4), Color(0xFFEAFBFF), Color(0xFFF7F4FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.72),
                        foregroundColor: const Color(0xFF10233F),
                      ),
                    ),
                    const Spacer(),
                    Text(status, style: _statusStyle),
                  ],
                ),
                const SizedBox(height: 18),
                Text(smallLabel, style: _mutedStyle),
                const SizedBox(height: 4),
                Text(title, style: _pageTitleStyle),
                const SizedBox(height: 20),
                const MascotTip(
                  message:
                      'This section will use your real saved data as soon as you add it.',
                  mood: MascotMood.calm,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: _darkHeroDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heroTitle, style: _heroTitleStyle),
                      const SizedBox(height: 8),
                      Text(heroMessage, style: _heroMessageStyle),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (final row in rows) ...[
                  _SupportRow(data: row),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({required this.data});

  final _SupportRowData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x2E1FC9DC), Color(0x2E3268F6)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                data.icon,
                style: const TextStyle(
                  color: Color(0xFF145CC8),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: _rowTitleStyle),
                const SizedBox(height: 3),
                Text(data.subtitle, style: _mutedStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportRowData {
  const _SupportRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final String title;
  final String subtitle;
}

BoxDecoration _darkHeroDecoration() {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF08154D), Color(0xFF3220AF)],
    ),
    borderRadius: BorderRadius.circular(32),
    boxShadow: const [
      BoxShadow(
        color: Color(0x3D1A2770),
        blurRadius: 38,
        offset: Offset(0, 18),
      ),
    ],
  );
}

const _pageTitleStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 30,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _rowTitleStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 15,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _mutedStyle = TextStyle(
  color: Color(0xFF65748B),
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.35,
  letterSpacing: 0,
);

const _statusStyle = TextStyle(
  color: Color(0xFF10233F),
  fontSize: 12,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _heroTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 24,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _heroMessageStyle = TextStyle(
  color: Color(0xB3FFFFFF),
  fontSize: 14,
  fontWeight: FontWeight.w700,
  height: 1.45,
  letterSpacing: 0,
);
