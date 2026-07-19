import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Botão circular de gravar/parar, com pulso animado durante a gravação —
/// versão Flutter do `.rec-button` do protótipo.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onTap,
  });

  final bool isRecording;
  final VoidCallback onTap;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isRecording) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isRecording) _buildPulseRing(),
          _buildButton(),
        ],
      ),
    );
  }

  Widget _buildPulseRing() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_pulseController.value);
        final scale = 0.9 + t * 0.35;
        final opacity = 0.7 * (1 - t);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.recDim),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton() {
    return Material(
      color: AppColors.surface2,
      shape: const CircleBorder(side: BorderSide(color: AppColors.line, width: 2)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onTap,
        child: SizedBox(
          width: 104,
          height: 104,
          child: Center(
            child: Semantics(
              button: true,
              label: widget.isRecording ? 'Parar gravação' : 'Iniciar gravação',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.isRecording ? 28 : 36,
                height: widget.isRecording ? 28 : 36,
                decoration: BoxDecoration(
                  color: widget.isRecording ? AppColors.rec : AppColors.accent,
                  borderRadius:
                      BorderRadius.circular(widget.isRecording ? 6 : 10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
