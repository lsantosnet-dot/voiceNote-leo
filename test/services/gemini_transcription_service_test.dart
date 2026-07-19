import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:voicenote_leo/models/output_format.dart';
import 'package:voicenote_leo/services/api_key_repository.dart';
import 'package:voicenote_leo/services/gemini_transcription_service.dart';

class _FakeApiKeyRepository extends ApiKeyRepository {
  _FakeApiKeyRepository(this._key);
  final String? _key;

  @override
  Future<String?> read() async => _key;
}

GenerateContentResponse _successResponse(String text) {
  return GenerateContentResponse(
    [Candidate(Content.text(text), null, null, null, null)],
    null,
  );
}

void main() {
  late File audioFile;

  setUp(() async {
    audioFile = File(
      '${Directory.systemTemp.path}/gemini_service_test_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    await audioFile.writeAsBytes([1, 2, 3, 4]);
  });

  tearDown(() async {
    if (await audioFile.exists()) await audioFile.delete();
  });

  test('sem chave configurada lança MissingApiKeyException', () async {
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository(null),
      generateContent: ({required apiKey, required model, required prompt}) {
        fail('não deveria chamar a API sem chave');
      },
    );

    await expectLater(
      service.transcribeAndStructure(audioFile: audioFile),
      throwsA(isA<MissingApiKeyException>()),
    );
  });

  test('chave em branco também é tratada como ausente', () async {
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository('   '),
      generateContent: ({required apiKey, required model, required prompt}) {
        fail('não deveria chamar a API com chave em branco');
      },
    );

    await expectLater(
      service.transcribeAndStructure(audioFile: audioFile),
      throwsA(isA<MissingApiKeyException>()),
    );
  });

  test('resposta com texto é retornada normalmente', () async {
    late Iterable<Content> capturedPrompt;
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository('chave-valida'),
      generateContent: ({required apiKey, required model, required prompt}) async {
        capturedPrompt = prompt;
        return _successResponse('Resumo\nConversa sobre o projeto.');
      },
    );

    final result = await service.transcribeAndStructure(audioFile: audioFile);

    expect(result, 'Resumo\nConversa sobre o projeto.');
    // O áudio deve ir como inline_data (DataPart) junto ao prompt de texto.
    final parts = capturedPrompt.single.parts;
    expect(parts.whereType<DataPart>(), hasLength(1));
    expect(parts.whereType<TextPart>(), hasLength(1));
  });

  test('chave inválida (InvalidApiKey) vira InvalidApiKeyException', () async {
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository('chave-invalida'),
      generateContent: ({required apiKey, required model, required prompt}) {
        throw InvalidApiKey('API key not valid');
      },
    );

    await expectLater(
      service.transcribeAndStructure(audioFile: audioFile),
      throwsA(isA<InvalidApiKeyException>()),
    );
  });

  test('erro de quota (RESOURCE_EXHAUSTED) vira QuotaExceededException', () async {
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository('chave-valida'),
      generateContent: ({required apiKey, required model, required prompt}) {
        throw ServerException(
          'Quota exceeded for quota metric... RESOURCE_EXHAUSTED',
        );
      },
    );

    await expectLater(
      service.transcribeAndStructure(audioFile: audioFile),
      throwsA(isA<QuotaExceededException>()),
    );
  });

  test('erro de servidor sem relação com quota vira TranscriptionFailedException', () async {
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository('chave-valida'),
      generateContent: ({required apiKey, required model, required prompt}) {
        throw ServerException('Internal error');
      },
    );

    await expectLater(
      service.transcribeAndStructure(audioFile: audioFile),
      throwsA(isA<TranscriptionFailedException>()),
    );
  });

  test('sem internet (SocketException) vira NoInternetException', () async {
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository('chave-valida'),
      generateContent: ({required apiKey, required model, required prompt}) {
        throw const SocketException('Failed host lookup');
      },
    );

    await expectLater(
      service.transcribeAndStructure(audioFile: audioFile),
      throwsA(isA<NoInternetException>()),
    );
  });

  test('erro de cliente HTTP também vira NoInternetException', () async {
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository('chave-valida'),
      generateContent: ({required apiKey, required model, required prompt}) {
        throw http.ClientException('Connection refused');
      },
    );

    await expectLater(
      service.transcribeAndStructure(audioFile: audioFile),
      throwsA(isA<NoInternetException>()),
    );
  });

  test('resposta vazia vira TranscriptionFailedException', () async {
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository('chave-valida'),
      generateContent: ({required apiKey, required model, required prompt}) async {
        return _successResponse('');
      },
    );

    await expectLater(
      service.transcribeAndStructure(audioFile: audioFile),
      throwsA(isA<TranscriptionFailedException>()),
    );
  });

  test('prompt de tópicos pede estrutura de Resumo/Pontos principais', () async {
    late Iterable<Content> capturedPrompt;
    final service = GeminiTranscriptionService(
      apiKeyRepository: _FakeApiKeyRepository('chave-valida'),
      generateContent: ({required apiKey, required model, required prompt}) async {
        capturedPrompt = prompt;
        return _successResponse('ok');
      },
    );

    await service.transcribeAndStructure(
      audioFile: audioFile,
      outputFormat: OutputFormat.topics,
    );

    final textPart = capturedPrompt.single.parts.whereType<TextPart>().single;
    expect(textPart.text, contains('Pontos principais'));
    expect(textPart.text, contains('Resumo'));
  });
}
