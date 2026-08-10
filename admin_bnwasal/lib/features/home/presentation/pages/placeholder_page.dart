import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderPage({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.3))),
          SizedBox(height: 8),
          Text('قيد التطوير', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.15))),
        ],
      ),
    );
  }
}
