import 'package:hive/hive.dart';

part 'note.g.dart';

/// Uma nota de voz já processada pelo Gemini: texto estruturado e pronto
/// para copiar, compartilhar ou consultar no histórico.
@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String structuredText;

  @HiveField(3)
  final DateTime timestamp;

  Note({
    required this.id,
    required this.title,
    required this.structuredText,
    required this.timestamp,
  });
}
