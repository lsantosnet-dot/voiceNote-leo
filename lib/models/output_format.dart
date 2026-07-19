/// Formato de saída do texto estruturado gerado pelo Gemini.
enum OutputFormat {
  topics('Tópicos'),
  freeText('Texto corrido'),
  meetingMinutes('Ata de reunião'),
  correctedTranscription('Transcrição corrigida');

  final String label;

  const OutputFormat(this.label);
}
