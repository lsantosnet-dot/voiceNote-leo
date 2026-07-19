import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Lançada quando a permissão de microfone não foi concedida.
class MicPermissionDeniedException implements Exception {}

/// Encapsula o pacote `record`: verifica permissão, grava em `.m4a` num
/// arquivo temporário e expõe o nível de amplitude para a waveform.
class AudioRecorderService {
  late final AudioRecorder _recorder = AudioRecorder();

  Stream<Amplitude> amplitudeStream({Duration interval = const Duration(milliseconds: 120)}) {
    return _recorder.onAmplitudeChanged(interval);
  }

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Inicia a gravação e retorna o caminho do arquivo `.m4a`.
  ///
  /// Lança [MicPermissionDeniedException] se a permissão for negada.
  Future<String> start() async {
    final granted = await _recorder.hasPermission();
    if (!granted) {
      throw MicPermissionDeniedException();
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/nota_de_voz_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    return path;
  }

  Future<String?> stop() => _recorder.stop();

  Future<void> dispose() => _recorder.dispose();
}
