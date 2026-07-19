import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voicenote_leo/models/note.dart';
import 'package:voicenote_leo/screens/history_screen.dart';
import 'package:voicenote_leo/screens/recording_screen.dart';
import 'package:voicenote_leo/screens/result_screen.dart';
import 'package:voicenote_leo/screens/settings_screen.dart';
import 'package:voicenote_leo/services/note_repository.dart';
import 'package:voicenote_leo/services/settings_repository.dart';
import 'package:voicenote_leo/state/history_state.dart';
import 'package:voicenote_leo/state/result_state.dart';
import 'package:voicenote_leo/widgets/top_bar_icon_button.dart';

/// Conta quantas vezes uma rota foi empilhada — usado para confirmar que
/// os ícones de histórico/configurações não empilham a mesma tela duas
/// vezes quando tocados repetidamente antes da transição terminar.
class _CountingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
  }
}

Note _note(String id) {
  return Note(
    id: id,
    title: 'Nota $id',
    structuredText: 'Resumo\nConteúdo $id.',
    timestamp: DateTime(2026, 7, 19, 10, int.parse(id)),
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('navigation_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(NoteAdapter());

    // `SettingsScreen()`/`ApiKeyRepository()` reais tocam o canal de
    // plataforma do flutter_secure_storage — mocka pra não precisar de
    // debugState nos testes de navegação que só olham pro AppBar/ícones.
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  setUp(() async {
    await Hive.openBox<Note>(NoteRepository.boxName);
    await Hive.openBox(SettingsRepository.boxName);
  });

  tearDown(() async {
    final notesBox = Hive.box<Note>(NoteRepository.boxName);
    await notesBox.clear();
    await notesBox.close();
    final settingsBox = Hive.box(SettingsRepository.boxName);
    await settingsBox.clear();
    await settingsBox.close();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('seta de voltar', () {
    testWidgets('não aparece na tela principal (raiz)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecordingScreen()));

      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('aparece no Histórico quando aberto a partir de outra tela', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
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

    testWidgets('aparece nas Configurações quando abertas a partir de outra tela', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
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

    testWidgets('aparece no Resultado quando aberto a partir de outra tela', (tester) async {
      // Construído dentro de runAsync: o construtor de ResultState dispara
      // o processamento (Future/IO reais) que não resolve sozinho dentro da
      // zona FakeAsync dos testes de widget. A chave mockada retorna null,
      // então cai no estado de erro — o que já basta pra checar a AppBar.
      late ResultState state;
      await tester.runAsync(() async {
        state = ResultState(
          audioPath: '${tempDir.path}/inexistente.m4a',
          recordingDuration: Duration.zero,
          noteRepository: NoteRepository(),
        );
        await state.initialLoad;
      });
      addTearDown(() => tester.runAsync(() async => state.dispose()));

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(
                      audioPath: state.audioPath,
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
  });

  group('ícones de histórico/configurações como toggle', () {
    testWidgets('tocar duas vezes rápido no ícone de histórico só empilha uma tela', (tester) async {
      final observer = _CountingNavigatorObserver();
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: const RecordingScreen(),
      ));
      final baseline = observer.pushCount;

      // Invoca o callback diretamente (em vez de `tester.tap` duas vezes):
      // assim que a primeira chamada dispara a transição de rota, o ícone
      // pode ficar geometricamente encoberto pela nova tela entrando,
      // fazendo um segundo `tap()` real não acertar o alvo — o que
      // mascararia o teste (passaria mesmo sem o guard funcionar). Chamar o
      // callback direto testa o guard de verdade, não a geometria do toque.
      final button = tester.widget<TopBarIconButton>(
        find.byWidgetPredicate((w) => w is TopBarIconButton && w.tooltip == 'Histórico'),
      );
      button.onPressed();
      button.onPressed();
      await tester.pumpAndSettle();

      expect(observer.pushCount - baseline, 1);
      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('depois de fechar (voltar), o ícone de histórico abre de novo', (tester) async {
      final observer = _CountingNavigatorObserver();
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: const RecordingScreen(),
      ));
      final baseline = observer.pushCount;

      await tester.tap(find.byTooltip('Histórico'));
      await tester.pumpAndSettle();
      expect(observer.pushCount - baseline, 1);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Histórico'));
      await tester.pumpAndSettle();

      expect(observer.pushCount - baseline, 2);
    });

    testWidgets('tocar duas vezes rápido no ícone de configurações só empilha uma tela', (tester) async {
      final observer = _CountingNavigatorObserver();
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: const RecordingScreen(),
      ));
      final baseline = observer.pushCount;

      final button = tester.widget<TopBarIconButton>(
        find.byWidgetPredicate((w) => w is TopBarIconButton && w.tooltip == 'Configurações'),
      );
      button.onPressed();
      button.onPressed();
      await tester.pumpAndSettle();

      expect(observer.pushCount - baseline, 1);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('fluxo gravar → resultado → histórico', () {
    testWidgets('nota salva pelo Resultado (via NoteRepository) aparece no Histórico', (tester) async {
      // ResultState salva a nota assim que a tela de resultado é exibida
      // (fase 4/5); o Histórico lê o mesmo box do Hive sempre que é aberto
      // (fase 6). Verifica aqui a ponta a ponta desse contrato de
      // armazenamento compartilhado, sem precisar de uma chamada real à API.
      await tester.runAsync(() => NoteRepository().add(_note('01')));

      final historyState = HistoryState(noteRepository: NoteRepository());

      await tester.pumpWidget(MaterialApp(home: HistoryScreen(debugState: historyState)));

      expect(find.text('Nota 01'), findsOneWidget);
    });
  });
}
