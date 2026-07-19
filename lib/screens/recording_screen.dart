import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/recording_state.dart';
import '../widgets/app_colors.dart';
import '../widgets/record_button.dart';
import '../widgets/top_bar_icon_button.dart';
import '../widgets/waveform.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Tela principal (raiz) do app: gravação, nos estados ocioso e gravando.
class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key, @visibleForTesting this.debugState});

  /// Permite injetar um [RecordingState] (com um serviço falso) em testes de
  /// widget, sem depender do canal de plataforma real do pacote `record`.
  @visibleForTesting
  final RecordingState? debugState;

  @override
  Widget build(BuildContext context) {
    if (debugState != null) {
      return ChangeNotifierProvider.value(
        value: debugState!,
        child: const _RecordingScreenBody(),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => RecordingState(),
      child: const _RecordingScreenBody(),
    );
  }
}

class _RecordingScreenBody extends StatelessWidget {
  const _RecordingScreenBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              const _TopBar(),
              const SizedBox(height: 8),
              Expanded(child: _CaptureView()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final isRecording = context.select<RecordingState, bool>((s) => s.isRecording);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording ? AppColors.rec : AppColors.textMuted,
                boxShadow: isRecording
                    ? [BoxShadow(color: AppColors.rec.withValues(alpha: 0.6), blurRadius: 8)]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'NOTA DE VOZ',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        Row(
          children: [
            TopBarIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Configurações',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: 8),
            TopBarIconButton(
              icon: Icons.history,
              tooltip: 'Histórico',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CaptureView extends StatelessWidget {
  const _CaptureView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RecordingState>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Waveform(levels: state.levels, isRecording: state.isRecording),
        const SizedBox(height: 28),
        Text(
          _formatDuration(state.elapsed),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 28,
            letterSpacing: 1.5,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 28),
        RecordButton(
          isRecording: state.isRecording,
          onTap: () => state.toggleRecording(),
        ),
        const SizedBox(height: 28),
        _Hint(state: state),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.state});

  final RecordingState state;

  @override
  Widget build(BuildContext context) {
    if (state.permissionDenied) {
      return Column(
        children: [
          const Text(
            'Não conseguimos acessar o microfone.\nPermita o acesso nas configurações do Android para gravar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => state.toggleRecording(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accentDim),
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }

    final message = state.isRecording
        ? 'Toque para parar.\nGravando sua nota de voz…'
        : 'Toque para gravar.\nFale naturalmente — a IA organiza depois.';
    final boldWord = state.isRecording ? 'Gravando' : 'Fale naturalmente';

    return _RichHint(text: message, boldWord: boldWord);
  }
}

/// Renderiza o hint com uma palavra/trecho em destaque, como no protótipo
/// (`.hint b`).
class _RichHint extends StatelessWidget {
  const _RichHint({required this.text, required this.boldWord});

  final String text;
  final String boldWord;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5);
    const boldStyle = TextStyle(
      fontSize: 13,
      color: AppColors.text,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );

    final boldIndex = text.indexOf(boldWord);
    if (boldIndex == -1) {
      return Text(text, textAlign: TextAlign.center, style: baseStyle);
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, boldIndex)),
          TextSpan(text: boldWord, style: boldStyle),
          TextSpan(text: text.substring(boldIndex + boldWord.length)),
        ],
      ),
    );
  }
}
