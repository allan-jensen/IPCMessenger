#Requires AutoHotkey v2.0
#Include .\IPCMessenger.ahk

; ------------------------------------------------------------------------------
; Exemplo de uso da biblioteca IPCMessenger.ahk como emissor síncrono (SENDER).
;
; O emissor envia uma mensagem e aguarda uma resposta da outra ponta (RECEIVER).
;
; Configurações:
; - channel      : Nome identificador do canal (ex: "test").
; - requestTime  : Intervalo (ms) entre cada verificação por resposta.
; - timeout      : Tempo máximo (ms) para aguardar uma resposta.
;                  Se não definido (ou 0), aguardará indefinidamente.
;
; Importante:
; - Se não houver um receiver escutando no mesmo canal, o sender aguardará até
;   ultrapassar o timeout, ou indefinidamente se timeout = 0.
; - Ideal para chamadas que esperam retorno imediato de outro processo/script.
; ------------------------------------------------------------------------------

msg := IPCMessenger.newSyncSender("test")

!Numpad1::
{
	MsgBox("Start")
	MsgBox("Response: " msg.sendSyncMessage({a: "text1", b: Random(0, 10)}))
	MsgBox("Stop")
}

Esc::ExitApp