import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF62E4B6),
              Color(0xFF1FC9DC),
              Color(0xFF6A4DF4),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x403268F6),
              blurRadius: 38,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'k',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}
