import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/note.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(NoteAdapter());
  runApp(const VoiceNoteApp());
}

class VoiceNoteApp extends StatelessWidget {
  const VoiceNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nota de Voz',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4FD8C4)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Fundação do projeto — telas em construção')),
      ),
    );
  }
}
