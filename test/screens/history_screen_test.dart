import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voicenote_leo/models/note.dart';
import 'package:voicenote_leo/screens/history_screen.dart';
import 'package:voicenote_leo/services/note_repository.dart';
import 'package:voicenote_leo/state/history_state.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('history_screen_test');
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
      title: 'Reunião sobre o projeto $id',
      structuredText: 'Resumo\nConversa sobre o projeto $id.\n\nPontos principais\n- Item $id',
      timestamp: timestamp ?? DateTime(2026, 7, 19, 9, int.parse(id)),
    );
  }

  testWidgets('mostra a mensagem de estado vazio quando não há notas', (tester) async {
    final state = HistoryState(noteRepository: NoteRepository());

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(debugState: state),
    ));

    expect(find.textContaining('Nenhuma gravação ainda'), findsOneWidget);
  });

  testWidgets('lista os cards colapsados com título, prévia e data/hora', (tester) async {
    final repository = NoteRepository();
    await tester.runAsync(() => repository.add(buildNote('01')));
    final state = HistoryState(noteRepository: repository);

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(debugState: state),
    ));

    expect(find.text('Reunião sobre o projeto 01'), findsOneWidget);
    expect(find.textContaining('Conversa sobre o projeto 01'), findsOneWidget);
    expect(find.textContaining('19/07'), findsOneWidget);
    // Ainda colapsado: nem o texto completo nem as ações aparecem.
    expect(find.text('Copiar'), findsNothing);
    expect(find.text('Excluir'), findsNothing);
  });

  testWidgets('tocar no card expande mostrando texto completo e ações', (tester) async {
    final repository = NoteRepository();
    await tester.runAsync(() => repository.add(buildNote('01')));
    final state = HistoryState(noteRepository: repository);

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(debugState: state),
    ));

    await tester.tap(find.text('Reunião sobre o projeto 01'));
    await tester.pumpAndSettle();

    // "- Item 01" (com o marcador) só existe no texto completo — a prévia
    // remove o marcador de lista.
    expect(find.textContaining('- Item 01'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);

    // Tocar de novo recolhe.
    await tester.tap(find.text('Reunião sobre o projeto 01'));
    await tester.pumpAndSettle();

    expect(find.text('Copiar'), findsNothing);
  });

  testWidgets('excluir remove a nota do Hive imediatamente e some da lista', (tester) async {
    final repository = NoteRepository();
    await tester.runAsync(() async {
      await repository.add(buildNote('01'));
      await repository.add(buildNote('02'));
    });
    final state = HistoryState(noteRepository: repository);

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(debugState: state),
    ));

    await tester.tap(find.text('Reunião sobre o projeto 01'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Excluir'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('Reunião sobre o projeto 01'), findsNothing);
    expect(find.text('Reunião sobre o projeto 02'), findsOneWidget);
    expect(repository.getAll().map((n) => n.id), ['02']);
  });
}
