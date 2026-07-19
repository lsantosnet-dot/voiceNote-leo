import 'package:hive/hive.dart';

import '../models/gemini_model.dart';
import '../models/output_format.dart';

/// Preferências não sensíveis (modelo do Gemini e formato de saída),
/// guardadas num box do Hive separado da chave de API (que fica no secure
/// storage) e do histórico de notas.
class SettingsRepository {
  static const boxName = 'settings';
  static const _modelKey = 'gemini_model';
  static const _outputFormatKey = 'output_format';

  Box get _box => Hive.box(boxName);

  GeminiModel getModel() {
    final name = _box.get(_modelKey) as String?;
    return GeminiModel.values.firstWhere(
      (model) => model.name == name,
      orElse: () => GeminiModel.flash,
    );
  }

  Future<void> setModel(GeminiModel model) => _box.put(_modelKey, model.name);

  OutputFormat getOutputFormat() {
    final name = _box.get(_outputFormatKey) as String?;
    return OutputFormat.values.firstWhere(
      (format) => format.name == name,
      orElse: () => OutputFormat.topics,
    );
  }

  Future<void> setOutputFormat(OutputFormat format) =>
      _box.put(_outputFormatKey, format.name);
}
