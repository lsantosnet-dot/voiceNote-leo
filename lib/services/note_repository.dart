import 'package:hive/hive.dart';

import '../models/note.dart';

/// Histórico local de notas, guardado num box do Hive (aberto em `main.dart`
/// antes do app rodar).
class NoteRepository {
  static const boxName = 'notes';

  Box<Note> get _box => Hive.box<Note>(boxName);

  Future<void> add(Note note) => _box.put(note.id, note);

  Future<void> delete(String id) => _box.delete(id);

  /// Notas mais recentes primeiro.
  List<Note> getAll() {
    final notes = _box.values.toList();
    notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notes;
  }
}
