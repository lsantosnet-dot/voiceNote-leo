import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/note_repository.dart';

/// Estado da tela de histórico: lista as notas salvas, controla qual card
/// está expandido e trata a exclusão.
class HistoryState extends ChangeNotifier {
  HistoryState({NoteRepository? noteRepository})
      : _repository = noteRepository ?? NoteRepository() {
    _notes = _repository.getAll();
  }

  final NoteRepository _repository;
  late List<Note> _notes;
  String? _expandedId;

  List<Note> get notes => _notes;
  String? get expandedId => _expandedId;

  void toggleExpanded(String id) {
    _expandedId = _expandedId == id ? null : id;
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    _notes = _notes.where((note) => note.id != id).toList();
    if (_expandedId == id) _expandedId = null;
    notifyListeners();
  }
}
