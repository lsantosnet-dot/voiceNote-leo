import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/output_format.dart';
import '../state/recording_state.dart';
import '../widgets/app_colors.dart';
import '../widgets/record_button.dart';
import '../widgets/top_bar_icon_button.dart';
import '../widgets/waveform.dart';
import 'history_screen.dart';
import 'result_screen.dart';
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

class _TopBar extends StatefulWidget {
  const _TopBar();

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  bool _settingsOpen = false;
  bool _historyOpen = false;

  /// Os ícones funcionam como toggle: abrir (empilha a tela) fica desativado
  /// enquanto ela já está aberta — fechar acontece pela seta de voltar, que
  /// resolve o Future do push e reativa o ícone.
  Future<void> _openSettings(BuildContext context) async {
    if (_settingsOpen) return;
    setState(() => _settingsOpen = true);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) setState(() => _settingsOpen = false);
  }

  Future<void> _openHistory(BuildContext context) async {
    if (_historyOpen) return;
    setState(() => _historyOpen = true);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    if (mounted) setState(() => _historyOpen = false);
  }

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
              active: _settingsOpen,
              onPressed: () => _openSettings(context),
            ),
            const SizedBox(width: 8),
            TopBarIconButton(
              icon: Icons.history,
              tooltip: 'Histórico',
              active: _historyOpen,
              onPressed: () => _openHistory(context),
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
        if (!state.isRecording) ...[
          _FormatPicker(
            selected: state.selectedFormat,
            onSelected: state.selectFormat,
          ),
          const SizedBox(height: 24),
        ],
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
          onTap: () => _handleTap(context, state),
        ),
        const SizedBox(height: 28),
        _Hint(state: state),
      ],
    );
  }

  Future<void> _handleTap(BuildContext context, RecordingState state) async {
    final wasRecording = state.isRecording;
    final duration = state.elapsed;
    await state.toggleRecording();

    if (!wasRecording || state.permissionDenied) return;
    final audioPath = state.lastRecordingPath;
    if (audioPath == null) return;

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(audioPath: audioPath, recordingDuration: duration),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Seletor do formato de saída, escolhido antes de gravar — some enquanto
/// grava, já que passar a valer só na próxima nota seria confuso.
class _FormatPicker extends StatelessWidget {
  const _FormatPicker({required this.selected, required this.onSelected});

  final OutputFormat selected;
  final ValueChanged<OutputFormat> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final format in OutputFormat.values)
          _FormatChip(
            label: format.label,
            selected: format == selected,
            onTap: () => onSelected(format),
          ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDim : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? AppColors.accent : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
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
