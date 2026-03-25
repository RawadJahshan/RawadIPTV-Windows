import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Settings'),
      ),
      body: Center(
        child: Text(
          'Settings Page - Add your options here',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
        ),
      ),
    );
  }
}