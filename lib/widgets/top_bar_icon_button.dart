import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Botão quadrado com cantos arredondados usado no topo das telas
/// (ícones de histórico/configurações/voltar), no estilo `.icon-nav` do
/// protótipo.
class TopBarIconButton extends StatelessWidget {
  const TopBarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, size: 16, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
