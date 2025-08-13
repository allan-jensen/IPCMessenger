#Requires AutoHotkey v2.0
#Include .\IPCMessenger.ahk

; ------------------------------------------------------------------------------
; Exemplo de uso da biblioteca IPCMessenger.ahk como receptor síncrono (RECEIVER).
;
; O receptor escuta chamadas no canal definido e responde usando uma função callback.
;
; Configurações:
; - channel      : Nome identificador do canal (ex: "test").
; - callback     : Função chamada automaticamente ao receber uma mensagem.
;                  Deve retornar o valor que será enviado de volta ao emissor.
; - requestTime  : Intervalo (ms) entre verificações por novas mensagens.
;
; Importante:
; - A função callback recebe como argumento os dados enviados pelo sender.
; - O valor retornado pela função será enviado como resposta.
; ------------------------------------------------------------------------------

msg := IPCMessenger.newSyncReceiver("test", callback)

callback(data) {
	MsgBox(data.a . " " . data.b)
	return "This is the response"
}

Esc::ExitApp