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
; ============================================================================

#NoEnv
#SingleInstance Force
#Persistent
SetBatchLines, -1

; ---------------------------------------------------------------------------
;  CONFIG  -- edit these if you want different keys / behaviour
; ---------------------------------------------------------------------------
global PadIndex        := 0      ; which XInput pad (0 = first controller)
global TriggerThresh   := 30     ; 0-255, how far a trigger must be pulled
global PollInterval    := 15     ; ms between polls
global RepeatDelay     := 350    ; ms before a held direction starts repeating
global RepeatRate      := 120    ; ms between repeats while a direction is held
global OnlyWhenFFXI    := true   ; only act while the FFXI window is focused

; Keys sent to FFXI/Windower. These MUST match your Windower binds:
;   bind numpad8 htb cursor up      |  bind numpad2 htb cursor down
;   bind numpad4 htb cursor left    |  bind numpad6 htb cursor right
;   bind numpad5 htb cursor activate
global Key_Up       := "{Numpad8}"
global Key_Down     := "{Numpad2}"
global Key_Left     := "{Numpad4}"
global Key_Right    := "{Numpad6}"
global Key_Activate := "{Numpad5}"

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
global XInputGetStateProc := XInputDll . "\XInputGetState"

; XINPUT_GAMEPAD button bitmasks
global XB_DPAD_UP    := 0x0001
global XB_DPAD_DOWN  := 0x0002
global XB_DPAD_LEFT  := 0x0004
global XB_DPAD_RIGHT := 0x0008
global XB_A          := 0x1000

; Per-button edge/repeat tracking
global prevUp := 0, prevDown := 0, prevLeft := 0, prevRight := 0, prevA := 0
global nextUp := 0, nextDown := 0, nextLeft := 0, nextRight := 0

SetTimer, PollPad, %PollInterval%
return

; ---------------------------------------------------------------------------
;  Main poll loop
; ---------------------------------------------------------------------------
PollPad:
    if (OnlyWhenFFXI && !WinActive("ahk_class FFXiClass"))
    {
        ResetPadState()
        return
    }

    VarSetCapacity(state, 16, 0)               ; XINPUT_STATE
    res := DllCall(XInputGetStateProc, "UInt", PadIndex, "Ptr", &state, "UInt")
    if (res != 0)                               ; non-zero = controller not connected
    {
        ResetPadState()
        return
    }

    buttons   := NumGet(state, 4, "UShort")     ; wButtons  @ offset 4
    lTrigger  := NumGet(state, 6, "UChar")      ; bLeftTrigger  @ 6
    rTrigger  := NumGet(state, 7, "UChar")      ; bRightTrigger @ 7

    layerOn := (lTrigger > TriggerThresh) || (rTrigger > TriggerThresh)
    if (!layerOn)
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
        SendInput, %Key_Activate%
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
        SendInput, %key%
        next%name% := now + RepeatDelay
    }
    else if (isDown && now >= next%name%)        ; held long enough -> repeat
    {
        SendInput, %key%
        next%name% := now + RepeatRate
    }
    prev%name% := isDown
}

ResetPadState()
{
    global
    prevUp := 0, prevDown := 0, prevLeft := 0, prevRight := 0, prevA := 0
}
