import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../models/gemini_model.dart';
import '../models/output_format.dart';
import 'api_key_repository.dart';

/// Erro da camada de API, já com mensagem pronta pra exibir na UI —
/// sem termos técnicos.
sealed class TranscriptionException implements Exception {
  const TranscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MissingApiKeyException extends TranscriptionException {
  const MissingApiKeyException()
      : super(
          'Nenhuma chave de API configurada. Adicione sua chave do Gemini '
          'nas configurações para gravar notas.',
        );
}

class InvalidApiKeyException extends TranscriptionException {
  const InvalidApiKeyException()
      : super(
          'A chave de API informada não é válida. Confira a chave nas '
          'configurações.',
        );
}

class QuotaExceededException extends TranscriptionException {
  const QuotaExceededException()
      : super(
          'Limite gratuito do Gemini foi atingido por hoje. Tente '
          'novamente mais tarde.',
        );
}

class NoInternetException extends TranscriptionException {
  const NoInternetException()
      : super('Sem conexão com a internet. Verifique sua rede e tente novamente.');
}

class TranscriptionFailedException extends TranscriptionException {
  const TranscriptionFailedException()
      : super('Não foi possível processar o áudio agora. Tente novamente.');
}

/// Assinatura da chamada real ao Gemini — isolada para permitir troca por um
/// dublê nos testes, já que [GenerativeModel] é `final` e não pode ser
/// estendida fora do pacote `google_generative_ai`.
typedef ContentGenerator = Future<GenerateContentResponse> Function({
  required String apiKey,
  required String model,
  required Iterable<Content> prompt,
});

Future<GenerateContentResponse> _defaultContentGenerator({
  required String apiKey,
  required String model,
  required Iterable<Content> prompt,
}) {
  return GenerativeModel(model: model, apiKey: apiKey).generateContent(prompt);
}

/// Camada de API: monta a chamada `generateContent` do Gemini com o áudio
/// gravado em `inline_data` + um prompt de transcrição e estruturação, e
/// devolve o texto já pronto. Erros de rede, chave e quota são traduzidos
/// em [TranscriptionException]s com mensagem amigável.
class GeminiTranscriptionService {
  GeminiTranscriptionService({
    ApiKeyRepository? apiKeyRepository,
    ContentGenerator generateContent = _defaultContentGenerator,
  })  : _apiKeyRepository = apiKeyRepository ?? ApiKeyRepository(),
        _generateContent = generateContent;

  final ApiKeyRepository _apiKeyRepository;
  final ContentGenerator _generateContent;

  /// Envia [audioFile] para o Gemini e retorna o texto transcrito e
  /// estruturado no [outputFormat] pedido.
  Future<String> transcribeAndStructure({
    required File audioFile,
    GeminiModel model = GeminiModel.flash,
    OutputFormat outputFormat = OutputFormat.topics,
  }) async {
    final apiKey = await _apiKeyRepository.read();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const MissingApiKeyException();
    }

    final bytes = await audioFile.readAsBytes();
    final mimeType = _mimeTypeFor(audioFile.path);

    try {
      final response = await _generateContent(
        apiKey: apiKey.trim(),
        model: model.apiModelId,
        prompt: [
          Content.multi([
            TextPart(_promptFor(outputFormat)),
            DataPart(mimeType, bytes),
          ]),
        ],
      );

      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        throw const TranscriptionFailedException();
      }
      return text;
    } on InvalidApiKey {
      throw const InvalidApiKeyException();
    } on ServerException catch (e) {
      if (_looksLikeQuotaError(e.message)) {
        throw const QuotaExceededException();
      }
      throw const TranscriptionFailedException();
    } on SocketException {
      throw const NoInternetException();
    } on http.ClientException {
      throw const NoInternetException();
    } on GenerativeAIException {
      throw const TranscriptionFailedException();
    }
  }

  bool _looksLikeQuotaError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('resource_exhausted') ||
        lower.contains('rate limit') ||
        lower.contains('429');
  }

  String _mimeTypeFor(String path) {
    if (path.endsWith('.wav')) return 'audio/wav';
    if (path.endsWith('.3gp')) return 'audio/3gpp';
    return 'audio/mp4'; // .m4a (aacLc), o formato usado pela gravação.
  }

  String _promptFor(OutputFormat format) {
    const transcriptionInstruction =
        'Transcreva fielmente a fala em português do Brasil contida no áudio '
        'a seguir. Não inclua a transcrição literal na resposta, apenas o '
        'conteúdo já organizado conforme pedido abaixo.';

    return switch (format) {
      OutputFormat.topics => '''
$transcriptionInstruction

Organize o conteúdo transcrito em tópicos claros, usando exatamente esta
estrutura de resposta (sem comentários extras, sem markdown de código):

Resumo
Um parágrafo curto resumindo o assunto.

Pontos principais
- Primeiro ponto
- Segundo ponto
- (quantos forem necessários)

Próxima ação
Descreva a ação, tarefa ou pendência mencionada. Se nenhuma ação foi
mencionada, escreva "Nenhuma ação identificada."
''',
      OutputFormat.freeText => '''
$transcriptionInstruction

Reescreva o conteúdo como um texto corrido, natural e bem pontuado, sem
tópicos, marcadores ou títulos, mantendo o sentido original da fala.
''',
      OutputFormat.meetingMinutes => '''
$transcriptionInstruction

Organize o conteúdo no formato de uma ata de reunião, usando as seções
abaixo (omita qualquer seção sem conteúdo correspondente):

Contexto
Participantes ou assunto da reunião, se mencionados.

Discussão
Principais pontos discutidos.

Decisões
Decisões tomadas.

Próximos passos
Ações e responsáveis, se mencionados.
''',
    };
  }
}
