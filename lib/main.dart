import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/note.dart';
import 'screens/recording_screen.dart';
import 'services/api_key_repository.dart';
import 'services/note_repository.dart';
import 'widgets/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(NoteAdapter());
  await Hive.openBox<Note>(NoteRepository.boxName);
  await _seedApiKeyForTestingIfNeeded();
  runApp(const VoiceNoteApp());
}

/// Provisório: enquanto a tela de configurações (que vai gravar a chave via
/// `flutter_secure_storage`) não existe, permite testar a camada de API
/// passando a chave em tempo de build — nunca hardcoded no código-fonte:
///
///   flutter run --dart-define=GEMINI_API_KEY=sua_chave_aqui
///
/// Remover esta função quando a tela de configurações estiver pronta.
Future<void> _seedApiKeyForTestingIfNeeded() async {
  const envApiKey = String.fromEnvironment('GEMINI_API_KEY');
  if (envApiKey.isEmpty) return;

  final repository = ApiKeyRepository();
  final existing = await repository.read();
  if (existing == null || existing.isEmpty) {
    await repository.save(envApiKey);
  }
}

class VoiceNoteApp extends StatelessWidget {
  const VoiceNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nota de Voz',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RecordingScreen(),
    );
  }
}
