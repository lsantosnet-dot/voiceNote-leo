import 'package:flutter_test/flutter_test.dart';
import 'package:voicenote_leo/models/gemini_model.dart';
import 'package:voicenote_leo/models/output_format.dart';
import 'package:voicenote_leo/services/api_key_repository.dart';
import 'package:voicenote_leo/services/settings_repository.dart';
import 'package:voicenote_leo/state/settings_state.dart';

class _FakeApiKeyRepository extends ApiKeyRepository {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> save(String apiKey) async => stored = apiKey.trim();

  @override
  Future<void> clear() async => stored = null;
}

class _FakeSettingsRepository extends SettingsRepository {
  GeminiModel model = GeminiModel.flash;
  OutputFormat format = OutputFormat.topics;

  @override
  GeminiModel getModel() => model;

  @override
  Future<void> setModel(GeminiModel value) async => model = value;

  @override
  OutputFormat getOutputFormat() => format;

  @override
  Future<void> setOutputFormat(OutputFormat value) async => format = value;
}

void main() {
  test('sem chave salva, começa com status não configurado', () async {
    final state = SettingsState(
      apiKeyRepository: _FakeApiKeyRepository(),
      settingsRepository: _FakeSettingsRepository(),
    );
    await state.initialLoad;

    expect(state.keyConfigured, isFalse);
    expect(state.apiKeyDraft, isEmpty);
    expect(state.selectedModel, GeminiModel.flash);
    expect(state.selectedFormat, OutputFormat.topics);
  });

  test('carrega a chave e as preferências já salvas', () async {
    final apiKeyRepo = _FakeApiKeyRepository()..stored = 'chave-existente';
    final settingsRepo = _FakeSettingsRepository()
      ..model = GeminiModel.pro
      ..format = OutputFormat.meetingMinutes;

    final state = SettingsState(apiKeyRepository: apiKeyRepo, settingsRepository: settingsRepo);
    await state.initialLoad;

    expect(state.keyConfigured, isTrue);
    expect(state.apiKeyDraft, 'chave-existente');
    expect(state.selectedModel, GeminiModel.pro);
    expect(state.selectedFormat, OutputFormat.meetingMinutes);
  });

  test('obscureApiKey começa true e alterna ao chamar toggle', () async {
    final state = SettingsState(
      apiKeyRepository: _FakeApiKeyRepository(),
      settingsRepository: _FakeSettingsRepository(),
    );
    await state.initialLoad;

    expect(state.obscureApiKey, isTrue);
    state.toggleObscureApiKey();
    expect(state.obscureApiKey, isFalse);
  });

  test('save() grava a chave e as preferências escolhidas', () async {
    final apiKeyRepo = _FakeApiKeyRepository();
    final settingsRepo = _FakeSettingsRepository();
    final state = SettingsState(apiKeyRepository: apiKeyRepo, settingsRepository: settingsRepo);
    await state.initialLoad;

    state.updateApiKeyDraft('AIzaSyNovaChave');
    state.selectModel(GeminiModel.flashLite);
    state.selectFormat(OutputFormat.freeText);

    await state.save();

    expect(apiKeyRepo.stored, 'AIzaSyNovaChave');
    expect(settingsRepo.model, GeminiModel.flashLite);
    expect(settingsRepo.format, OutputFormat.freeText);
    expect(state.keyConfigured, isTrue);
  });

  test('save() com chave em branco limpa a chave e marca como não configurada', () async {
    final apiKeyRepo = _FakeApiKeyRepository()..stored = 'chave-antiga';
    final settingsRepo = _FakeSettingsRepository();
    final state = SettingsState(apiKeyRepository: apiKeyRepo, settingsRepository: settingsRepo);
    await state.initialLoad;
    expect(state.keyConfigured, isTrue);

    state.updateApiKeyDraft('   ');
    await state.save();

    expect(apiKeyRepo.stored, isNull);
    expect(state.keyConfigured, isFalse);
  });
}
