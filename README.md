# IPCMessenger.ahk

**IPCMessenger**(Inter-Process Communication Messenger) é uma biblioteca para comunicação entre scripts AutoHotkey v2 através de **memória compartilhada (FileMapping)** com **controle de concorrência por Mutex**. Suporta tanto comunicação **assíncrona** (fila com polling) quanto **síncrona** (envio com resposta).

---

##  Funcionalidades

- Comunicação entre múltiplos scripts AutoHotkey v2
- Envio de objetos complexos ou variáveis
- Modos de operação:
  - `POLL`: Comunicação assíncrona em fila
  - `SENDER`: Emissor síncrono com espera por resposta
  - `RECEIVER`: Receptor síncrono com callback
- Manipulação de dados via memória compartilhada (`FileMapping`)
- Deduplicação de mensagens por ID
- Controle seguro de concorrência via `Mutex`

## Aviso
-- Esta biblioteca utiliza mecanismos baseados em threads e interrupções via `SetTimer` do AutoHotkey v2.  
Portanto, **qualquer operação que bloqueie a thread principal**, como MsgBox, pode **interromper ou atrasar o funcionamento do IPCMessenger**.

## Exemplos
- `Async`: Executar Poll1, Poll2 e Poll3 simultaneamente. Alt + Numpad1-6 envia mensagens
- `Synced`: Executar Sender e Receiver simultaneamente. Alt + Numpad1 envia mensagem