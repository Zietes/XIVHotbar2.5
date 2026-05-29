# XIVHotbar2 — Controller bridge (no Steam Input required)

Windower addons can only receive **keyboard/mouse** input — never the gamepad,
and they can't read FFXI's own controller mapping. So controller support works
by having a tiny helper read the pad and send keystrokes that XIVHotbar2 is
bound to. This folder is that helper, using **AutoHotkey + XInput** (the same
approach the sibling addon *xivcrossbar* uses), so you don't need Steam Input.

It uses a **light layer**: nothing happens until you **hold a trigger**, so your
controller keeps working normally in FFXI the rest of the time. Hold a trigger
and the **D-pad** moves the cyan cursor while **A** activates the highlighted
slot.

## What's here

| File | Purpose |
|------|---------|
| `xivhotbar2_controller.ahk` | Reads the Xbox/XInput pad and sends the cursor keys while a trigger is held |
| `xivhotbar2_binds.txt` | The Windower `bind` lines that map those keys to `htb cursor ...` |

## Setup (Xbox / any XInput controller)

1. **Install [AutoHotkey v1.1+](https://www.autohotkey.com/)** (free).

2. **Add the Windower binds.** Paste these into the Windower console (or add
   them to `Windower4/scripts/init.txt` so they load every time):
   ```
   bind numpad8 htb cursor up
   bind numpad2 htb cursor down
   bind numpad4 htb cursor left
   bind numpad6 htb cursor right
   bind numpad5 htb cursor activate
   ```
   (These numpad keys are unused by XIVHotbar2's own row chords.)

3. **Start the bridge.** Double-click `xivhotbar2_controller.ahk`. It runs in
   the tray and only sends keys while FFXI is focused **and** a trigger is held.

   *Optional — auto-start with the game:* enable Windower's **Run** plugin
   (Windower launcher → Plugins → Run) and add a line that launches the script,
   so it starts whenever you log in.

4. **Use it in game:** **hold LT (or RT)** → the active page lights up gold and
   the cyan cursor appears. While holding, tap the **D-pad** to move the cursor
   (left/right along a page, up/down between pages) and press **A** to fire the
   highlighted ability. Release the trigger to return to normal controls.

## Troubleshooting (it's not working?)

**First, confirm the script is even running.** When you launch the `.ahk` it now
pops a tray notification ("XIVHotbar2 Controller running") that says which XInput
DLL loaded and whether your controller is detected. If you don't see it, look for
the green-H AutoHotkey icon in the system tray — no icon means the script isn't
running (re-launch it, or check AutoHotkey is installed). You can also
right-click that tray icon → **Toggle debug overlay**.

Press **Ctrl+Alt+D** with the script running to toggle a **live debug overlay**.
While debugging, the pad is read even from the desktop, so you can isolate the
problem:

1. **Overlay says "Pad 0: NOT CONNECTED"** → the script can't see your
   controller. Make sure it's an XInput (Xbox-style) pad and plugged in; if it's
   a second controller, set `PadIndex` (0–3) at the top of the `.ahk`.
2. **Buttons/triggers DON'T change in the overlay when you press them** → the
   pad isn't reaching XInput at all (a wrapper/Steam may be capturing it). Close
   other controller software and retry.
3. **`LT`/`RT` show numbers and the D-pad row flips to 1 when pressed, but
   nothing happens in game** → the controller is read fine; the keys just aren't
   reaching FFXI. This is almost always the **administrator mismatch** below.

### The #1 cause: "run as administrator" mismatch

Windower/FFXI are almost always run **as administrator**. Windows refuses to let
a *non-elevated* program send keystrokes into an *elevated* window — so the
script reads your pad perfectly but its keys are silently dropped. That is
exactly the "pad detected, overlay moves, nothing in game" symptom.

This version **auto-elevates**: on launch it relaunches itself as admin (you'll
get a one-time UAC prompt — click **Yes**). Confirm it worked two ways:

- The startup tray message and the debug overlay both show **`Admin: YES`**.
- **Use the built-in self-test:** focus FFXI and press **F8** on your keyboard.
  That injects the activate key exactly like the controller does.
  - Cursor activates → the key path works; the controller will too.
  - Nothing happens → still blocked. Make sure the script actually elevated
    (Admin: YES), and that Windower itself is the elevated window. As a manual
    fallback, right-click the `.ahk` → **Run as administrator**.

If F8 works but the controller still doesn't, then it's only the controller
gate: check **"FFXI focused: 1"** shows and a **trigger is held** (keys only
send when both are true).

Also verify your five `bind` lines are loaded in Windower — type Numpad 5 by
hand; if the cursor doesn't activate, the bind is missing, not the script.

This version sends each key as a real **down → hold (~40ms) → up** using **scan
codes**, because Windower reads the keyboard through DirectInput and a normal
instant key "tap" is often missed. If keys still don't register, raise
`KeyHoldTime` at the top of the script (e.g. to 60–80).

## Notes & tuning

- **Double-inputs:** because FFXI still reads the pad natively, a button you
  press while holding the trigger *may* also do its normal FFXI action. The
  D-pad is usually safe while a trigger is held; if `A` does something you don't
  want, change `Key_Activate` in the `.ahk` to a different button (e.g. map a
  bumper instead) or use a trigger combo FFXI ignores.
- **Editable settings** live at the top of `xivhotbar2_controller.ahk`:
  `PadIndex` (which controller), `TriggerThresh` (pull sensitivity),
  `RepeatDelay`/`RepeatRate` (cursor auto-repeat speed), and the `Key_*` sends.
- **DirectInput pads:** this script is XInput-only. A non-XInput controller
  would need a DirectInput variant (see xivcrossbar's `ffxi_directinput.ahk`).

## Prefer Steam Input instead?

That still works too — the addon just needs the same five keys. See the
**Controller / Gamepad Support** section in the main `README.md` for the Steam
Input hold-layer walkthrough. Both routes drive the identical `htb cursor`
commands, so you can switch freely.
