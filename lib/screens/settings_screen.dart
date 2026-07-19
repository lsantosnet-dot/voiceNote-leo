import 'package:flutter/material.dart';

import '../widgets/app_colors.dart';

/// Tela de configurações — ainda vazia, apenas navegável a partir da tela
/// principal.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text('Configurações'),
      ),
      body: const Center(
        child: Text(
          'Em breve.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
