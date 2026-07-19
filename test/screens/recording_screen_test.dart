import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voicenote_leo/screens/recording_screen.dart';
import 'package:voicenote_leo/services/audio_recorder_service.dart';
import 'package:voicenote_leo/state/recording_state.dart';
import 'package:voicenote_leo/widgets/record_button.dart';

/// Serviço de áudio falso: nunca toca o canal de plataforma real do
/// pacote `record`, então roda em qualquer ambiente de teste de widget.
class _FakeAudioRecorderService extends AudioRecorderService {
  bool permissionGranted = true;
  final _amplitudeController = StreamController<Amplitude>.broadcast();

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<String> start() async {
    if (!permissionGranted) throw MicPermissionDeniedException();
    return '/tmp/fake.m4a';
  }

  @override
  Future<String?> stop() async => '/tmp/fake.m4a';

  @override
  Stream<Amplitude> amplitudeStream({Duration interval = const Duration(milliseconds: 120)}) {
    return _amplitudeController.stream;
  }

  @override
  Future<void> dispose() async {
    await _amplitudeController.close();
  }
}

void main() {
  testWidgets('estado ocioso mostra cronômetro zerado e hint de gravar', (tester) async {
    final state = RecordingState(service: _FakeAudioRecorderService());
    addTearDown(() => tester.runAsync(() async => state.dispose()));

    await tester.pumpWidget(MaterialApp(home: RecordingScreen(debugState: state)));

    expect(find.text('00:00'), findsOneWidget);
    expect(find.textContaining('Toque para gravar', findRichText: true), findsOneWidget);
  });

  testWidgets('tocar no botão aciona o toggle de gravação', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: RecordButton(isRecording: false, onTap: () => tapCount++),
    ));

    await tester.tap(find.byType(RecordButton));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('gravando atualiza o hint e permite parar', (tester) async {
    final state = RecordingState(service: _FakeAudioRecorderService());
    addTearDown(() => tester.runAsync(() async => state.dispose()));

    await tester.pumpWidget(MaterialApp(home: RecordingScreen(debugState: state)));

    // Aciona diretamente o mesmo método que o toque no botão dispara,
    // envolvido em runAsync: a chamada real usa Future/Stream que não
    // resolvem sozinhos dentro da zona FakeAsync dos testes de widget.
    await tester.runAsync(state.toggleRecording);
    await tester.pump();

    expect(state.isRecording, isTrue);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.textContaining('Toque para parar', findRichText: true), findsOneWidget);

    await tester.runAsync(state.toggleRecording);
    await tester.pump();

    expect(state.isRecording, isFalse);
    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('permissão negada mostra aviso e botão de tentar novamente', (tester) async {
    final fakeService = _FakeAudioRecorderService()..permissionGranted = false;
    final state = RecordingState(service: fakeService);
    addTearDown(() => tester.runAsync(() async => state.dispose()));

    await tester.pumpWidget(MaterialApp(home: RecordingScreen(debugState: state)));

    await tester.runAsync(state.toggleRecording);
    await tester.pump();

    expect(state.permissionDenied, isTrue);
    expect(find.textContaining('Não conseguimos acessar o microfone'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    fakeService.permissionGranted = true;
    await tester.runAsync(state.toggleRecording);
    await tester.pump();

    expect(state.isRecording, isTrue);

    // Encerra a gravação antes do fim do teste para não deixar o
    // cronômetro (Timer.periodic) pendente.
    await tester.runAsync(state.toggleRecording);
    await tester.pump();
  });
}
