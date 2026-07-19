import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive/hive.dart';
import 'package:voicenote_leo/models/note.dart';
import 'package:voicenote_leo/screens/result_screen.dart';
import 'package:voicenote_leo/services/api_key_repository.dart';
import 'package:voicenote_leo/services/gemini_transcription_service.dart';
import 'package:voicenote_leo/services/note_repository.dart';
import 'package:voicenote_leo/services/settings_repository.dart';
import 'package:voicenote_leo/state/result_state.dart';

class _FakeApiKeyRepository extends ApiKeyRepository {
  @override
  Future<String?> read() async => 'chave-valida';
}

GenerateContentResponse _successResponse(String text) {
  return GenerateContentResponse(
    [Candidate(Content.text(text), null, null, null, null)],
    null,
  );
}

GeminiTranscriptionService _fakeService(
  Future<GenerateContentResponse> Function() respond,
) {
  return GeminiTranscriptionService(
    apiKeyRepository: _FakeApiKeyRepository(),
    generateContent: ({required apiKey, required model, required prompt}) => respond(),
  );
}

/// Constrói o [ResultState] dentro de [WidgetTester.runAsync]: o
/// processamento inicial é disparado no construtor e usa Future/IO reais
/// (chamada de API + gravação no Hive), que não resolvem sozinhos dentro da
/// zona FakeAsync dos testes de widget.
Future<ResultState> _buildAndAwaitState(
  WidgetTester tester, {
  required String audioPath,
  required Duration recordingDuration,
  required GeminiTranscriptionService transcriptionService,
}) async {
  late ResultState state;
  await tester.runAsync(() async {
    state = ResultState(
      audioPath: audioPath,
      recordingDuration: recordingDuration,
      transcriptionService: transcriptionService,
      noteRepository: NoteRepository(),
    );
    await state.initialLoad;
  });
  return state;
}

void main() {
  late Directory tempDir;
  late File audioFile;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('result_screen_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(NoteAdapter());
  });

  setUp(() async {
    await Hive.openBox<Note>(NoteRepository.boxName);
    await Hive.openBox(SettingsRepository.boxName);
    audioFile = File(
      '${tempDir.path}/audio_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    await audioFile.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    final box = Hive.box<Note>(NoteRepository.boxName);
    await box.clear();
    await box.close();
    final settingsBox = Hive.box(SettingsRepository.boxName);
    await settingsBox.clear();
    await settingsBox.close();
    if (await audioFile.exists()) await audioFile.delete();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('mostra indicador de carregamento antes da resposta chegar', (tester) async {
    // O Completer nunca é resolvido neste teste: só interessa checar a UI
    // enquanto o processamento ainda está pendente.
    final completer = Completer<GenerateContentResponse>();
    late ResultState state;
    await tester.runAsync(() async {
      state = ResultState(
        audioPath: audioFile.path,
        recordingDuration: Duration.zero,
        transcriptionService: _fakeService(() => completer.future),
        noteRepository: NoteRepository(),
      );
    });
    addTearDown(() => tester.runAsync(() async => state.dispose()));

    await tester.pumpWidget(MaterialApp(
      home: ResultScreen(
        audioPath: audioFile.path,
        recordingDuration: Duration.zero,
        debugState: state,
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Transformando sua gravação em texto…'), findsOneWidget);
  });

  testWidgets('mostra o texto estruturado editável e as ações', (tester) async {
    final state = await _buildAndAwaitState(
      tester,
      audioPath: audioFile.path,
      recordingDuration: const Duration(seconds: 38),
      transcriptionService: _fakeService(
        () async => _successResponse('Resumo\nReunião sobre o projeto.'),
      ),
    );
    addTearDown(() => tester.runAsync(() async => state.dispose()));

    await tester.pumpWidget(MaterialApp(
      home: ResultScreen(
        audioPath: audioFile.path,
        recordingDuration: const Duration(seconds: 38),
        debugState: state,
      ),
    ));

    expect(find.text('Texto estruturado'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Resumo\nReunião sobre o projeto.'),
      findsOneWidget,
    );
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Reprocessar'), findsOneWidget);
    expect(find.text('↺ Nova gravação'), findsOneWidget);
  });

  testWidgets('editar o texto no card atualiza o estado', (tester) async {
    final state = await _buildAndAwaitState(
      tester,
      audioPath: audioFile.path,
      recordingDuration: Duration.zero,
      transcriptionService: _fakeService(
        () async => _successResponse('Resumo\nOriginal.'),
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: ResultScreen(
        audioPath: audioFile.path,
        recordingDuration: Duration.zero,
        debugState: state,
      ),
    ));

    await tester.enterText(find.byType(TextField), 'Resumo\nEditado pelo usuário.');

    expect(state.text, 'Resumo\nEditado pelo usuário.');

    // Cancela o Timer de debounce (salvamento no Hive) explicitamente —
    // esse comportamento já é coberto pelos testes de ResultState; aqui só
    // interessa a fiação entre o TextField e o estado.
    state.dispose();
  });

  testWidgets('erro inicial mostra mensagem e botão de tentar novamente', (tester) async {
    final state = await _buildAndAwaitState(
      tester,
      audioPath: audioFile.path,
      recordingDuration: Duration.zero,
      transcriptionService: _fakeService(() async {
        throw const NoInternetException();
      }),
    );
    addTearDown(() => tester.runAsync(() async => state.dispose()));

    await tester.pumpWidget(MaterialApp(
      home: ResultScreen(
        audioPath: audioFile.path,
        recordingDuration: Duration.zero,
        debugState: state,
      ),
    ));

    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('botão reprocessar aciona o reprocessamento e atualiza o texto', (tester) async {
    var callCount = 0;
    final state = await _buildAndAwaitState(
      tester,
      audioPath: audioFile.path,
      recordingDuration: Duration.zero,
      transcriptionService: _fakeService(() async {
        callCount++;
        return _successResponse('Resumo\nVersão $callCount.');
      }),
    );
    addTearDown(() => tester.runAsync(() async => state.dispose()));

    await tester.pumpWidget(MaterialApp(
      home: ResultScreen(
        audioPath: audioFile.path,
        recordingDuration: Duration.zero,
        debugState: state,
      ),
    ));
    expect(find.widgetWithText(TextField, 'Resumo\nVersão 1.'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Reprocessar'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Resumo\nVersão 2.'), findsOneWidget);
  });

  testWidgets('seta de voltar aparece quando a tela é aberta fora da raiz', (tester) async {
    final state = await _buildAndAwaitState(
      tester,
      audioPath: audioFile.path,
      recordingDuration: Duration.zero,
      transcriptionService: _fakeService(
        () async => _successResponse('Resumo\nOk.'),
      ),
    );
    addTearDown(() => tester.runAsync(() async => state.dispose()));

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ResultScreen(
                    audioPath: audioFile.path,
                    recordingDuration: Duration.zero,
                    debugState: state,
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
  });
}
