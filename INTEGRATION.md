# Gamepad Companion provider v1

`GamepadCompanionAPI` exposes plain functions (dot calls). The TOC loads the provider before options. Consumers can discover it after ADDON_LOADED and remain independent when absent.

- `version = 1`
- `GetState()` returns a copy: `available`, `enabled`, `nativeEnabled`, `gameplay`, `pendingLayout`; when known, `ltHeld`, `rtHeld`, `bothHeld`, `activeLayer` (`base`, `lt`, `rt`, `both`), `page`, `nativeOverride`. `nativeEnabled` describes Blizzard's UI independently of the companion enable switch; `enabled` describes usable companion observation.
- `Subscribe(owner, callback)` immediately calls `callback(snapshot)` and later publishes changed snapshots. In 0.1.3, a native bar-selection posthook additionally calls `callback(snapshot, "native-bar")` synchronously, including repeated native repaints. Listeners on this path must limit work to state/alpha; companion geometry stays deferred. `Unsubscribe(owner)` removes the subscription. The owner is not passed to the callback.
- `GetBarFrame(layer)` resolves an ordinary native bar or the shared `stance` bar, or nil. Stance has independent saved layout settings. `GetState().activeSpecialBar` is `stance` when it is selected during gameplay; `activeLayer` retains its ordinary-layer meaning and `nativeOverride` remains true for stance selection. Callers must also honor availability, enabled and gameplay state before leasing alpha.
- `GetCapabilities()` reports `layout`, `activeZoom`, `activeZoomInCombat=false`, `toggle=false`, `bindingOverrides=false`.
- `GetSettings()` returns a copy. `SetBarOption(layer, key, value)`, `SetEnabled(bool)`, `ResetBar(layer)` and `ResetAll()` return success and an optional pending message.

Unknown is nil, not false. Held describes physical keys bound to native GAMEPADLEFTMOD/GAMEPADRIGHTMOD; activeLayer describes the native selected ordinary action bar. Menu suspension or a special native override can have no ordinary activeLayer. These notifications confer no protected-action authority.

Frame Gambit owns alpha. The companion owns its requested bar geometry and restores the latest host-requested values. Since 0.1.4, Base also controls the shoulder artwork and the friendly/hostile targeting and shortcuts bars. Those bars and the shoulder backgrounds anchor to Base while customized; icons/highlights retain their background anchors. Base active zoom applies to this group when Base or a shoulder override is selected. Override state remains distinct in the public API. It never reparents native frames, replaces native scripts, changes secure action attributes or installs override bindings.

Version 0.1.3 uses one secure posthook on `SetActiveActionBar`, installed outside combat once per native page identity. `synchronousBarState` in capabilities reports whether the current page is observed. It never registers callbacks in Blizzard's input manager or hooks native geometry methods. Bounded polling remains for geometry and other state. The provider subscription table belongs entirely to Gamepad Companion. Geometry reconciliation preserves detectable native repaints; identical host writes are indistinguishable from the companion's own value. A failed geometry write sets `layoutError=true` and stops writes to that frame until a settings action or recovery event permits another attempt; its restoration record remains retained.

Since 0.3.0, `GetSettings()` also returns `optionsStyle` (`A`, `B` or `C`; the options window look only). `SetOptionsStyle(style)` saves it without any layout work; `SelectOptionsStyle(style)` (defined by the options window) also restyles open windows. Neither affects bar geometry or state.

Since 0.5.0, `GetCapabilities().bindingOverrides` is true while the opt-in touchpad zones (`Touchpad.lua`) have keys bound: `PADBACK` and its modifier variants in chord mode (L1's variants go to Blizzard's `TOGGLEUIFOCUS`), or `PAD6` in split mode. `GamepadCompanionAPI.Touch` has `Status()` and `Command(text)`. The layout part still never binds keys.

Since 0.4.0, `GetCapabilities().activeZoom` is always false: Blizzard's Edit Mode "Expand" setting enlarges the selected bar. Settings entries have `x`, `y` and `scale` only. `GamepadCompanionAPI.EditMode` now only has `Status()`, `Convert(name, activate)`, `List()` and `Command(text)`.
