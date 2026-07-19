import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../services/audio_recorder_service.dart';

enum RecordingPhase { idle, recording, permissionDenied }

/// Estado da tela de gravação: ociosa, gravando ou aguardando permissão.
class RecordingState extends ChangeNotifier {
  RecordingState({AudioRecorderService? service})
      : _service = service ?? AudioRecorderService();

  static const int _waveformBarCount = 28;

  final AudioRecorderService _service;

  RecordingPhase _phase = RecordingPhase.idle;
  Duration _elapsed = Duration.zero;
  List<double> _levels = List.filled(_waveformBarCount, 0.06);
  String? _lastRecordingPath;

  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;

  RecordingPhase get phase => _phase;
  bool get isRecording => _phase == RecordingPhase.recording;
  bool get permissionDenied => _phase == RecordingPhase.permissionDenied;
  Duration get elapsed => _elapsed;
  List<double> get levels => _levels;
  String? get lastRecordingPath => _lastRecordingPath;

  Future<void> toggleRecording() {
    return isRecording ? _stop() : _start();
  }

  Future<void> _start() async {
    try {
      _lastRecordingPath = await _service.start();
    } on MicPermissionDeniedException {
      _phase = RecordingPhase.permissionDenied;
      notifyListeners();
      return;
    }

    _phase = RecordingPhase.recording;
    _elapsed = Duration.zero;
    notifyListeners();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });

    _amplitudeSub?.cancel();
    _amplitudeSub = _service.amplitudeStream().listen(_onAmplitude);
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    await _amplitudeSub?.cancel();
    _lastRecordingPath = await _service.stop();
    _phase = RecordingPhase.idle;
    _levels = List.filled(_waveformBarCount, 0.06);
    notifyListeners();
  }

  void _onAmplitude(Amplitude amplitude) {
    // dBFS costuma variar entre ~-45 (silêncio) e 0 (pico); normaliza pra 0..1.
    final normalized = ((amplitude.current + 45) / 45).clamp(0.0, 1.0);
    _levels = [..._levels.skip(1), normalized];
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
