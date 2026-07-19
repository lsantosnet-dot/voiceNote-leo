import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive/hive.dart';
import 'package:voicenote_leo/models/note.dart';
import 'package:voicenote_leo/services/api_key_repository.dart';
import 'package:voicenote_leo/services/gemini_transcription_service.dart';
import 'package:voicenote_leo/services/note_repository.dart';
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

void main() {
  late Directory tempDir;
  late File audioFile;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('result_state_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(NoteAdapter());
  });

  setUp(() async {
    await Hive.openBox<Note>(NoteRepository.boxName);
    audioFile = File(
      '${tempDir.path}/audio_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    await audioFile.writeAsBytes([1, 2, 3, 4]);
  });

  tearDown(() async {
    final box = Hive.box<Note>(NoteRepository.boxName);
    await box.clear();
    await box.close();
    if (await audioFile.exists()) await audioFile.delete();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('processa o áudio ao iniciar e salva a nota no histórico', () async {
    final state = ResultState(
      audioPath: audioFile.path,
      recordingDuration: const Duration(seconds: 12),
      transcriptionService: _fakeService(
        () async => _successResponse('Resumo\nConteúdo de teste.'),
      ),
      noteRepository: NoteRepository(),
    );
    await state.initialLoad;

    expect(state.phase, ResultPhase.ready);
    expect(state.text, 'Resumo\nConteúdo de teste.');

    final notes = NoteRepository().getAll();
    expect(notes, hasLength(1));
    expect(notes.first.structuredText, 'Resumo\nConteúdo de teste.');
    expect(notes.first.title, 'Conteúdo de teste.');

    state.dispose();
  });

  test('erro no processamento inicial vai para o estado de erro', () async {
    final state = ResultState(
      audioPath: audioFile.path,
      recordingDuration: Duration.zero,
      transcriptionService: _fakeService(() async {
        throw const NoInternetException();
      }),
      noteRepository: NoteRepository(),
    );
    await state.initialLoad;

    expect(state.phase, ResultPhase.error);
    expect(state.errorMessage, isNotNull);
    expect(NoteRepository().getAll(), isEmpty);

    state.dispose();
  });

  test('tentar novamente depois de um erro processa com sucesso', () async {
    var callCount = 0;
    final state = ResultState(
      audioPath: audioFile.path,
      recordingDuration: Duration.zero,
      transcriptionService: _fakeService(() async {
        callCount++;
        if (callCount == 1) throw const NoInternetException();
        return _successResponse('Resumo\nFuncionou na segunda tentativa.');
      }),
      noteRepository: NoteRepository(),
    );
    await state.initialLoad;
    expect(state.phase, ResultPhase.error);

    await state.retryInitial();

    expect(state.phase, ResultPhase.ready);
    expect(state.text, 'Resumo\nFuncionou na segunda tentativa.');
    expect(NoteRepository().getAll(), hasLength(1));

    state.dispose();
  });

  test('reprocessar atualiza o texto e a mesma nota, sem duplicar', () async {
    var callCount = 0;
    final state = ResultState(
      audioPath: audioFile.path,
      recordingDuration: const Duration(seconds: 5),
      transcriptionService: _fakeService(() async {
        callCount++;
        return _successResponse('Resumo\nVersão $callCount.');
      }),
      noteRepository: NoteRepository(),
    );
    await state.initialLoad;
    expect(state.text, 'Resumo\nVersão 1.');

    await state.reprocess();

    expect(state.phase, ResultPhase.ready);
    expect(state.isReprocessing, isFalse);
    expect(state.text, 'Resumo\nVersão 2.');
    expect(state.reprocessError, isNull);

    final notes = NoteRepository().getAll();
    expect(notes, hasLength(1));
    expect(notes.first.structuredText, 'Resumo\nVersão 2.');

    state.dispose();
  });

  test('erro ao reprocessar mantém o texto anterior e expõe o erro', () async {
    var callCount = 0;
    final state = ResultState(
      audioPath: audioFile.path,
      recordingDuration: Duration.zero,
      transcriptionService: _fakeService(() async {
        callCount++;
        if (callCount == 1) return _successResponse('Resumo\nOriginal.');
        throw const QuotaExceededException();
      }),
      noteRepository: NoteRepository(),
    );
    await state.initialLoad;

    await state.reprocess();

    expect(state.text, 'Resumo\nOriginal.');
    expect(state.reprocessError, isNotNull);
    expect(state.phase, ResultPhase.ready);

    state.dispose();
  });

  test('editar o texto atualiza a nota salva (com debounce)', () async {
    final state = ResultState(
      audioPath: audioFile.path,
      recordingDuration: Duration.zero,
      transcriptionService: _fakeService(
        () async => _successResponse('Resumo\nTexto original.'),
      ),
      noteRepository: NoteRepository(),
    );
    await state.initialLoad;

    state.updateText('Resumo\nTexto corrigido pelo usuário.');
    expect(state.text, 'Resumo\nTexto corrigido pelo usuário.');

    await Future<void>.delayed(const Duration(milliseconds: 600));

    final notes = NoteRepository().getAll();
    expect(notes, hasLength(1));
    expect(notes.first.structuredText, 'Resumo\nTexto corrigido pelo usuário.');
    expect(notes.first.title, 'Texto corrigido pelo usuário.');

    state.dispose();
  });

  test('descarta o áudio em cache ao ser descartado (dispose)', () async {
    final state = ResultState(
      audioPath: audioFile.path,
      recordingDuration: Duration.zero,
      transcriptionService: _fakeService(
        () async => _successResponse('Resumo\nOk.'),
      ),
      noteRepository: NoteRepository(),
    );
    await state.initialLoad;
    expect(await audioFile.exists(), isTrue);

    state.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await audioFile.exists(), isFalse);
  });
}
