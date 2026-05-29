; ============================================================================
;  XIVHotbar2 - Controller bridge (XInput / Xbox pads)
; ----------------------------------------------------------------------------
;  Windower addons can only receive keyboard/mouse input, never the gamepad.
;  This AutoHotkey v1 script reads an XInput controller directly and, while you
;  HOLD a trigger, turns the D-pad + A button into the keystrokes that
;  XIVHotbar2's controller commands are bound to (see controller/README.md).
;
;  "Light layer" design: the script does NOTHING unless a trigger is held, so
;  your controller keeps working natively in FFXI the rest of the time. Only
;  while a trigger is held do the D-pad / A become hotbar-cursor keys.
;
;  Requires AutoHotkey v1.1+  (https://www.autohotkey.com/)
;
;  TROUBLESHOOTING: press  Ctrl+Alt+D  to toggle a live debug overlay that
;  shows whether the pad is read, the trigger values, and the last key sent.
; ============================================================================

#NoEnv
#SingleInstance Force
#Persistent
#InstallKeybdHook
SetBatchLines, -1

; ---------------------------------------------------------------------------
;  CONFIG  -- edit these if you want different keys / behaviour
; ---------------------------------------------------------------------------
global PadIndex        := 0      ; which XInput pad (0 = first controller)
global TriggerThresh   := 30     ; 0-255, how far a trigger must be pulled
global PollInterval    := 15     ; ms between polls
global RepeatDelay     := 350    ; ms before a held direction starts repeating
global RepeatRate      := 130    ; ms between repeats while a direction is held
global KeyHoldTime     := 40     ; ms to hold each key down (so DirectInput sees it)
global OnlyWhenFFXI    := true   ; only act while the FFXI window is focused

; Keys sent to FFXI/Windower, as SCAN CODES (NumLock-independent and read
; correctly by Windower's DirectInput keyboard hook). These MUST match your
; Windower binds:
;   bind numpad8 htb cursor up      |  bind numpad2 htb cursor down
;   bind numpad4 htb cursor left    |  bind numpad6 htb cursor right
;   bind numpad5 htb cursor activate
global Key_Up       := "sc048"   ; Numpad 8
global Key_Down     := "sc050"   ; Numpad 2
global Key_Left     := "sc04B"   ; Numpad 4
global Key_Right    := "sc04D"   ; Numpad 6
global Key_Activate := "sc04C"   ; Numpad 5

; ---------------------------------------------------------------------------
;  XInput setup
; ---------------------------------------------------------------------------
global hXInput := 0
global XInputDll := ""
for i, dll in ["XInput1_4.dll", "XInput1_3.dll", "XInput9_1_0.dll"]
{
    hXInput := DllCall("LoadLibrary", "Str", dll, "Ptr")
    if (hXInput)
    {
        XInputDll := dll
        break
    }
}
if (!hXInput)
{
    MsgBox, 16, XIVHotbar2 Controller, Could not load XInput. Install the DirectX runtime or AutoHotkey, then try again.
    ExitApp
}
global XInputGetStateProc := DllCall("GetProcAddress", "Ptr", hXInput, "AStr", "XInputGetState", "Ptr")
if (!XInputGetStateProc)
{
    MsgBox, 16, XIVHotbar2 Controller, Loaded %XInputDll% but XInputGetState was not found.
    ExitApp
}

; XINPUT_GAMEPAD button bitmasks
global XB_DPAD_UP    := 0x0001
global XB_DPAD_DOWN  := 0x0002
global XB_DPAD_LEFT  := 0x0004
global XB_DPAD_RIGHT := 0x0008
global XB_A          := 0x1000

; Per-button edge/repeat tracking
global prevUp := 0, prevDown := 0, prevLeft := 0, prevRight := 0, prevA := 0
global nextUp := 0, nextDown := 0, nextLeft := 0, nextRight := 0

; Debug
global DebugMode := false
global LastKey   := "(none)"

; Tray menu
Menu, Tray, Tip, XIVHotbar2 Controller (Ctrl+Alt+D = debug)
Menu, Tray, Add, Toggle debug overlay, ToggleDebug

; Startup confirmation: probe the pad once and tell the user the script is alive,
; which XInput DLL loaded, and whether a controller is detected right now.
VarSetCapacity(probe, 16, 0)
probeRes := DllCall(XInputGetStateProc, "UInt", PadIndex, "Ptr", &probe, "UInt")
padMsg := (probeRes = 0) ? ("DETECTED on pad " PadIndex) : ("NOT detected (plug in / check PadIndex). code " probeRes)
TrayTip, XIVHotbar2 Controller running, % "XInput DLL: " XInputDll "`nController: " padMsg "`n`nPress Ctrl+Alt+D for the debug overlay.", 10, 1

SetTimer, PollPad, %PollInterval%
return

; ---------------------------------------------------------------------------
;  Hotkeys  (defined as real hotkeys so they actually fire)
; ---------------------------------------------------------------------------
^!d::Gosub, ToggleDebug   ; Ctrl+Alt+D toggles the debug overlay

; ---------------------------------------------------------------------------
;  Main poll loop
; ---------------------------------------------------------------------------
PollPad:
    ffxiActive := WinActive("ahk_class FFXiClass") ? 1 : 0

    ; Read the pad whenever FFXI is focused, OR always while debugging so you
    ; can verify the controller is seen even from the desktop.
    if (OnlyWhenFFXI && !ffxiActive && !DebugMode)
    {
        ResetPadState()
        ToolTip
        return
    }

    VarSetCapacity(state, 16, 0)               ; XINPUT_STATE
    res := DllCall(XInputGetStateProc, "UInt", PadIndex, "Ptr", &state, "UInt")
    connected := (res = 0)

    if (!connected)
    {
        if (DebugMode)
            ToolTip, % "XIVHotbar2 controller`nPad " PadIndex ": NOT CONNECTED (err " res ")`nFFXI focused: " ffxiActive
        ResetPadState()
        return
    }

    buttons   := NumGet(state, 4, "UShort")     ; wButtons  @ offset 4
    lTrigger  := NumGet(state, 6, "UChar")      ; bLeftTrigger  @ 6
    rTrigger  := NumGet(state, 7, "UChar")      ; bRightTrigger @ 7
    layerOn   := (lTrigger > TriggerThresh) || (rTrigger > TriggerThresh)

    if (DebugMode)
    {
        ToolTip, % "XIVHotbar2 controller [DEBUG]`n"
            . "FFXI focused: " ffxiActive "   (keys only send when 1)`n"
            . "LT: " lTrigger "   RT: " rTrigger "   (need > " TriggerThresh ")`n"
            . "trigger layer: " (layerOn ? "ON" : "off") "`n"
            . "buttons: " Format("0x{:04X}", buttons)
            . "  Up:" ((buttons & XB_DPAD_UP)?1:0)
            . " Dn:" ((buttons & XB_DPAD_DOWN)?1:0)
            . " Lf:" ((buttons & XB_DPAD_LEFT)?1:0)
            . " Rt:" ((buttons & XB_DPAD_RIGHT)?1:0)
            . " A:" ((buttons & XB_A)?1:0) "`n"
            . "last key sent: " LastKey
    }

    ; Only actually send keys while FFXI is focused and a trigger is held.
    if (!layerOn || (OnlyWhenFFXI && !ffxiActive))
    {
        ResetPadState()
        return
    }

    now := A_TickCount
    HandleDirection(buttons & XB_DPAD_UP,    "Up",    Key_Up,    now)
    HandleDirection(buttons & XB_DPAD_DOWN,  "Down",  Key_Down,  now)
    HandleDirection(buttons & XB_DPAD_LEFT,  "Left",  Key_Left,  now)
    HandleDirection(buttons & XB_DPAD_RIGHT, "Right", Key_Right, now)

    ; A button = activate (press only, no repeat)
    aDown := (buttons & XB_A) ? 1 : 0
    if (aDown && !prevA)
        SendKey(Key_Activate)
    prevA := aDown
return

; Edge-trigger + auto-repeat for a held direction
HandleDirection(isDown, name, key, now)
{
    global
    isDown := isDown ? 1 : 0
    prev := prev%name%
    if (isDown && !prev)                        ; just pressed -> fire now, arm repeat
    {
        SendKey(key)
        next%name% := now + RepeatDelay
    }
    else if (isDown && now >= next%name%)        ; held long enough -> repeat
    {
        SendKey(key)
        next%name% := now + RepeatRate
    }
    prev%name% := isDown
}

; Send a key as a real down/hold/up so DirectInput's per-frame polling catches
; it (a zero-length SendInput tap is often missed by games).
SendKey(key)
{
    global KeyHoldTime, LastKey
    SendInput, {%key% down}
    Sleep, %KeyHoldTime%
    SendInput, {%key% up}
    LastKey := key " @ " A_Hour ":" A_Min ":" A_Sec
}

ResetPadState()
{
    global
    prevUp := 0, prevDown := 0, prevLeft := 0, prevRight := 0, prevA := 0
}

ToggleDebug:
    DebugMode := !DebugMode
    if (!DebugMode)
        ToolTip
return
