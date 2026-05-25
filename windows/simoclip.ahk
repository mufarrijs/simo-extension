#Requires AutoHotkey v2.0
#SingleInstance Force

; SimoClip for Windows
; ─────────────────────────────────────────────────────────────────────────────
; COPY   Ctrl+C  →  (hold Ctrl) press 0–9   → saves to slot
; PASTE  Ctrl+B  →  (hold Ctrl) press 0–9   → pastes from slot
; Regular Ctrl+C and Ctrl+V are NEVER blocked.
;
; SHORTCUTS
;   Ctrl+Shift+0      Show slot viewer
;   Ctrl+Shift+H      Browse history
;   Ctrl+Shift+E      Enable / disable
;   Ctrl+Shift+X      Clear all slots
; ─────────────────────────────────────────────────────────────────────────────

; ── Config ────────────────────────────────────────────────────────────────────

DATA_DIR    := A_AppData . "\SimoClip\"
SLOTS_FILE  := DATA_DIR . "slots.ini"
HIST_FILE   := DATA_DIR . "history.txt"
CHORD_MS    := 1000     ; chord window in milliseconds

; ── State ─────────────────────────────────────────────────────────────────────

global slots        := Map()
global lastAction   := ""
global lastActionAt := 0
global appEnabled   := true

; ── Setup ─────────────────────────────────────────────────────────────────────

DirCreate(DATA_DIR)
LoadSlots()
SetupTray()
TrayTip("SimoClip ready", "Ctrl+C then Ctrl+0-9 to save`nCtrl+B then Ctrl+0-9 to paste", 3)

; ── Persistence ───────────────────────────────────────────────────────────────

LoadSlots() {
    global slots
    loop 10 {
        n := A_Index - 1
        v := IniRead(SLOTS_FILE, "Slots", "C" . n, "")
        if v != ""
            slots[n] := v
    }
}

SaveSlots() {
    global slots
    loop 10 {
        n := A_Index - 1
        IniWrite(slots.Has(n) ? slots[n] : "", SLOTS_FILE, "Slots", "C" . n)
    }
}

AppendHistory(content, slotN := "") {
    line := FormatTime(, "yyyy-MM-dd HH:mm")
    if slotN != ""
        line .= " [C" . slotN . "]"
    line .= " | " . StrReplace(StrReplace(content, "`r`n", " "), "`n", " ")
    FileAppend(SubStr(line, 1, 300) . "`n", HIST_FILE)
}

; ── Core chord logic ──────────────────────────────────────────────────────────

Notify(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -1800)
}

HandleChord(n) {
    global slots, lastAction, lastActionAt, appEnabled
    if !appEnabled
        return
    elapsed := A_TickCount - lastActionAt
    if elapsed > CHORD_MS or lastAction = ""
        return
    action := lastAction
    lastAction := ""

    if action = "copy" {
        Sleep 80   ; wait for clipboard to settle after Ctrl+C
        txt := A_Clipboard
        if txt = ""
            return
        slots[n] := txt
        SaveSlots()
        AppendHistory(txt, n)
        Notify("C" . n . " saved  ·  " . SubStr(txt, 1, 45))
    } else if action = "paste" {
        if !slots.Has(n) or slots[n] = "" {
            Notify("C" . n . " is empty")
            return
        }
        A_Clipboard := slots[n]
        Sleep 50
        Send "^v"
    }
}

; ── Hotkeys ───────────────────────────────────────────────────────────────────

; Ctrl+C: mark copy mode, ALWAYS passes through (~ prefix)
~^c:: {
    global lastAction, lastActionAt, appEnabled
    if appEnabled {
        lastAction   := "copy"
        lastActionAt := A_TickCount
    }
}

; Ctrl+B: mark paste mode, passes through so bold still works in Word/Docs
~^b:: {
    global lastAction, lastActionAt, appEnabled
    if appEnabled {
        lastAction   := "paste"
        lastActionAt := A_TickCount
    }
}

; Ctrl+0-9: chord — only captured when inside the chord window
; Outside the chord window these pass through normally to the active app
#HotIf appEnabled and (A_TickCount - lastActionAt) < CHORD_MS and lastAction != ""
^0:: HandleChord(0)
^1:: HandleChord(1)
^2:: HandleChord(2)
^3:: HandleChord(3)
^4:: HandleChord(4)
^5:: HandleChord(5)
^6:: HandleChord(6)
^7:: HandleChord(7)
^8:: HandleChord(8)
^9:: HandleChord(9)
#HotIf

; ── Slot panel (Ctrl+Shift+0) ─────────────────────────────────────────────────

^+0:: ShowSlotPanel()

ShowSlotPanel() {
    global slots
    g := Gui("+AlwaysOnTop -MinimizeBox", "SimoClip — Slots")
    g.SetFont("s11", "Segoe UI")
    g.BackColor := "0F0F18"
    g.SetFont("cDDDDEE")

    g.Add("Text", "w340 Center c5599AA", ":) SimoClip")
    g.Add("Text", "w340 Center c334455", "Click a slot to paste it into the active app")
    g.Add("Text", "w340 h6")

    loop 10 {
        n := A_Index - 1
        lbl := slots.Has(n) and slots[n] != "" ? "C" . n . "  " . SubStr(slots[n], 1, 48) : "C" . n . "  (empty)"
        btn := g.Add("Button", "w340 h26 c003366 Background1A2535", lbl)
        btn.OnEvent("Click", PasteSlotFn(n, g))
    }

    g.Add("Text", "w340 h8")
    r := g.Add("Button", "w165", "History...")
    r.OnEvent("Click", (*) => (g.Destroy(), ShowHistory()))
    c := g.Add("Button", "x+10 w165", "Close")
    c.OnEvent("Click", (*) => g.Destroy())

    g.Show()
}

PasteSlotFn(n, gui) {
    return (*) => (gui.Destroy(), Sleep(120), DoPasteSlot(n))
}

DoPasteSlot(n) {
    global slots
    if !slots.Has(n) or slots[n] = "" {
        Notify("C" . n . " is empty")
        return
    }
    A_Clipboard := slots[n]
    Sleep 50
    Send "^v"
}

; ── History viewer (Ctrl+Shift+H) ─────────────────────────────────────────────

^+h:: ShowHistory()

ShowHistory() {
    if !FileExist(HIST_FILE) {
        MsgBox("No history yet.", "SimoClip", "Iconx")
        return
    }

    g := Gui("+Resize +AlwaysOnTop", "SimoClip — History")
    g.SetFont("s10", "Segoe UI")
    g.BackColor := "0F0F18"

    lv := g.Add("ListView", "w520 h380 Background0F0F18 cDDDDEE -LV0x10", ["Time", "Slot", "Content"])
    lv.ModifyCol(1, 115)
    lv.ModifyCol(2, 45)
    lv.ModifyCol(3, 340)

    lines := []
    loop read, HIST_FILE
        lines.Push(A_LoopReadLine)

    loop lines.Length {
        line := lines[lines.Length - A_Index + 1]
        parts := StrSplit(line, " | ", , 2)
        if parts.Length >= 2 {
            meta := parts[1]
            content := parts[2]
            slot := ""
            if RegExMatch(meta, "\[C(\d)\]", &m)
                slot := "C" . m[1]
            time := RegExReplace(meta, " \[C\d\]", "")
            lv.Add(, time, slot, content)
        }
    }

    g.Add("Text", "w520 h4")
    copy := g.Add("Button", "w160 h28", "Copy selected")
    copy.OnEvent("Click", (*) => CopyFromLv(lv))
    clear := g.Add("Button", "x+8 w160 h28", "Clear history")
    clear.OnEvent("Click", (*) => ConfirmClearHist(g))
    cls := g.Add("Button", "x+8 w160 h28", "Close")
    cls.OnEvent("Click", (*) => g.Destroy())

    g.Show()
}

CopyFromLv(lv) {
    row := lv.GetNext(0, "Focused")
    if row {
        A_Clipboard := lv.GetText(row, 3)
        Notify("Copied ✓")
    }
}

ConfirmClearHist(parentGui) {
    res := MsgBox("Delete all history entries?", "SimoClip", "YesNo Icon!")
    if res = "Yes" {
        parentGui.Destroy()
        FileDelete(HIST_FILE)
        Notify("History cleared")
    }
}

; ── Enable / disable (Ctrl+Shift+E) ───────────────────────────────────────────

^+e:: {
    global appEnabled
    appEnabled := !appEnabled
    Notify(appEnabled ? "SimoClip ✓ enabled" : "SimoClip ○ disabled")
}

; ── Clear all slots (Ctrl+Shift+X) ────────────────────────────────────────────

^+x:: {
    global slots
    res := MsgBox("Clear all slots C0–C9?`nHistory is kept.", "SimoClip", "YesNo Icon!")
    if res = "Yes" {
        slots := Map()
        SaveSlots()
        Notify("All slots cleared")
    }
}

; ── Tray menu ─────────────────────────────────────────────────────────────────

SetupTray() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add(":) SimoClip", (*) => 0)
    A_TrayMenu.Disable(":) SimoClip")
    A_TrayMenu.Add()
    A_TrayMenu.Add("Show Slots  (Ctrl+Shift+0)", (*) => ShowSlotPanel())
    A_TrayMenu.Add("History     (Ctrl+Shift+H)", (*) => ShowHistory())
    A_TrayMenu.Add()
    A_TrayMenu.Add("Toggle Enable  (Ctrl+Shift+E)", (*) => (appEnabled := !appEnabled, Notify(appEnabled ? "Enabled ✓" : "Disabled ○")))
    A_TrayMenu.Add("Clear All Slots (Ctrl+Shift+X)", (*) => (slots := Map(), SaveSlots(), Notify("Cleared")))
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit SimoClip", (*) => ExitApp())
    A_TrayMenu.Default := "Show Slots  (Ctrl+Shift+0)"
    A_IconTip := "SimoClip"
}
