/// Modelos Gemini disponíveis para seleção nas configurações.
enum GeminiModel {
  flash('gemini-2.5-flash', 'Gemini 2.5 Flash — rápido, recomendado'),
  pro('gemini-2.5-pro', 'Gemini 2.5 Pro — mais preciso, limite diário menor'),
  flashLite('gemini-2.0-flash-lite', 'Gemini 2.0 Flash-Lite — mais econômico');

  final String apiModelId;
  final String label;

  const GeminiModel(this.apiModelId, this.label);
}
