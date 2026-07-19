import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Barras finas que sobem e descem com a amplitude do áudio — a versão
/// Flutter da `.waveform` do protótipo.
class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.levels, required this.isRecording});

  final List<double> levels;
  final bool isRecording;

  static const double _maxBarHeight = 48;
  static const double _minBarHeight = 8;

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? AppColors.rec : AppColors.textMuted;

    return SizedBox(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final level in levels)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: 3,
                height: _minBarHeight + level * (_maxBarHeight - _minBarHeight),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
