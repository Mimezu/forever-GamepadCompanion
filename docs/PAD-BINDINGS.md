# Pad bindings

One model for what Companion puts on a pad key, and how it reads L2 / R2.

## The held layer: one source

- `Sh.Held()` / `Sh.Layer()` (Shared.lua) read L2 / R2 from the pad itself,
  `C_GamePad.GetDeviceMappedState`: the state the secure snippets read as
  `GetGamePadState`. No pad to read: nil, and callers fall back to Base.
- Never `IsKeyDown` on a binding's key. The game's key state is the bindings':
  a release a window ate stays down, Blizzard's sets rebind the triggers'
  keys. That put Focus UI on Create with L2 up (2026-11-21).
- Readers: Keys.Watch (held-layer extras), the touchpad preview, the
  Controller page, the API's state (Core.lua). Fishing's `F.R2Held` reads the
  same pad state on its own.

## Who owns which key

| Keys | Owner | How |
| --- | --- | --- |
| L3 R3 Create Options PS Mute | Keys.lua `owner` | Base: one secure click per key (the snippet picks the layer at the press, in combat too), or a Blizzard function's binding |
| the same, a held layer | Keys.lua `layerOwner` | out of combat: the layer's binding or click while the pad says L2 / R2 is down; off on release (Blizzard's modifier hook, a 20 ms poll), in combat, on a pad change, without a pad |
| Touchpad PADBACK / PAD6, 8 prefixes | Touchpad.lua `binds` | always the zones' secure click; a 0.5 s watcher and Sh.Claim take it back |
| R2 with a pole in hand | Fishing.lua `owner` | cast / catch; changed only with R2 up |
| PAD3 at the bank | BankMove.lua | while the bank is open |
| D-pad, L1 R1, A B X Y at a flight master | FlightList.lua's panel | pad buttons on its own frame (as the window, Focus.lua), one press at a time, out of combat, while the list shows; no binding changed |
| L2, R2 at a flight master | FlightList.lua (GamepadCompanionFlightBinds) | override bindings while the list shows (L2: turn-ins, R2: quests), as the fishing pole's: changed only once both triggers have been up 0.25 s, out of combat; a state driver drops them in a fight |
| B on a taxi | FlightCard.lua (GamepadCompanionFlightCardBinds) | override binding while flying with a stop ahead: two presses land there (TaxiRequestEarlyLanding); changed only once B has been up 0.25 s, out of combat |
| Ctrl+Shift+Alt+F1-12 | Gestures.lua | WoW Helper's keys |
| L1 R1 | nobody | Blizzard's target bars; the window reads them as pad buttons (Focus.lua) |

## Rules

1. A Blizzard function (Focus UI, Radial) runs only from a key binding, on
   the exact layer chosen. A held layer's binding never outlives the hold.
2. The layer is read at the press, in the secure snippet, wherever the action
   is ours. The watcher only where a Blizzard function is on the key or shares
   it with another layer's action.
3. Nothing rebinds while a trigger is held but the watcher's own `layerOwner`.
   Never bind, relay or re-send a trigger for a layer.
4. Bindings change out of combat only; PLAYER_REGEN_DISABLED clears the extras.
   Every key is checked against what it should run (`Keys.Heal`): 4 times a
   second and the moment a window takes or gives back the pad. Base goes
   back on top, the held layer's extras above it; a leftover of ours on a key
   the game owns is dropped; the game's own bindings are never fought.
5. A mode that takes a trigger (Fishing's R2 now, a lure on L2 next) is an
   override on the trigger's key, on its own owner, changed only with the
   trigger up and cleared when the mode ends (the pole off). `Sh.Held` still
   reports the trigger down while it is pressed; a mode that wants its trigger
   out of the layers while it owns it tells `Sh.Layer` so (next step).
