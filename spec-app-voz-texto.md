# Nota de Voz — App Flutter (Android)

## Objetivo
App de uso pessoal para Android: grava a voz do usuário, envia o áudio para o Gemini
(Google AI Studio, camada gratuita) e recebe de volta um texto estruturado, pronto
para copiar/colar ou compartilhar em outro app. Cada usuário usa sua própria chave
de API — o app não tem backend nem custo compartilhado.

## Stack e pacotes
- Flutter (Android apenas por enquanto)
- `record` — captura de áudio
- `google_generative_ai` — cliente oficial do Gemini API (envio de áudio inline)
- `flutter_secure_storage` — armazenamento da chave de API (nunca em `SharedPreferences` puro)
- `share_plus` — compartilhamento nativo (share sheet do Android)
- `hive` (ou `sqflite`) — histórico local de notas
- `provider` — gerenciamento de estado (suficiente para o escopo do app)
- `home_widget` — widget de tela inicial (fase 2)

## Arquitetura em camadas
1. **UI (Flutter widgets)** — telas descritas abaixo
2. **Camada de áudio** — grava, mantém o arquivo em cache local enquanto a tela de
   resultado está aberta (necessário para o recurso de reprocessar sem regravar)
3. **Camada de API** — monta a chamada `generateContent` com o áudio em `inline_data`
   (base64) + prompt de estruturação; trata erros de rede/quota/chave inválida
4. **Camada de armazenamento** — histórico de notas (Hive/sqflite) e chave de API
   (secure storage), separados
5. **Estado** — `ChangeNotifier` por tela (gravação, resultado, histórico, config)

## Fluxo principal
1. Usuário toca em gravar → grava áudio local (`.m4a`)
2. Ao parar, o áudio é enviado direto ao Gemini com prompt de estruturação
   (pula transcrição separada — o modelo já transcreve e organiza numa única chamada)
3. Resposta em texto é exibida na tela de resultado, **editável**
4. Usuário copia, compartilha, reprocessa (mesmo áudio) ou grava uma nova nota
5. Nota é salva automaticamente no histórico local ao concluir

## Telas e estados

### 1. Tela principal — Gravação (ociosa / gravando)
- Botão circular de gravar/parar, com pulso animado durante a gravação
- Waveform simples (ou indicador de nível de áudio)
- Cronômetro da gravação
- Ícones no topo: histórico (relógio) e configurações (engrenagem)
- **Esta é a tela "raiz"** — as demais sempre voltam pra cá

### 2. Tela de Resultado
- Card de texto **editável** (toque para corrigir antes de copiar/enviar)
- Ações: **Copiar** (clipboard), **Compartilhar** (share sheet nativo)
- Ações secundárias: **Reprocessar** (reenvia o mesmo áudio em cache, sem regravar —
  mostra estado de carregamento) e **Nova gravação**
- Seta de voltar no topo (leva à tela principal)
- Salva automaticamente no histórico ao ser exibida

### 3. Histórico
- Lista de cards colapsados (título, prévia, data/hora)
- Toque expande o card revelando o texto completo
- Cada card expandido tem ícone de **copiar** e ícone de **excluir** (lixeira)
- Estado vazio com mensagem orientativa
- Seta de voltar no topo

### 4. Configurações
- Indicador de status da chave (configurada / não configurada)
- Campo de chave de API com máscara de senha + botão de mostrar/ocultar
- Texto explicando que a chave fica só no dispositivo, com link para gerar em
  `aistudio.google.com/apikey`
- Seletor de modelo (ex: Gemini 2.5 Flash / 2.5 Pro / 2.0 Flash-Lite)
- Seletor de formato de saída (tópicos / texto corrido / ata de reunião)
- Botão salvar
- Seta de voltar no topo

## Regras de negócio importantes
- A chave de API é por dispositivo/usuário — nunca hardcoded, nunca versionada
- O áudio bruto não precisa ser retido após o processamento, exceto temporariamente
  para permitir o "reprocessar sem regravar" (pode ser descartado ao sair da tela
  de resultado ou ao gravar uma nova nota)
- Tratar erros de: sem internet, chave inválida, limite de quota do free tier
  excedido (mensagens claras, sem termos técnicos de API)
- Free tier do Gemini: dados de entrada/saída podem ser usados pelo Google para
  melhorar modelos — isso deve estar refletido no texto da tela de configurações
  (já está no rascunho acima)

## Fase 2 (não implementar agora)
- Widget de tela inicial (via `home_widget`) que abre o app direto na tela de
  gravação — não grava em segundo plano por conta das exigências de notificação
  de foreground service do Android para captura de áudio
- Parada automática por silêncio

## Referência visual
Protótipo HTML interativo anexo (`prototipo-voz-texto.html`) — reproduz fielmente
os quatro estados de tela, paleta de cores, tipografia e microcopy. Usar como fonte
da verdade para layout, espaçamento e nomenclatura de botões/labels.
