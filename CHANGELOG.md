# Changelog

## Unreleased

- (0.4.2) Fix for client 70532 and later: class buttons (LB + LT / RB + RT) with an offset. While their radial flyout is open, Blizzard now anchors the button to the flyout's centre with no offset (`ApplyExtraButtonStyles`, `IsPopupOpen`), after centring the flyout on the button where Companion put it. Companion added its offset on top of that anchor, so the button jumped away from the open radial by the offset. It now leaves that anchor alone (and the prompt where it is) while the flyout is open; the offset comes back when the flyout closes. `tests/CompactLayout.lua` covers both the 70338 (reparent only) and 70532 (anchor to flyout) behaviour.
- (0.4.2) The per-login gamepad layout repair now finds nothing: 70338's own `ReconcileLayouts` let a clean gamepad layout fall through to the keyboard reconcile (an `elseif`), which removed the controller bar at every login and made the 0.4.1 repair necessary; 70532 fixed it. The repair stays as a safety net. Help text and EDIT-MODE.md no longer say the conversion reloads the UI (0.4.1 removed that).

- (0.4.1) Fix: no controller action bar after the conversion.
  - Gamepad layouts saved before 70338 ("gamepad new", "Alberich", "[GP] Gamepad Mime 2", "Alberich Native") are stored without the GamepadMainActionBar system, and with 59 keyboard-era systems. Edit Mode hides a frame whose system the active layout lacks, so the bar was hidden and could not be selected in Edit Mode.
  - Every login (out of combat), Companion now gives those layouts the gamepad preset's systems and settings, like Blizzard's ReconcileWithGamepad. Moved frames keep their positions and keyboard layouts are untouched. The previous layouts are kept in `nativeExportHistory`.
- (0.4.1) Fix: `ReloadUI` is protected, so the 0.4.0 conversion's reload was blocked (ADDON_ACTION_BLOCKED). Companion no longer reloads; Blizzard applies the layout through its own event.
- (0.4.1) Alberich's selection of "Alberich Gamepad" did not persist: the edit-mode cache still shows "gamepad new" active. Companion now checks the gamepad layout in use the session after a conversion and says once which layout to pick in Edit Mode. `/gpc edit` shows the gamepad layout in use and whether it has the controller bar.

- (0.4.0) Build 70338 gives Blizzard Edit Mode real gamepad layouts. They are reconciled against the gamepad preset, and the client keeps one active layout per input type and switches by itself. Companion's own Edit Mode placement is retired:
  - Removed: snapshot playback, the Layouts panel, Save here / Load / Copy / Import / Recover / Retry, the cooldown and detail adapters, and their tests.
  - The files and tests moved to `StorageInvestigation/gamepadcompanion-retired-20261013`. The loaded code went from 4,104 to 2,976 lines.
- (0.4.0) One-time conversion. The Companion layout a character was using becomes a Blizzard character layout "<Character> Gamepad":
  - It starts from the gamepad preset and keeps the gamepad layout in use for every frame Companion never moved, including the controller action bar block's position and its Compact / Expand settings.
  - It then places the saved frames.
  - It runs the first time the gamepad UI is up, out of combat and outside Edit Mode. It then selects the layout and reloads once.
  - Keyboard logins wait. Failures are reported and not retried automatically. Old profiles stay in `GamepadCompanionEditModeDB` as a backup.
  - Commands: `/gpc edit`, `/gpc edit convert [name]`, `/gpc edit list`. See EDIT-MODE.md.
- (0.4.0) Converter fixes over the 0.2.1 export. That export failed verification on Alberich on 2026-09-26, and the likely cause is the first item:
  - Offsets are rounded to a tenth and setting values to integers, as the client stores them.
  - Readback differences are reported instead of failing the export.
  - A frame with no gamepad system is skipped instead of stopping the export.
  - Settings that no longer exist are not written, so Blizzard's reconcile changes nothing.
- (0.4.0) Removed Active zoom. Blizzard's Expand setting on the controller action bar (Edit Mode) enlarges the selected bar natively. `GetCapabilities().activeZoom` is now always false. Saved zoom values are dropped; none were set.
- (0.4.0) Options: "Edit Mode layouts" became "Edit Mode", which opens Blizzard Edit Mode from the hardware click (`/editmode`). Help topics updated. README rewritten for the current feature set (old one in the retired folder).
- (0.4.0) New `tests/NativeMigration.lua`:
  - It converts the real saved profiles (3 characters) against Blizzard's 70338 gamepad preset (52 systems, copied to `StorageInvestigation/forever-ui-70338`).
  - It checks that the result is reconcile-clean, the readback is exact, the controller bar is kept, the layout is selected once with one reload, and it covers keyboard deferral, combat wait, full slots and name clashes.
  - All six suites pass on Lua 5.1 and LuaJIT. Not yet verified in game.

- (0.3.2) Build 70338: Blizzard moved Compact Action Bar from Options > Gamepad (the `GamepadUseCompactActionBar` CVar, no longer read) into Edit Mode, as a setting of the controller action bar saved with the Edit Mode layout. The Compact / Standard buttons sent the old `/console` command and always reported "did not change". They now mark the layout in use; clicking the other one runs Blizzard's `/editmode` from the hardware click and says which box to tick. "Gamepad options" no longer scrolls to the removed checkbox. Help text updated.
- (0.3.2) Build 70338: `GamepadMainActionBarFrame` is now an Edit Mode system (preset BOTTOM 0,110). Companion Edit Mode layouts leave it out, so saving or loading a layout never places the frame that holds the secure gamepad action buttons; move the bar block in Blizzard Edit Mode, and Companion's bar offsets are added on top.
- (0.3.1) Class-action buttons (LB+LT / RB+RT) keep their placement while Blizzard's radial flyout is open. Before, the placement was dropped as soon as the flyout took the button, so the button jumped to Blizzard's spot when you let go of L1 or L2. Your offset is converted to the flyout's scale, and a `SetParent` posthook applies it at once. Nothing is written in combat.
- (0.3.0) Styles A and C swapped: A is now the controller-friendly layout and the default, C the classic look. Saves from before the swap (no `optionsStyleVersion`) keep the look they had: old C becomes A. Fixed a flaky check in `tests/NativeLayoutExport.lua` that zeroed an offset one fixture frame already had.
- (0.3.0) Compact / Standard now switch Blizzard's Compact action bar option (`GamepadUseCompactActionBar`, per character) and edit that layout; the window always edits the layout in use, so the orange "Not in use" state is gone. The buttons are InsecureActionButtonTemplate macro buttons running `/console GamepadUseCompactActionBar 1|0` from the hardware click, like the Macros button. An addon `SetCVar` would fire CVAR_UPDATE in addon execution and write `CVarCallbackRegistry.cvarValueCache` tainted, which Blizzard's compact bar switching reads in combat. Disabled during combat; a message appears if the setting did not change.
- (0.3.0) Options window alignment: every row now shares the same left (20) and right (540) edges. The value steppers, reset/copy row and tool row used to stop at 518 while the toolbar, layout switch, tabs and Close reached 540; three tabs left a 2 px gap. Tabs now split the row exactly. Button labels are centred at any height and cut short instead of spilling out.
- (0.3.0) Window styles A / B / C (`optionsStyle`, default A; Style buttons in the footer or `/gpc style A|B|C`). A is the fixed classic look. B is the Forever Names / Petal / Halo window (NineSlice border, centred title, native close) with each section in a card. C uses the same chrome with a controller-friendly editor: arrow pad, step size 1 / 10 / 50, big -/+ for scale and zoom, no text entry. All three drive the same settings; switching keeps the window open, the selected tab and Spread view.
- (0.3.0) Shared chrome (`OptionsSkin.Chrome`) for the options, help and Edit Mode layouts windows. The Layouts panel drops its flat blue box and text "X" for the same look as the options window, with a tag column (Load / Copy / Import), a tick on the layout in use, a page count, disabled arrows on the first/last page and tooltips. It closes again when you leave Edit Mode if Edit Mode opened it.
- (0.3.0) Fixes: the options and help windows register with Frame Gambit's Cinematic suite windows (they were blacked out with the HUD). The minus buttons used U+2212, which Friz Quadrata doesn't have; they now use "-". The prompt row named "LB + LT" on the RB + RT tab. Typed values that were not confirmed stayed on screen; leaving a box now puts the saved value back, Tab applies and moves on, and "0,85" is read as 0.85. Result messages (range errors, "applies after combat") stay up for 5 seconds instead of being wiped by the next state repaint. The close button no longer sits on a second button frame. The "Gamepad options" shortcut no longer reopens this window much later if Blizzard's panel never opened. `/gpc options` opened Blizzard's settings; it now opens this window (`/gpc gamepad` still opens Blizzard's).
- (0.3.0) Enabled is a check box instead of a button whose label showed the state. Disabled buttons dim their label. `/gpc on|off` confirm in chat; `/gpc help` lists the commands; unknown commands say so instead of opening the window. `/gpc reset` keeps the window style.
- (0.3.0) The help window is 170 px shorter and has a Window styles topic. Edit Mode status reads "In use for the gamepad UI: <name>."
- (0.3.0) Retired the unused `Assets/SuiteWindowBackdrop.png` (moved to `StorageInvestigation/gamepadcompanion-retired-20260927`). New `tests/OptionsStyles.lua`; the options, compact and Edit Mode tests now load the skin like the TOC does. All suites pass on Lua 5.1 and LuaJIT; not yet verified in game.

- (0.2.2) Spread view in compact mode shows all four trigger bars. Blizzard's compact rule hides every bar but the active one; Spread view now shows the others itself (outside combat, re-shown if Blizzard hides them again on a trigger change) and hides them again when Spread view ends, leaving the active bar shown. Standard mode never touches bar visibility.
- (0.2.0) Compact mode: read `PageUnit:ShouldUseCompactLayout()` (CVar `GamepadUseCompactActionBar`, per character) and keep separate Standard (`bars`) and Compact (`compact`) layouts. Compact has one `bars` entry for all four trigger bars plus its own stance and class-button entries. Settings version 2; version 1 saves keep their values in Standard, Compact starts neutral. Blizzard's option is only read, never written.
- (0.2.0) Class-action buttons (`LeftClassAction` / `RightClassAction`) and their input prompts: offset (in PageUnit pixels), scale that keeps the button in place, and prompt hiding through alpha. A `hooksecurefunc` on each button's `ApplyExtraButtonStylesForState` restores the placement after Blizzard's per-press re-anchor, outside combat only. Writes are skipped while the radial flyout has reparented the button.
- (0.2.0) API: `SetBarOption`/`ResetBar` take an optional `mode`; new `GetMode`, `ResetMode`, `CopyLayout`, `SetClassPrompts`, `OpenGamepadSettings`; `GetBarFrame` also returns the class buttons. State gains `compact` and `mode`.
- (0.2.0) Options window rebuilt (560x560): Compact/Standard switch, mode- and class-aware tabs, tooltips, Shift-click and mouse-wheel fine steps, per-tab/per-layout reset, copy between layouts, Blizzard Gamepad options shortcut via `C_SettingsUtil.OpenSettingsPanel` (reopens on close), Edit Mode layouts button, version in the title, new Help topics. `/gpc gamepad`.
- (0.2.0) New `tests/CompactLayout.lua`. All suites pass on Lua 5.1 and LuaJIT; not yet verified in game.

- (0.1.26) Build 1.60.1.70009 review. No Blizzard gamepad API or frame used by Companion was removed; `PageUnit` fields, `GetActiveBar`, `SetActiveActionBar`, `GetCurrentPage`, the shoulder regions and `GamepadPlayerCastingBarFrame` are unchanged. Offline tests pass against both the 69913 mirror and the 70009 source.
- (0.1.26) Native Edit Mode now declares and saves `interfaceStyle` on custom layouts (see NATIVE-EDIT-MODE.md). `/gpc edit diagnose` counts controller-tagged layouts and records the running addon version instead of a stale "0.1.21".
- (0.1.26) `/gpc edit native Name[; Other Name]` rebuilds keyboard-tagged native custom layouts as controller layouts. It keeps the gamepad preset's system set (the controller UI hides keyboard bars by omitting their systems), takes saved position/settings where the source has that system, and fills the rest from the preset. It refuses in combat, in Edit Mode, for the active layout and for unknown names. Originals go to `GamepadCompanionEditModeDB.nativeConversionBackups`. Saves through `C_EditMode.SaveLayouts`, then reloads. `/gpc edit native` alone lists candidates.
- (0.1.26) Known 70009 layout changes, not handled in code: `GamepadMainActionBarFrame` sits 85 px higher (BOTTOM y 25 -> 110), so saved bar offsets appear 85 px higher. New LB+LT / RB+RT class-action buttons (Druid forms, Paladin auras, Warrior stances, pet commands) anchor to the bottom bar anchor and re-anchor themselves on every press. Companion does not move them.

- (0.1.25) `/gpc reset`, `/gpc on` and `/gpc off` accept any capitalization and surrounding spaces.
- (0.1.25) Bar option bounds are a shared constant instead of a table built on every call; removed an unused Edit Mode variable.
- (0.1.25) Button-hold detection stays on its 10 Hz demand-driven poll: this client exposes no GAME_PAD_BUTTON_DOWN/UP events (only GAME_PAD_ACTIVE_CHANGED), so there is no event source to replace it safely.
- Offer Copy entries for Companion layouts saved on other characters, ahead of older same-named Blizzard imports. Copy the complete profile into an independent per-character save; preserve frames that are not available yet. Add `/gpc edit copy Name` and show source choices for duplicate names.
- Native layout imports skip unavailable frames and dependent anchors instead of rejecting all usable positions. Report skipped frames, preserve the source, and retain validation for malformed anchors and circular dependencies.
- Add regressions for new-character copying, source isolation, panel Copy/Load selection, same-name native layouts, combat/error guards, missing frames/anchors, and invalid imports.

- Keep dynamic camera pitch enabled and character centering disabled after login and native input-mode switches, including Forever's temporary gamepad CVar overrides.

- Poll live input only for subscribers or an open editor; default bars without consumers sleep. Audit unchanged customized bar geometry at most twice per second, separate from input checks, and pause geometry-only polling during combat. Native bar callbacks and game events still refresh immediately.
- Move closed-editor form discovery out of input polling. The options window unsubscribes when hidden. The Edit Mode watcher sleeps in keyboard mode and after faults; controller editor checks run twice per second, with the existing four-per-second cadence retained for active cooldown overlays.
- Add regression coverage for timer demand, idle geometry reads, native repaint recovery, editor subscriptions and watcher wake/sleep behavior.

- Add a Stance tab for independent position, scale and active zoom of Blizzard's shared stance/form bar. Preserve native form actions and override routing; defer geometry edits in combat and restore the native layout on reset or disable.

## 0.1.24 — Keep the form editor visible in Cinematic

- Register the form overview and spread captions with Frame Gambit's scene-provider API. Cinematic no longer blacks out these LOW-strata editor surfaces; they remain below the spellbook and still hide when Spread view closes. Registration supports either addon load order.

## 0.1.23 — Editable form bars

- Use native square D-pad and round face-button artwork, icon masks, shadows and hover rims in the form overview. Empty slots follow the current controller symbol set.
- Accept spell, item and macro drops into validated form storage outside combat. Replacing an occupied slot retains its old action on the cursor; failed replacement attempts restore it. Dragging out picks up the existing action. These editor buttons do not cast actions.
- Place the overview and all spread captions below the spellbook and other normal panels. Read icons through the client's C_ActionBar.GetActionTexture API when available.
- Lua 5.1 and LuaJIT regression checks pass for form discovery, captions, drag/drop, replacement, rollback and combat blocking. In-game drop acceptance and appearance require a reload and live check.

## 0.1.22 — Form spread overview and Forever options

- Add all five client-defined form storage groups as previews on the left of Spread view, validating each slot before reading it. Highlight the active group and remember observed form names per character, including stealth. Unidentified groups remain numbered; no native form or binding is changed to discover them.
- Caption the regular bars with their current page and trigger combination. Previews close with Spread view and do not execute or change actions.
- Match the other Forever addons with native leather, gold-rimmed controls, warm text and the red close button in options and help. Preserve native spellbook/macro button handlers.
- Lua regression coverage checks group discovery, changing forms, character isolation, reload, editor lifecycle and layout restoration. Live appearance still needs an in-game check.

## 0.1.21 — Cooperate with root opacity fades

- Submit viewer alpha through its SetAlpha method so Frame Gambit's secure posthook composes opacity immediately. The prototype C call bypassed that hook and repeatedly exposed Companion alpha until Frame Gambit's next audit. Do not resubmit unchanged alpha each tick.
- Capture opacity from native Edit Mode setting metadata when available, and do not infer opacity edits from a third-party animation. Preserve the saved opacity when metadata is unavailable.
- Add a regression that simulates root alpha composition and verifies no repeated fade requests or accidental saving of transient alpha. This addresses the identified blinking path; the remaining aura-table taint is unresolved and requires a client taint log.

## 0.1.20 — Isolate cooldown presentation from native aura state

- Replace cooldown runtime preference/grid writes with an addon-owned presentation layer. Do not assign any Lua fields on native viewers or pooled items, call their setting/layout/data helpers, or set their managed-frame opt-out flags. Those fields are consumed later by secure aura callbacks, so avoiding only RefreshData was insufficient.
- Apply icon scale, layout, spacing, opacity, timer/tooltips and bar appearance through C frame/region methods. Reapply to new native items on the existing out-of-combat tick; do not repaint while either editor is open. Save native editor changes without rewriting Blizzard metadata. All existing profile data is retained.
- Visibility/hide-inactive are suppression overlays only: Blizzard owns native Show/Hide and may still hide a viewer/item. To keep an always-visible overlay available, its native visibility must allow it. Secret activity booleans are passed directly to SetAlphaFromBoolean, never used in Lua conditions.
- Preserve the previous error but start a fresh restoration attempt on reload/login. New errors still stop restoration for the rest of that session; there is no automatic same-session retry loop.
- Replace the permissive cooldown mocks with immutable native objects that reject every Lua field write, including existing keys, and all native mutator helpers. Verify native edits, reacquired items, presentation release, legacy decoding and fresh-session recovery. Live client taint behavior still requires verification after a clean reload.

## 0.1.19 — Avoid protected aura refresh during cooldown restoration

- Replace addon calls to cooldown `RefreshLayout` and `UpdateShownState` with cosmetic layout of the existing item pool. Full refresh re-registers aura IDs in a secure table and fails at CooldownViewer.lua:1691 when called from addon execution. Do not release/acquire items, fetch spell data or evaluate live aura visibility during restoration.
- Restore icon scale, grid, spacing, timers, tooltips and bar appearance on existing items; retain preferences for native acquisition. Visibility and hide-inactive transitions are handled on subsequent Blizzard lifecycle updates, not forced from the addon.
- Detach saved cooldown roots from managed containers before changing child geometry. Preserve profiles and the blocked-action latch; after loading this update, `/gpc edit retry` explicitly retries restoration. Failed retries now report failure instead of claiming completion.
- Regression tests reject native pool rebuilds, data refresh and viewer visibility calls during addon apply/release. These verify the reported call path is removed, not live WoW security behavior or the separate SetPreferredGamepadInteractTarget failure.

## 0.1.18 — Blocked-action diagnostics

- Record the last three blocked-action reports with the native event stack, active profile, editor/apply state and twelve recent addon operation breadcrumbs. Capture delayed reports even when placement is already stopped; do not hook protected gamepad methods or clear the security stop.
- `/gpc edit error` displays the latest captured stack. Reports persist with the existing saved variables on reload/logout. No saved layout is rewritten by diagnostics.
- This is an investigation build, not a confirmed fix for `SetPreferredGamepadInteractTarget()` failures. Offline tests verify bounded reporting and profile preservation, not WoW taint behavior.

## 0.1.17 — Cooldown viewer settings and placement

- Save and restore all twelve Edit Mode display preferences across Essential Cooldowns, Utility Cooldowns, Buff Icons and Buff Bars: orientation, row/column limit, direction, icon size, spacing, opacity, visibility, bar content, hide-inactive, timers, tooltips and bar width. Preferences apply where supported by each viewer.
- Decode previously saved raw cooldown settings and imported native slider values without rewriting the original profile. Use runtime display preferences and the viewer's own layout methods; do not alter native systemInfo, dirty-setting, selection or snap tables.
- Move saved viewers outside managed layout containers while active, restoring their parent/opt-out flag on release. Let the native grid compute dimensions instead of forcing stale saved outer sizes. Repair later native reparenting only outside combat/Edit Mode; queue restoration after module loading or enable-CVar changes.
- Add tests using actual Blizzard grid-refresh, item-acquisition and visibility methods, plus end-to-end profile save/reopen, dynamic icon counts, legacy settings, import, combat, mode switching and reload.
- Native setting widgets still read the preset's metadata. Saved appearance is restored independently. Spell selection/order remains in Blizzard's own cooldown configuration. The earlier blocked-action issue is not claimed fixed; the persistent stop remains enforced.

## 0.1.16 — Gamepad cast bar edits

- Bridge the actual native Cast Bar preview (`PlayerCastingBarFrame`) to the separate gameplay frame (`GamepadPlayerCastingBarFrame`). Save the edited preview's position, dimensions, effective scale and Show Cast Time setting under the gamepad frame's name.
- Restore the saved placement to both gameplay and the editor preview while editing; release the preview on exit. Temporarily reparent edited cast bars out of automatic layout containers through base frame methods. Native layout, selection, event handlers and shared system tables remain untouched.
- Interpret older two-bar saves using the edited preview snapshot without overwriting the stored profile. Resolve the duplicate cast-bar system ID deterministically during import, including encoded size and cast-time settings.
- Regression tests execute Blizzard's actual preview selection, input-mode cast event routing and cast-time setter. They cover save/reopen, keyboard restoration, drag stability, combat deferral, old profiles, imports and reload. Live validation remains required.

## 0.1.15 — Objective tracker placement and height

- Save the objective tracker's top-left edge and requested viewport height separately, instead of restoring a center point that moves when Blizzard changes the height. Read the encoded native Height setting on import.
- Place the tracker under an addon-owned anchor whose height lets Blizzard's default height calculation retain the saved viewport. Temporarily opt out of automatic OnShow enrolment and keep native layout/settings/snap/managed-frame tables untouched. Restore the original parent and opt-out flag on release.
- Repair a later native reparent once outside combat and Edit Mode. Never continuously repaint the tracker or replace its native height/drag functions. Keep older center-based saves compatible without rewriting them.
- Add regression coverage using the matching client's actual tracker height and managed-frame methods: scaled geometry, save/exit/reopen, late native resets, native dragging/resizing, default/keyboard release, combat deferral, reload, imports and unchanged-state stability.
- The native Height slider can still be hidden by Blizzard's default-position flag. Drag the tracker slightly to expose it, adjust the height, then use Companion Save here. Saved height restoration no longer depends on that slider being visible. Live verification remains required.

## 0.1.14 — Settings and rejected-size fix

- Stop treating self-sizing container dimensions as a blocked action. Continue verifying anchors/scales and stopping on real rejected calls; include the frame name in failures. Release only the obsolete exact 0.1.13 size-error latch.
- Validate the next placement before writing it and retain currently applied frames while switching profiles, instead of first resetting every frame to its baseline.
- Save/reapply minimap header-underneath and map/header scales, compact party/raid member width/height, and objective text size/opacity. Reapply on roster/pet/quest changes outside combat. Read stored native setting conversions when importing supported settings.
- Keep the five most recent overwritten profile revisions. `/gpc edit recover` restores the latest revision under a new name. Preserve raw saved system settings for future migration; do not write them into Blizzard's live tables.
- Add `/gpc edit diagnose` for a read-only native API/schema report. Native layout integration findings are documented in NATIVE-EDIT-MODE.md.
- Offline settings, self-sizing, recovery, and existing regression tests pass. Live validation remains outstanding.

## 0.1.13 — Independent controller placement profiles

- Replace the failing native Edit Mode integration with Companion-owned Save/Load controls beside Edit Mode. Continue to use Blizzard's editor to move/resize frames; save their placement through Companion's panel.
- Keep profile data separate from Blizzard's layout tables. Do not hook native Edit Mode methods, rebuild its dropdown, register exit callbacks, rename profiles, or call C_EditMode mutators.
- Recover moved positions from existing Blizzard layouts, including `[GP]` layouts, using Import. Imported size/settings values are not applied; resize in Edit Mode and Save here to capture rendered size. Non-geometric settings (orientation, icon counts, visibility rules) remain Blizzard-owned.
- Apply geometry through frame base methods outside combat, avoiding the native Edit Mode method overrides that update its anchor/snap metadata. Restore on editor exit and input-mode transitions, without continuous placement retries.
- Stop automatic placement on a rejected write or a Gamepad Companion blocked-action event. Preserve that stop across reloads until an explicit retry. Tests prohibit native layout mutations/hooks and exercise both thrown and event-reported failures.
- This addresses the identified unsafe code paths; live behavior still requires validation after a fresh client start.

## 0.1.12 — Edit Mode recovery

- Stop loading the experimental Edit Mode integration after a live report of rejected controller layout selection, a blocked-action popup on exiting Edit Mode, and a client freeze.
- Replace it with an inert status command. No native Edit Mode hooks, layout writes, selections, timers or exit callbacks are installed by the recovery module.
- Preserve native saved layouts and both Companion databases. Existing bar controls remain available. Restart the client to clear the previous session's hooks and taint.
- The earlier offline harness assumed the native client accepted custom controller layouts and did not model WoW's taint restrictions. Its passing results did not establish live compatibility.

## 0.1.11

- Merge the standalone Gamepad Edit Mode workaround into Gamepad Companion. Normal controller Edit Mode saves retain the `[GP] ` tag, and input-mode layout selection is restored per character.
- Add `/gpc edit`, `/gpc edit list`, and `/gpc edit convert Name`; retain `/gpedit` as an alias. Add an Edit Mode topic to Help.
- Import standalone layout choices once into Companion-owned saved data. Bar settings, resets and saves do not overwrite Edit Mode choices. Retire the installed standalone addon to avoid duplicate hooks.
- Native-method regression tests pass offline; in-game validation remains pending.

## 0.1.10

- Run the Macros button through Blizzard's out-of-combat action template and native `/macro` command instead of calling the macro panel opener from addon Lua. Preserve GPC and Spread view during panel opening.

## 0.1.9

- Open Spells through the same native hardware-click delegation used by BindCards, preserving the action template and checking Blizzard's input restrictions. Remove direct spellbook opener calls and show guidance when delegation is unavailable.
- Preserve the editor and Spread view across temporary native panel closure when opening Spells or Macros.

## 0.1.8

- Reveal Frame Gambit-managed controller bars while Gamepad Companion is open.
- Add temporary Spread view for the four action bars, plus Spells and Macros buttons that leave the companion open. Turning Spread view off or closing the window restores saved placement; combat defers geometry restoration.
- Keep editing state out of saved settings. Add coverage for spread restoration, opacity override and editor button lifecycle.

## 0.1.7

- Keep shoulder visuals and page numbers fixed during active zoom and bar/page changes. They follow saved Base position and scale, with a stable visual-center offset, rather than moving with live button bounds.

## 0.1.6

- Center linked shoulder artwork and page numbers over the visible action buttons, accounting for the native square/circle layout's asymmetric bounds and effective UI scale.
- Expose left, right and both shoulder buttons held through the state provider for Frame Gambit conditions. Unreadable input remains unknown.

## 0.1.5

- Make the 1–2–3 page selector follow Base movement, scale and active zoom while preserving its spacing above the bar.
- Restore its native layout on reset or disable, and defer changes during combat like the linked shoulder controls.

## 0.1.4

- Make the green/red shoulder artwork, backgrounds and pressed highlights follow Base movement and scale.
- Apply Base layout to the friendly, hostile and two-shoulder shortcuts bars, including active zoom while a shoulder bar replaces Base.
- Keep native parents, opacity and input behavior intact; restore native anchors/scales on reset or disable and defer geometry writes during combat.
- Add Lua 5.1/LuaJIT regression coverage for shoulder geometry, overrides, combat deferral, native repaints and restoration after a rejected write.

## 0.1.3

- Publish native bar-selection state synchronously through one secure posthook so Frame Gambit can apply opacity without either evaluator's polling delay.
- Keep the synchronous path free of geometry writes, including during combat and reentrant settings callbacks; retain polling for other state and layout work.

## 0.1.2

- Restore layout controls, out-of-combat active zoom and the Frame Gambit provider.
- Replace native hooks and input-manager callbacks with bounded observation.
- Reconcile geometry against the latest observed native layout without repeatedly adding offsets; preserve native changes when releasing control.
- Keep combat changes deferred and native bindings and trigger behavior unchanged.

## 0.1.1 — recovery

- Suspend native controller integration after a blocked-action report; stop loading the old core entirely.
- Remove loaded paths to native callbacks, hooks, geometry and frame-provider exposure, including with default settings.
- Preserve saved settings and show a paused state. A clean client restart is required to clear the previous session's hooks/taint.

## Unreleased


- Add reversible per-bar offsets and base size for Blizzard's Forever controller bars.
- Add an out-of-combat active size multiplier and compact options/help windows.
- Publish a versioned gamepad-state adapter for Frame Gambit and future BindCards integration.
- Keep native input, bindings, menus and action storage unchanged.
- Defer live conditional gamepad overrides and trigger toggles pending secure integration validation.
# 0.2.1

- Add `/gpc edit export Name` to create a native gamepad layout from the current
  character's active Companion snapshot, rather than a same-name Blizzard layout.
- Preserve originals, verify native save readback before handing over placement,
  and retain Companion placement on failure. `exportcheck` previews the export.
- Translate saved geometry and visual preferences into native settings, including
  chat dimensions, objective height and cast scale; report native limits.
