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
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Verdadeiro enquanto a tela que este ícone abre está no topo da pilha —
  /// usado só para destacar visualmente que o botão está "ligado".
  final bool active;

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
              border: Border.all(color: active ? AppColors.accentDim : AppColors.line),
            ),
            child: Icon(icon, size: 16, color: active ? AppColors.accent : AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
