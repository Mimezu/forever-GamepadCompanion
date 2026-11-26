# Pad bindings

One model for what Companion puts on a pad key, and how it reads L2 / R2.

## The held layer: one source

- `Sh.Held()` / `Sh.Layer()` (Shared.lua) read L2 / R2 from the pad itself,
  `C_GamePad.GetDeviceMappedState`: the state the secure snippets read as
  `GetGamePadState`. No pad to read: nil, and callers fall back to Base.
- Never `IsKeyDown` on a binding's key. The game's key state is the bindings':
  a release a window ate stays down, Blizzard's sets rebind the triggers'
  keys. That put Focus UI on Create with L2 up (2026-11-21).
- Readers: the touchpad preview, the Controller page, the API's state
  (Core.lua). Keys.lua reads no layer in Lua: its secure snippet does, at the press. Fishing's `F.R2Held` reads the
  same pad state on its own.

## Who owns which key

| Keys | Owner | How |
| --- | --- | --- |
| L3 R3 Create Options PS Mute | Keys.lua `GamepadCompanionKeyBinds` (click), `GamepadCompanionKeyNative` (a Blizzard function) | no action: the game's own. Only a Blizzard function on Base: that function on the key. Else one secure click per key, written in place only when the settings change; the snippet picks the layer at the press: a macro (k<n>), a WoW Helper chord (h<n>), or none |
| Alt-Ctrl-Shift-1..9 | Keys.lua `GamepadCompanionHelperChords` (1-3), `GamepadCompanionGameChords` (4-9) | WoW Helper's keys, held while the hold cells say n: 1 Focus UI, 2 Radial, 3 Ping wheel (bound once at login); 4-9 a key's own game command when its Base is empty |
| Touchpad PADBACK / PAD6, 8 prefixes | Touchpad.lua `binds` | always the zones' secure click; a 0.5 s watcher and Sh.Claim take it back |
| R2 with a pole in hand | Fishing.lua `owner` | cast / catch; changed only with R2 up |
| PAD3 at the bank | BankMove.lua | while the bank is open |
| D-pad, L1 R1, A B X Y at a flight master | FlightList.lua's panel | pad buttons on its own frame (as the window, Focus.lua), one press at a time, out of combat, while the list shows; no binding changed |
| L2, R2 at a flight master | FlightList.lua (GamepadCompanionFlightBinds) | override bindings while the list shows (L2: turn-ins, R2: quests), as the fishing pole's: changed only once both triggers have been up 0.25 s, out of combat; a state driver drops them in a fight |
| B on a taxi | FlightCard.lua (GamepadCompanionFlightCardBinds) | override binding while flying with a stop ahead: two presses land there (TaxiRequestEarlyLanding); changed only once B has been up 0.25 s, out of combat |
| Ctrl+Shift+Alt+F1-12 | Gestures.lua | WoW Helper's keys |
| L1 R1 | nobody | Blizzard's target bars; the window reads them as pad buttons (Focus.lua) |

## Rules

1. A Blizzard gamepad function (Focus UI, Radial, Ping wheel) goes on a pad
   key only when it is that key's one action, on Base. Anywhere else it runs
   through WoW Helper: the click's pick h<n> sets the hold cells (HelperLink
   K.Hold), the helper holds the chord. In game: a binding let go hands its
   function to the next fresh binding of the key; a function stays in its
   record under a click written over it; the newest record wins.
   So a record that carried a function is never let go: a key given back
   after one stays our click (Base: its own command's chord) till /reload.
   A key's own command is read from its keybinding, never an override.
2. The layer is read at the press, in the secure snippet, never in Lua.
3. Nothing rebinds when L2 / R2 move. Never bind, relay or re-send a trigger
   for a layer.
4. Bindings change out of combat only, when the settings do (or Blizzard's
   binding covers a key of ours: Sh.Claim writes ours again in place).
5. A mode that takes a trigger (Fishing's R2 now, a lure on L2 next) is an
   override on the trigger's key, on its own owner, changed only with the
   trigger up and cleared when the mode ends (the pole off). `Sh.Held` still
   reports the trigger down while it is pressed; a mode that wants its trigger
   out of the layers while it owns it tells `Sh.Layer` so (next step).
