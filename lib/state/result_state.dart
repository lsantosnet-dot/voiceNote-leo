import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/gemini_transcription_service.dart';
import '../services/note_repository.dart';

enum ResultPhase { loading, ready, error }

/// Estado da tela de resultado: dispara o envio do áudio já gravado pro
/// Gemini, mantém o texto editável, permite reprocessar (mesmo áudio, sem
/// regravar) e salva a nota automaticamente no histórico local.
class ResultState extends ChangeNotifier {
  ResultState({
    required this.audioPath,
    required this.recordingDuration,
    GeminiTranscriptionService? transcriptionService,
    NoteRepository? noteRepository,
  })  : _transcriptionService = transcriptionService ?? GeminiTranscriptionService(),
        _noteRepository = noteRepository ?? NoteRepository() {
    initialLoad = _process();
  }

  /// Future do processamento inicial disparado pelo construtor — exposto só
  /// para testes conseguirem esperar por ele de forma determinística.
  @visibleForTesting
  late final Future<void> initialLoad;

  static const _skippableHeaders = {
    'Resumo',
    'Pontos principais',
    'Próxima ação',
    'Contexto',
    'Discussão',
    'Decisões',
    'Próximos passos',
  };

  final String audioPath;
  final Duration recordingDuration;
  final DateTime timestamp = DateTime.now();

  final GeminiTranscriptionService _transcriptionService;
  final NoteRepository _noteRepository;

  ResultPhase _phase = ResultPhase.loading;
  String _text = '';
  String? _errorMessage;
  String? _reprocessError;
  bool _isReprocessing = false;
  int _contentVersion = 0;
  Note? _note;
  Timer? _saveDebounce;

  ResultPhase get phase => _phase;
  String get text => _text;
  String? get errorMessage => _errorMessage;
  String? get reprocessError => _reprocessError;
  bool get isReprocessing => _isReprocessing;

  /// Incrementa toda vez que o texto muda por causa da API (carregamento
  /// inicial ou reprocessamento) — a tela usa isso pra saber quando deve
  /// atualizar o campo editável sem atropelar o que o usuário está digitando.
  int get contentVersion => _contentVersion;

  Future<void> retryInitial() => _process();

  Future<void> _process() async {
    _phase = ResultPhase.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _transcriptionService.transcribeAndStructure(
        audioFile: File(audioPath),
      );
      _text = result;
      _contentVersion++;
      _phase = ResultPhase.ready;
      await _persist();
    } on TranscriptionException catch (e) {
      _errorMessage = e.message;
      _phase = ResultPhase.error;
    }
    notifyListeners();
  }

  /// Reenvia o mesmo áudio em cache pro Gemini, sem regravar.
  Future<void> reprocess() async {
    if (_isReprocessing) return;
    _isReprocessing = true;
    _reprocessError = null;
    notifyListeners();

    try {
      final result = await _transcriptionService.transcribeAndStructure(
        audioFile: File(audioPath),
      );
      _text = result;
      _contentVersion++;
      await _persist();
    } on TranscriptionException catch (e) {
      _reprocessError = e.message;
    }

    _isReprocessing = false;
    notifyListeners();
  }

  /// Chamado a cada edição do usuário no card de texto.
  void updateText(String newText) {
    _text = newText;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    final title = _deriveTitle(_text);
    final note = _note;
    if (note == null) {
      final newNote = Note(
        id: timestamp.microsecondsSinceEpoch.toString(),
        title: title,
        structuredText: _text,
        timestamp: timestamp,
      );
      _note = newNote;
      await _noteRepository.add(newNote);
    } else {
      note.title = title;
      note.structuredText = _text;
      await note.save();
    }
  }

  String _deriveTitle(String text) {
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim().replaceFirst(RegExp(r'^[-•]\s*'), '');
      if (line.isEmpty || _skippableHeaders.contains(line)) continue;
      return line.length > 60 ? '${line.substring(0, 57)}…' : line;
    }
    return 'Nota de voz';
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    unawaited(_discardAudio());
    super.dispose();
  }

  Future<void> _discardAudio() async {
    final file = File(audioPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
