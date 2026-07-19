import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voicenote_leo/models/gemini_model.dart';
import 'package:voicenote_leo/models/output_format.dart';
import 'package:voicenote_leo/services/settings_repository.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_repository_test');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    await Hive.openBox(SettingsRepository.boxName);
  });

  tearDown(() async {
    final box = Hive.box(SettingsRepository.boxName);
    await box.clear();
    await box.close();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('modelo e formato usam o padrão (flash/tópicos) quando nada foi salvo', () {
    final repository = SettingsRepository();
    expect(repository.getModel(), GeminiModel.flash);
    expect(repository.getOutputFormat(), OutputFormat.topics);
  });

  test('salva e lê de volta o modelo escolhido', () async {
    final repository = SettingsRepository();
    await repository.setModel(GeminiModel.pro);
    expect(repository.getModel(), GeminiModel.pro);

    await repository.setModel(GeminiModel.flashLite);
    expect(repository.getModel(), GeminiModel.flashLite);
  });

  test('salva e lê de volta o formato de saída escolhido', () async {
    final repository = SettingsRepository();
    await repository.setOutputFormat(OutputFormat.meetingMinutes);
    expect(repository.getOutputFormat(), OutputFormat.meetingMinutes);

    await repository.setOutputFormat(OutputFormat.freeText);
    expect(repository.getOutputFormat(), OutputFormat.freeText);
  });
}
