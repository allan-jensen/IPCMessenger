#Requires AutoHotkey v2.0
#Include .\IPCMessenger.ahk

; ------------------------------------------------------------------------------
; Exemplo de uso da biblioteca IPCMessenger.ahk como async (POLL).
;
; Configurações:
; - channel       : Nome identificador do canal (ex: "test1", "test2").
; - requestTime   : Intervalo (ms) entre cada verificação de novas mensagens.
; - fetchData     : Define se o canal deve buscar mensagens (true/false).
; - queueSize     : Tamanho máximo da fila em memória compartilhada.
;                   (fila local pode conter mais mensagens)
;
; Importante:
; - Defina `fetchData := false` se o canal não for usado para receber dados.
;   Caso contrário, o polling desnecessário pode consumir recursos e causar lentidão.
; - Um intervalo de polling(requestTime) muito curto consome mais CPU.
; - Um intervalo muito longo pode perder mensagens se forem enviadas
;   rapidamente em sequência.
; ------------------------------------------------------------------------------

channel1 := IPCMessenger.newAsyncPoll("test1")
channel2 := IPCMessenger.newAsyncPoll("test2")
SetTimer(CheckChannels, 50)

CheckChannels() {
    ReadAndShow(channel1)
    ReadAndShow(channel2)
}

ReadAndShow(channel) {
    while channel.queueSize() != 0 {
        msg := channel.dequeue()
        MsgBox msg.a " " msg.b
    }
}

!Numpad1:: channel1.sendPollMessage({ a: "text1", b: Random(0, 10) })
!Numpad2:: channel2.sendPollMessage({ a: "text2", b: Random(0, 10) })

Esc::ExitApp