import 'package:flutter/foundation.dart';

import '../models/gemini_model.dart';
import '../models/output_format.dart';
import '../services/api_key_repository.dart';
import '../services/settings_repository.dart';

/// Estado da tela de configurações: chave de API (rascunho local até
/// salvar), modelo do Gemini e formato de saída escolhidos.
class SettingsState extends ChangeNotifier {
  SettingsState({
    ApiKeyRepository? apiKeyRepository,
    SettingsRepository? settingsRepository,
  })  : _apiKeyRepository = apiKeyRepository ?? ApiKeyRepository(),
        _settingsRepository = settingsRepository ?? SettingsRepository() {
    initialLoad = _loadInitial();
  }

  /// Future do carregamento inicial disparado pelo construtor — exposto só
  /// para testes conseguirem esperar por ele de forma determinística.
  @visibleForTesting
  late final Future<void> initialLoad;

  final ApiKeyRepository _apiKeyRepository;
  final SettingsRepository _settingsRepository;

  bool _keyConfigured = false;
  String _apiKeyDraft = '';
  bool _obscureApiKey = true;
  GeminiModel _selectedModel = GeminiModel.flash;
  OutputFormat _selectedFormat = OutputFormat.topics;

  bool get keyConfigured => _keyConfigured;
  String get apiKeyDraft => _apiKeyDraft;
  bool get obscureApiKey => _obscureApiKey;
  GeminiModel get selectedModel => _selectedModel;
  OutputFormat get selectedFormat => _selectedFormat;

  Future<void> _loadInitial() async {
    final key = await _apiKeyRepository.read();
    _apiKeyDraft = key ?? '';
    _keyConfigured = key != null && key.trim().isNotEmpty;
    _selectedModel = _settingsRepository.getModel();
    _selectedFormat = _settingsRepository.getOutputFormat();
    notifyListeners();
  }

  void updateApiKeyDraft(String value) {
    _apiKeyDraft = value;
    notifyListeners();
  }

  void toggleObscureApiKey() {
    _obscureApiKey = !_obscureApiKey;
    notifyListeners();
  }

  void selectModel(GeminiModel model) {
    _selectedModel = model;
    notifyListeners();
  }

  void selectFormat(OutputFormat format) {
    _selectedFormat = format;
    notifyListeners();
  }

  /// Salva a chave de API (secure storage) e as preferências de modelo e
  /// formato (Hive).
  Future<void> save() async {
    final trimmed = _apiKeyDraft.trim();
    if (trimmed.isEmpty) {
      await _apiKeyRepository.clear();
      _keyConfigured = false;
    } else {
      await _apiKeyRepository.save(trimmed);
      _keyConfigured = true;
    }
    await _settingsRepository.setModel(_selectedModel);
    await _settingsRepository.setOutputFormat(_selectedFormat);
    notifyListeners();
  }
}
