import 'package:flutter/material.dart';

import '../widgets/app_colors.dart';

/// Tela de histórico — ainda vazia, apenas navegável a partir da tela
/// principal.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text('Histórico'),
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
