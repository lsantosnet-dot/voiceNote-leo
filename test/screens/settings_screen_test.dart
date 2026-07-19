import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicenote_leo/models/gemini_model.dart';
import 'package:voicenote_leo/models/output_format.dart';
import 'package:voicenote_leo/screens/settings_screen.dart';
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

Future<SettingsState> _buildState(
  WidgetTester tester, {
  required ApiKeyRepository apiKeyRepository,
  required SettingsRepository settingsRepository,
}) async {
  late SettingsState state;
  await tester.runAsync(() async {
    state = SettingsState(
      apiKeyRepository: apiKeyRepository,
      settingsRepository: settingsRepository,
    );
    await state.initialLoad;
  });
  return state;
}

void main() {
  testWidgets('mostra status "nenhuma chave configurada" quando vazio', (tester) async {
    final state = await _buildState(
      tester,
      apiKeyRepository: _FakeApiKeyRepository(),
      settingsRepository: _FakeSettingsRepository(),
    );

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(debugState: state)));

    expect(find.text('Nenhuma chave configurada'), findsOneWidget);
    expect(find.text('Gemini 2.5 Flash — rápido, recomendado'), findsOneWidget);
    expect(find.text('Tópicos'), findsOneWidget);
  });

  testWidgets('mostra status configurado quando já existe chave salva', (tester) async {
    final state = await _buildState(
      tester,
      apiKeyRepository: _FakeApiKeyRepository()..stored = 'AIzaSyChaveExistente',
      settingsRepository: _FakeSettingsRepository(),
    );

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(debugState: state)));

    expect(find.text('Chave configurada'), findsOneWidget);
  });

  testWidgets('campo de chave começa oculto e o botão de olho alterna a visibilidade', (tester) async {
    final state = await _buildState(
      tester,
      apiKeyRepository: _FakeApiKeyRepository()..stored = 'AIzaSyChaveExistente',
      settingsRepository: _FakeSettingsRepository(),
    );

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(debugState: state)));

    final fieldBefore = tester.widget<TextField>(find.byType(TextField));
    expect(fieldBefore.obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    final fieldAfter = tester.widget<TextField>(find.byType(TextField));
    expect(fieldAfter.obscureText, isFalse);
  });

  testWidgets('escolher outro modelo e formato e salvar persiste tudo', (tester) async {
    final apiKeyRepo = _FakeApiKeyRepository();
    final settingsRepo = _FakeSettingsRepository();
    final state = await _buildState(
      tester,
      apiKeyRepository: apiKeyRepo,
      settingsRepository: settingsRepo,
    );

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(debugState: state)));

    await tester.enterText(find.byType(TextField), 'AIzaSyChaveDigitada');

    await tester.tap(find.text('Gemini 2.5 Flash — rápido, recomendado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini 2.5 Pro — mais preciso, limite diário menor').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tópicos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ata de reunião').last);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Salvar'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(apiKeyRepo.stored, 'AIzaSyChaveDigitada');
    expect(settingsRepo.model, GeminiModel.pro);
    expect(settingsRepo.format, OutputFormat.meetingMinutes);
    expect(find.text('Configurações salvas'), findsOneWidget);
  });
}
