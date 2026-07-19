import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voicenote_leo/services/audio_recorder_service.dart';
import 'package:voicenote_leo/state/recording_state.dart';

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
  test('start then stop resolves without hanging', () async {
    final state = RecordingState(service: _FakeAudioRecorderService());

    await state.toggleRecording();
    expect(state.isRecording, isTrue);

    await state.toggleRecording();
    expect(state.isRecording, isFalse);

    state.dispose();
  });

  test('cronômetro avança enquanto grava', () async {
    final state = RecordingState(service: _FakeAudioRecorderService());
    addTearDown(state.dispose);

    await state.toggleRecording();
    expect(state.elapsed, Duration.zero);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(state.elapsed.inSeconds, greaterThanOrEqualTo(1));

    await state.toggleRecording();
  });

  test('permissão negada não inicia gravação e permite tentar de novo', () async {
    final fakeService = _FakeAudioRecorderService()..permissionGranted = false;
    final state = RecordingState(service: fakeService);
    addTearDown(state.dispose);

    await state.toggleRecording();
    expect(state.permissionDenied, isTrue);
    expect(state.isRecording, isFalse);

    fakeService.permissionGranted = true;
    await state.toggleRecording();
    expect(state.isRecording, isTrue);

    await state.toggleRecording();
  });
}
