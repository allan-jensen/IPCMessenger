#Requires AutoHotkey v2.0
#Include .\IPCMessenger.ahk

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

!Numpad5:: channel1.sendPollMessage({ a: "text5", b: Random(0, 10) })
!Numpad6:: channel2.sendPollMessage({ a: "text6", b: Random(0, 10) })

Esc::ExitApp