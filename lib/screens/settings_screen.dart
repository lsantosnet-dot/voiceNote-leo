import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gemini_model.dart';
import '../models/output_format.dart';
import '../state/settings_state.dart';
import '../widgets/app_colors.dart';

/// Tela de configurações: chave de API, indicador de status, seletor de
/// modelo e de formato de saída — tudo persistido localmente.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, @visibleForTesting this.debugState});

  /// Permite injetar um [SettingsState] (com repositórios falsos) em
  /// testes de widget.
  @visibleForTesting
  final SettingsState? debugState;

  @override
  Widget build(BuildContext context) {
    if (debugState != null) {
      return ChangeNotifierProvider.value(
        value: debugState!,
        child: const _SettingsScreenBody(),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => SettingsState(),
      child: const _SettingsScreenBody(),
    );
  }
}

class _SettingsScreenBody extends StatefulWidget {
  const _SettingsScreenBody();

  @override
  State<_SettingsScreenBody> createState() => _SettingsScreenBodyState();
}

class _SettingsScreenBodyState extends State<_SettingsScreenBody> {
  final _apiKeyController = TextEditingController();
  bool _synced = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsState>();

    if (!_synced && state.apiKeyDraft.isNotEmpty) {
      _apiKeyController.text = state.apiKeyDraft;
      _synced = true;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text('Configurações'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KeyStatus(configured: state.keyConfigured),
              const SizedBox(height: 18),
              _SectionLabel('Chave da API (AI Studio)'),
              const SizedBox(height: 8),
              _ApiKeyField(
                controller: _apiKeyController,
                obscureText: state.obscureApiKey,
                onChanged: state.updateApiKeyDraft,
                onToggleObscure: state.toggleObscureApiKey,
              ),
              const SizedBox(height: 10),
              const Text(
                'Cada pessoa usa a própria chave gratuita — ela fica salva só '
                'neste aparelho. Gere a sua em aistudio.google.com/apikey.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.55),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 18),
              _SectionLabel('Modelo'),
              const SizedBox(height: 8),
              _ModelDropdown(
                value: state.selectedModel,
                onChanged: state.selectModel,
              ),
              const SizedBox(height: 18),
              _SectionLabel('Formato de saída'),
              const SizedBox(height: 8),
              _OutputFormatDropdown(
                value: state.selectedFormat,
                onChanged: state.selectFormat,
              ),
              const SizedBox(height: 18),
              const Text(
                'No nível gratuito do Google AI Studio, os áudios e textos '
                'processados podem ser usados pelo Google para melhorar os '
                'modelos.',
                style: TextStyle(fontSize: 11, color: Color(0xFF565A62), height: 1.5),
              ),
              const Spacer(),
              const SizedBox(height: 18),
              _SaveButton(onPressed: () => _save(context, state)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, SettingsState state) async {
    await state.save();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas')),
    );
  }
}

class _KeyStatus extends StatelessWidget {
  const _KeyStatus({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    final color = configured ? AppColors.accent : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: configured ? AppColors.accentDim : AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: configured
                  ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            configured ? 'Chave configurada' : 'Nenhuma chave configurada',
            style: TextStyle(fontSize: 12.5, color: color),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10.5,
        letterSpacing: 0.8,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _ApiKeyField extends StatelessWidget {
  const _ApiKeyField({
    required this.controller,
    required this.obscureText,
    required this.onChanged,
    required this.onToggleObscure,
  });

  final TextEditingController controller;
  final bool obscureText;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.text),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        hintText: 'AIzaSy…',
        hintStyle: const TextStyle(color: Color(0xFF565A62)),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentDim),
        ),
        suffixIcon: IconButton(
          onPressed: onToggleObscure,
          tooltip: obscureText ? 'Mostrar chave' : 'Ocultar chave',
          icon: Icon(
            obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textMuted,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({required this.value, required this.onChanged});

  final GeminiModel value;
  final ValueChanged<GeminiModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsDropdown<GeminiModel>(
      value: value,
      items: GeminiModel.values,
      labelOf: (model) => model.label,
      onChanged: onChanged,
    );
  }
}

class _OutputFormatDropdown extends StatelessWidget {
  const _OutputFormatDropdown({required this.value, required this.onChanged});

  final OutputFormat value;
  final ValueChanged<OutputFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsDropdown<OutputFormat>(
      value: value,
      items: OutputFormat.values,
      labelOf: (format) => format.label,
      onChanged: onChanged,
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: AppColors.surface2,
      style: const TextStyle(fontSize: 13.5, color: AppColors.text),
      icon: const Icon(Icons.expand_more, color: AppColors.textMuted, size: 20),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentDim),
        ),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(value: item, child: Text(labelOf(item))),
      ],
      onChanged: (item) {
        if (item != null) onChanged(item);
      },
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: const Color(0xFF08201C),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      child: const Text('Salvar'),
    );
  }
}
