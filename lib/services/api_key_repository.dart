import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Acesso à chave de API do Gemini. Fica só no keystore/keychain do
/// aparelho via `flutter_secure_storage` — nunca em texto puro, nunca
/// versionada no código.
class ApiKeyRepository {
  ApiKeyRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'gemini_api_key';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _storageKey);

  Future<void> save(String apiKey) =>
      _storage.write(key: _storageKey, value: apiKey.trim());

  Future<void> clear() => _storage.delete(key: _storageKey);
}
