import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/result_state.dart';
import '../widgets/app_colors.dart';

/// Tela de resultado: mostra o texto transcrito e estruturado pelo Gemini,
/// editável, com ações de copiar, compartilhar, reprocessar e nova gravação.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.audioPath,
    required this.recordingDuration,
    @visibleForTesting this.debugState,
  });

  final String audioPath;
  final Duration recordingDuration;

  /// Permite injetar um [ResultState] (com dependências falsas) em testes
  /// de widget, sem tocar na API real do Gemini ou no Hive.
  @visibleForTesting
  final ResultState? debugState;

  @override
  Widget build(BuildContext context) {
    if (debugState != null) {
      return ChangeNotifierProvider.value(
        value: debugState!,
        child: const _ResultScreenBody(),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => ResultState(
        audioPath: audioPath,
        recordingDuration: recordingDuration,
      ),
      child: const _ResultScreenBody(),
    );
  }
}

class _ResultScreenBody extends StatefulWidget {
  const _ResultScreenBody();

  @override
  State<_ResultScreenBody> createState() => _ResultScreenBodyState();
}

class _ResultScreenBodyState extends State<_ResultScreenBody> {
  final _controller = TextEditingController();
  int _syncedVersion = -1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ResultState>();

    if (state.contentVersion != _syncedVersion) {
      _syncedVersion = state.contentVersion;
      _controller.text = state.text;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text('Nota de voz'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: switch (state.phase) {
            ResultPhase.loading => const _LoadingView(),
            ResultPhase.error => _ErrorView(
                message: state.errorMessage!,
                onRetry: state.retryInitial,
              ),
            ResultPhase.ready => _ReadyView(controller: _controller, state: state),
          },
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          SizedBox(height: 20),
          Text(
            'Transformando sua gravação em texto…',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.rec, size: 36),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accentDim),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.controller, required this.state});

  final TextEditingController controller;
  final ResultState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'Texto estruturado',
              style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              _formatMeta(state),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: controller,
              onChanged: state.updateText,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(color: AppColors.text, fontSize: 14.5, height: 1.65),
              cursorColor: AppColors.accent,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.edit_outlined, size: 12, color: AppColors.textMuted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Toque no texto pra ajustar antes de copiar ou enviar',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActionButton.primary(
                icon: Icons.copy_outlined,
                label: 'Copiar',
                onPressed: () => _copy(context, controller.text),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton.secondary(
                icon: Icons.ios_share,
                label: 'Compartilhar',
                onPressed: () => _share(controller.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _GhostButton(
                icon: Icons.refresh,
                label: 'Reprocessar',
                loading: state.isReprocessing,
                onPressed: state.isReprocessing ? null : () => _reprocess(context, state),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GhostButton(
                label: '↺ Nova gravação',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Reprocessar usa o mesmo áudio já gravado — não precisa falar de novo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF565A62)),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado para a área de transferência')),
    );
  }

  Future<void> _share(String text) {
    return SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _reprocess(BuildContext context, ResultState state) async {
    await state.reprocess();
    if (!context.mounted) return;
    final error = state.reprocessError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  String _formatMeta(ResultState state) {
    final date = state.timestamp;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final duration = state.recordingDuration;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$day/$month · $minutes:$seconds';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton.primary({required this.icon, required this.label, required this.onPressed})
      : _primary = true;

  const _ActionButton.secondary({required this.icon, required this.label, required this.onPressed})
      : _primary = false;

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool _primary;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary ? AppColors.accent : AppColors.surface2,
        foregroundColor: _primary ? const Color(0xFF08201C) : AppColors.text,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: _primary ? BorderSide.none : const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    this.icon,
    required this.label,
    this.loading = false,
    required this.onPressed,
  });

  final IconData? icon;
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
      ),
      child: loading
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
                SizedBox(width: 8),
                Text('Reprocessando…'),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14),
                  const SizedBox(width: 6),
                ],
                Text(label),
              ],
            ),
    );
  }
}
