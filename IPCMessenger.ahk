#Requires AutoHotkey v2.0

class IPCMessenger {
	_mutex := unset
	_fileMapping := unset

	_queue := []
	_itemIdsList := ""

	_callback := unset

	_queueSize := 10
	_timeout := unset
	_requestTime := unset
	_type := ""

	__New(channel, type, fetchData, requestTime := 50, queueSize := 10, timeout := 0, callback := unset) {
		this._requestTime := requestTime
		this._queueSize := queueSize
		this._timeout := timeout
		this._type := type
		if (IsSet(callback) && callback != "") {
			this._callback := callback
		}

		this._mutex := Mutex("Local\" . channel . "Mutex")
		this._fileMapping := FileMapping("Local\" . channel . "FileMapping")
		if (fetchData = "POLL") {
			SetTimer(this._fetchPollData.Bind(this), requestTime)
		} else if (fetchData = "RECEIVER") {
			SetTimer(this._fetchReceiverData.Bind(this), requestTime)
		}
	}

	static newAsyncPoll(channel, requestTime := 50, fetchData := true, queueSize := 10) {
		if (fetchData) {
			return IPCMessenger(channel, "POLL", "POLL", requestTime, queueSize)
		} else {
			return IPCMessenger(channel, "POLL", false, requestTime, queueSize)
		}
	}

	static newSyncSender(channel, requestTime := 50, timeout := 0) {
		return IPCMessenger(channel, "SENDER", false, requestTime,, timeout)
	}

	static newSyncReceiver(channel, callback, requestTime := 50) {
		return IPCMessenger(channel, "RECEIVER", "RECEIVER", requestTime,,, callback)
	}

	sendPollMessage(obj) {
		this._ensureType("POLL")

		callback() {
			items := this._getFileMappingData(true)

			if (items.Length = this._queueSize) {
				items.RemoveAt(1)
			}

			id := Random(0, 1000000)

			this._addId(id)

			items.Push({id: id, data: obj})

			this._fileMapping.Write(JSON.stringify(items))
		}
		this._executeSynced(callback)
	}

	sendSyncMessage(obj) {
		this._ensureType("SENDER")

		callbackWrite() {
			this._fileMapping.Write(JSON.stringify({result: false, data: obj}))
		}
		this._executeSynced(callbackWrite)

		startTime := A_TickCount
		Loop {
			if (this._timeout != 0 && A_TickCount - startTime > this._timeout) {
				throw Error("Timeout")
			}

			callbacGet() {
				result := this._getFileMappingData(false)
				if (result.result) {
					this._fileMapping.Write("")
					return {result: true, data: result.data}
				} else {
					return {result: false}
				}
			}
			response := this._executeSynced(callbacGet)
			if (response.result) {
				return response.data
			} else {
				Sleep(this._requestTime)
			}
		}
	}

	queueSize() {
		this._ensureType("POLL")
		return this._queue.Length
	}

	dequeue() {
		this._ensureType("POLL")

		if (this.queueSize() = 0) {
			return
		}

		item := this._queue.Get(1)
		this._queue.RemoveAt(1)
		return item
	}

	_fetchReceiverData() {
		callbackGet() {
			return this._getFileMappingData(false)
		}
		data := this._executeSynced(callbackGet)

		if (data.HasOwnProp("result") && !data.result) {
			callback := this._callback
			response := callback(data.data)

			callbackWrite() {
				this._fileMapping.Write(JSON.stringify({result: true, data: response}))
			}
			data := this._executeSynced(callbackWrite)
		}
	}

	_fetchPollData() {
		callback() {
			return this._getFileMappingData(true)
		}
		items := this._executeSynced(callback)

		if (this._itemIdsList = "") {
			this._populateIds(items)
		}

		for i, item in items {
			alreadyProcessed := false
			for j, id in this._itemIdsList
			{
				if (item.id = id) {
					alreadyProcessed := true
					break
				}
			}

			if (!alreadyProcessed) {
				this._queue.Push(item.data)
				this._addId(item.id)
			}
		}
	}

	_populateIds(items) {
		this._itemIdsList := []
		for i, item in items {
			this._itemIdsList.Push(item.id)
		}
	}

	_addId(id) {
		if (this._itemIdsList.Length = this._queueSize) {
			this._itemIdsList.RemoveAt(1)
		}
		this._itemIdsList.Push(id)
	}

	_getFileMappingData(setArray) {
		data := this._fileMapping.Read()
		if (setArray && data = "") {
			data := "[]"
		}
		return JSON.parse(data,, false)
	}

	_ensureType(type) {
		if (this._type != type)
			throw Error("Method not allowed for this type: " . this._type)
	}

	_executeSynced(callback) {
		try {
			Critical
			while (this._mutex.Lock() != 0) {
			}

			return callback.Call()
		} finally {
			this._mutex.Release()
			Critical("Off")
		}
	}
}

;Libs
;https://www.autohotkey.com/boards/viewtopic.php?t=124720

Class FileMapping {
	; http://msdn.microsoft.com/en-us/library/windows/desktop/aa366556(v=vs.85).aspx
	; http://www.autohotkey.com/board/topic/86771-i-want-to-share-var-between-2-processes-how-to-copy-memory-do-it/#entry552031
	; Source: https://www.autohotkey.com/board/topic/93305-filemapping-class/

	__New(szName?, dwDesiredAccess := 0xF001F, flProtect := 0x4, dwSize := 10000) {	; Opens existing or creates new file mapping object with FILE_MAP_ALL_ACCESS, PAGE_READ_WRITE
		static INVALID_HANDLE_VALUE := -1
		this.BUF_SIZE := dwSize, this.szName := szName ?? ""
		if !(this.hMapFile := DllCall("OpenFileMapping", "Ptr", dwDesiredAccess, "Int", 0, "Ptr", IsSet(szName) ? StrPtr(szName) : 0)) {
			; OpenFileMapping Failed - file mapping object doesn't exist - that means we have to create it
			if !(this.hMapFile := DllCall("CreateFileMapping", "Ptr", INVALID_HANDLE_VALUE, "Ptr", 0, "Int", flProtect, "Int", 0, "Int", dwSize, "Str", szName)) ; CreateFileMapping Failed
				throw Error("Unable to create or open the file mapping", -1)
		}
		if !(this.pBuf := DllCall("MapViewOfFile", "Ptr", this.hMapFile, "Int", dwDesiredAccess, "Int", 0, "Int", 0, "Int", dwSize))	; MapViewOfFile Failed
			throw Error("Unable to map view of file")
	}
	Write(data, offset := 0) {
		if (this.pBuf) {
			if data is String
				StrPut(data, this.pBuf+offset, this.BUF_SIZE-offset)
			else if data is Buffer
				DllCall("RtlCopyMemory", "ptr", this.pBuf+offset, "ptr", data, "int", Min(data.Size, this.BUF_SIZE-offset))
			else
				throw TypeError("The data type can be a string or a Buffer object")
		} else
			throw Error("File already closed!")
	}
	; If a buffer object is provided then data is transferred from the file mapping to the buffer
	Read(buffer?, offset := 0, size?) => IsSet(buffer) ? DllCall("RtlCopyMemory", "ptr", buffer, "ptr", this.pBuf+offset, "int", Min(buffer.size, this.BUF_SIZE-offset, size ?? this.BUF_SIZE-offset)) : StrGet(this.pBuf+offset)
	Close() {
		DllCall("UnmapViewOfFile", "Ptr", this.pBuf), DllCall("CloseHandle", "Ptr", this.hMapFile)
		this.szName := "", this.BUF_SIZE := "", this.hMapFile := "", this.pBuf := ""
	}
	__Delete() => this.Close()
}

class Mutex {
	/**
	 * Creates a new Mutex, or opens an existing one. The mutex is destroyed once all handles to
	 * it are closed.
	 * @param name Optional. The name can start with "Local\" to be session-local, or "Global\" to be
	 * available system-wide.
	 * @param initialOwner Optional. If this value is TRUE and the caller created the mutex, the
	 * calling thread obtains initial ownership of the mutex object.
	 * @param securityAttributes Optional. A pointer to a SECURITY_ATTRIBUTES structure.
	 */
	__New(name?, initialOwner := 0, securityAttributes := 0) {
		if !(this.ptr := DllCall("CreateMutex", "ptr", securityAttributes, "int", !!initialOwner, "ptr", IsSet(name) ? StrPtr(name) : 0))
			throw Error("Unable to create or open the mutex", -1)
	}
	/**
	 * Tries to lock (or signal) the mutex within the timeout period.
	 * @param timeout The timeout period in milliseconds (default is infinite wait)
	 * @returns {Integer} 0 = successful, 0x80 = abandoned, 0x120 = timeout, 0xFFFFFFFF = failed
	 */
	Lock(timeout:=0xFFFFFFFF) => DllCall("WaitForSingleObject", "ptr", this, "int", timeout, "int")
	; Releases the mutex (resets it back to the unsignaled state)
	Release() => DllCall("ReleaseMutex", "ptr", this)
	__Delete() => DllCall("CloseHandle", "ptr", this)
}

;thqby
class JSON {
	;https://github.com/thqby/ahk2_lib/blob/master/JSON.ahk
	static null := ComValue(1, 0), true := ComValue(0xB, 1), false := ComValue(0xB, 0)

	/**
	 * Converts a AutoHotkey Object Notation JSON string into an object.
	 * @param text A valid JSON string.
	 * @param keepbooltype convert true/false/null to JSON.true / JSON.false / JSON.null where it's true, otherwise 1 / 0 / ''
	 * @param as_map object literals are converted to map, otherwise to object
	 */
	static parse(text, keepbooltype := false, as_map := true) {
		keepbooltype ? (_true := this.true, _false := this.false, _null := this.null) : (_true := true, _false := false, _null := "")
		as_map ? (map_set := (maptype := Map).Prototype.Set) : (map_set := (obj, key, val) => obj.%key% := val, maptype := Object)
		NQ := "", LF := "", LP := 0, P := "", R := ""
		D := [C := (A := InStr(text := LTrim(text, " `t`r`n"), "[") = 1) ? [] : maptype()], text := LTrim(SubStr(text, 2), " `t`r`n"), L := 1, N := 0, V := K := "", J := C, !(Q := InStr(text, '"') != 1) ? text := LTrim(text, '"') : ""
		Loop Parse text, '"' {
			Q := NQ ? 1 : !Q
			NQ := Q && RegExMatch(A_LoopField, '(^|[^\\])(\\\\)*\\$')
			if !Q {
				if (t := Trim(A_LoopField, " `t`r`n")) = "," || (t = ":" && V := 1)
					continue
				else if t && (InStr("{[]},:", SubStr(t, 1, 1)) || A && RegExMatch(t, "m)^(null|false|true|-?\d+(\.\d*(e[-+]\d+)?)?)\s*[,}\]\r\n]")) {
					Loop Parse t {
						if N && N--
							continue
						if InStr("`n`r `t", A_LoopField)
							continue
						else if InStr("{[", A_LoopField) {
							if !A && !V
								throw Error("Malformed JSON - missing key.", 0, t)
							C := A_LoopField = "[" ? [] : maptype(), A ? D[L].Push(C) : map_set(D[L], K, C), D.Has(++L) ? D[L] := C : D.Push(C), V := "", A := Type(C) = "Array"
							continue
						} else if InStr("]}", A_LoopField) {
							if !A && V
								throw Error("Malformed JSON - missing value.", 0, t)
							else if L = 0
								throw Error("Malformed JSON - to many closing brackets.", 0, t)
							else C := --L = 0 ? "" : D[L], A := Type(C) = "Array"
						} else if !(InStr(" `t`r,", A_LoopField) || (A_LoopField = ":" && V := 1)) {
							if RegExMatch(SubStr(t, A_Index), "m)^(null|false|true|-?\d+(\.\d*(e[-+]\d+)?)?)\s*[,}\]\r\n]", &R) && (N := R.Len(0) - 2, R := R.1, 1) {
								if A
									C.Push(R = "null" ? _null : R = "true" ? _true : R = "false" ? _false : IsNumber(R) ? R + 0 : R)
								else if V
									map_set(C, K, R = "null" ? _null : R = "true" ? _true : R = "false" ? _false : IsNumber(R) ? R + 0 : R), K := V := ""
								else throw Error("Malformed JSON - missing key.", 0, t)
							} else {
								; Added support for comments without '"'
								if A_LoopField == '/' {
									nt := SubStr(t, A_Index + 1, 1), N := 0
									if nt == '/' {
										if nt := InStr(t, '`n', , A_Index + 2)
											N := nt - A_Index - 1
									} else if nt == '*' {
										if nt := InStr(t, '*/', , A_Index + 2)
											N := nt + 1 - A_Index
									} else nt := 0
									if N
										continue
								}
								throw Error("Malformed JSON - unrecognized character.", 0, A_LoopField " in " t)
							}
						}
					}
				} else if A || InStr(t, ':') > 1
					throw Error("Malformed JSON - unrecognized character.", 0, SubStr(t, 1, 1) " in " t)
			} else if NQ && (P .= A_LoopField '"', 1)
				continue
			else if A
				LF := P A_LoopField, C.Push(InStr(LF, "\") ? UC(LF) : LF), P := ""
			else if V
				LF := P A_LoopField, map_set(C, K, InStr(LF, "\") ? UC(LF) : LF), K := V := P := ""
			else
				LF := P A_LoopField, K := InStr(LF, "\") ? UC(LF) : LF, P := ""
		}
		return J
		UC(S, e := 1) {
			static m := Map('"', '"', "a", "`a", "b", "`b", "t", "`t", "n", "`n", "v", "`v", "f", "`f", "r", "`r")
			local v := ""
			Loop Parse S, "\"
				if !((e := !e) && A_LoopField = "" ? v .= "\" : !e ? (v .= A_LoopField, 1) : 0)
					v .= (t := m.Get(SubStr(A_LoopField, 1, 1), 0)) ? t SubStr(A_LoopField, 2) :
						(t := RegExMatch(A_LoopField, "i)^(u[\da-f]{4}|x[\da-f]{2})\K")) ?
							Chr("0x" SubStr(A_LoopField, 2, t - 2)) SubStr(A_LoopField, t) : "\" A_LoopField,
							e := A_LoopField = "" ? e : !e
			return v
		}
	}

	/**
	 * Converts a AutoHotkey Array/Map/Object to a Object Notation JSON string.
	 * @param obj A AutoHotkey value, usually an object or array or map, to be converted.
	 * @param expandlevel The level of JSON string need to expand, by default expand all.
	 * @param space Adds indentation, white space, and line break characters to the return-value JSON text to make it easier to read.
	 */
	static stringify(obj, expandlevel := unset, space := "  ") {
		expandlevel := IsSet(expandlevel) ? Abs(expandlevel) : 10000000
		return Trim(CO(obj, expandlevel))
		CO(O, J := 0, R := 0, Q := 0) {
			static M1 := "{", M2 := "}", S1 := "[", S2 := "]", N := "`n", C := ",", S := "- ", E := "", K := ":"
			if (OT := Type(O)) = "Array" {
				D := !R ? S1 : ""
				for key, value in O {
					F := (VT := Type(value)) = "Array" ? "S" : InStr("Map,Object", VT) ? "M" : E
					Z := VT = "Array" && value.Length = 0 ? "[]" : ((VT = "Map" && value.count = 0) || (VT = "Object" && ObjOwnPropCount(value) = 0)) ? "{}" : ""
					D .= (J > R ? "`n" CL(R + 2) : "") (F ? (%F%1 (Z ? "" : CO(value, J, R + 1, F)) %F%2) : ES(value)) (OT = "Array" && O.Length = A_Index ? E : C)
				}
			} else {
				D := !R ? M1 : ""
				for key, value in (OT := Type(O)) = "Map" ? (Y := 1, O) : (Y := 0, O.OwnProps()) {
					F := (VT := Type(value)) = "Array" ? "S" : InStr("Map,Object", VT) ? "M" : E
					Z := VT = "Array" && value.Length = 0 ? "[]" : ((VT = "Map" && value.count = 0) || (VT = "Object" && ObjOwnPropCount(value) = 0)) ? "{}" : ""
					D .= (J > R ? "`n" CL(R + 2) : "") (Q = "S" && A_Index = 1 ? M1 : E) ES(key) K (F ? (%F%1 (Z ? "" : CO(value, J, R + 1, F)) %F%2) : ES(value)) (Q = "S" && A_Index = (Y ? O.count : ObjOwnPropCount(O)) ? M2 : E) (J != 0 || R ? (A_Index = (Y ? O.count : ObjOwnPropCount(O)) ? E : C) : E)
					if J = 0 && !R
						D .= (A_Index < (Y ? O.count : ObjOwnPropCount(O)) ? C : E)
				}
			}
			if J > R
				D .= "`n" CL(R + 1)
			if R = 0
				D := RegExReplace(D, "^\R+") (OT = "Array" ? S2 : M2)
			return D
		}
		ES(S) {
			switch Type(S) {
				case "Float":
					if (v := '', d := InStr(S, 'e'))
						v := SubStr(S, d), S := SubStr(S, 1, d - 1)
					if ((StrLen(S) > 17) && (d := RegExMatch(S, "(99999+|00000+)\d{0,3}$")))
						S := Round(S, Max(1, d - InStr(S, ".") - 1))
					return S v
				case "Integer":
					return S
				case "String":
					S := StrReplace(S, "\", "\\")
					S := StrReplace(S, "`t", "\t")
					S := StrReplace(S, "`r", "\r")
					S := StrReplace(S, "`n", "\n")
					S := StrReplace(S, "`b", "\b")
					S := StrReplace(S, "`f", "\f")
					S := StrReplace(S, "`v", "\v")
					S := StrReplace(S, '"', '\"')
					return '"' S '"'
				default:
					return S == this.true ? "true" : S == this.false ? "false" : "null"
			}
		}
		CL(i) {
			Loop (s := "", space ? i - 1 : 0)
				s .= space
			return s
		}
	}
}