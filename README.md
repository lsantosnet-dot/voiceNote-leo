# Nota de Voz

App Flutter (Android) de uso pessoal: grava a voz do usuário, envia o áudio
para o Gemini (Google AI Studio) e recebe de volta um texto estruturado,
pronto para copiar/colar ou compartilhar. Cada usuário usa a própria chave de
API — sem backend, sem custo compartilhado.

Detalhes de produto e fluxo completo em `spec-app-voz-texto.md`.

## Estrutura

```
lib/
  screens/   # telas (gravação, resultado, histórico, configurações)
  widgets/   # componentes reutilizáveis de UI
  services/  # áudio, chamadas ao Gemini, storage (secure storage / hive)
  models/    # modelos de dados (Note, OutputFormat, GeminiModel)
  state/     # ChangeNotifier / provider por tela
```

## Dependências principais

- `record` — captura de áudio
- `google_generative_ai` — cliente do Gemini API
- `flutter_secure_storage` — armazenamento da chave de API
- `share_plus` — compartilhamento nativo
- `hive` / `hive_flutter` — histórico local de notas
- `provider` — gerenciamento de estado

## Rodando

```
flutter pub get
flutter run
```
