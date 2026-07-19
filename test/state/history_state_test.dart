import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voicenote_leo/models/note.dart';
import 'package:voicenote_leo/services/note_repository.dart';
import 'package:voicenote_leo/state/history_state.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('history_state_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(NoteAdapter());
  });

  setUp(() async {
    await Hive.openBox<Note>(NoteRepository.boxName);
  });

  tearDown(() async {
    final box = Hive.box<Note>(NoteRepository.boxName);
    await box.clear();
    await box.close();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Note buildNote(String id, {DateTime? timestamp}) {
    return Note(
      id: id,
      title: 'Nota $id',
      structuredText: 'Resumo\nConteúdo da nota $id.',
      timestamp: timestamp ?? DateTime(2026, 7, 19, 10, int.parse(id)),
    );
  }

  test('começa vazio quando não há notas no Hive', () {
    final state = HistoryState(noteRepository: NoteRepository());
    expect(state.notes, isEmpty);
    expect(state.expandedId, isNull);
  });

  test('carrega as notas do Hive, mais recentes primeiro', () async {
    final repository = NoteRepository();
    await repository.add(buildNote('01', timestamp: DateTime(2026, 7, 19, 10, 0)));
    await repository.add(buildNote('02', timestamp: DateTime(2026, 7, 19, 12, 0)));

    final state = HistoryState(noteRepository: repository);

    expect(state.notes, hasLength(2));
    expect(state.notes.first.id, '02');
    expect(state.notes.last.id, '01');
  });

  test('toggleExpanded expande e recolhe o card', () async {
    final repository = NoteRepository();
    await repository.add(buildNote('01'));
    final state = HistoryState(noteRepository: repository);

    state.toggleExpanded('01');
    expect(state.expandedId, '01');

    state.toggleExpanded('01');
    expect(state.expandedId, isNull);
  });

  test('expandir outro card troca qual está expandido', () async {
    final repository = NoteRepository();
    await repository.add(buildNote('01'));
    await repository.add(buildNote('02'));
    final state = HistoryState(noteRepository: repository);

    state.toggleExpanded('01');
    expect(state.expandedId, '01');

    state.toggleExpanded('02');
    expect(state.expandedId, '02');
  });

  test('delete remove a nota do Hive imediatamente e da lista', () async {
    final repository = NoteRepository();
    await repository.add(buildNote('01'));
    await repository.add(buildNote('02'));
    final state = HistoryState(noteRepository: repository);

    await state.delete('01');

    expect(state.notes.map((n) => n.id), ['02']);
    expect(repository.getAll().map((n) => n.id), ['02']);
  });

  test('excluir o card expandido também recolhe', () async {
    final repository = NoteRepository();
    await repository.add(buildNote('01'));
    final state = HistoryState(noteRepository: repository);

    state.toggleExpanded('01');
    expect(state.expandedId, '01');

    await state.delete('01');

    expect(state.expandedId, isNull);
    expect(state.notes, isEmpty);
  });
}
