# The pad stuck after a window: jump and Interact dead until /reload

Forever 1.60.1, gamepad mode. After the Auction House (Auctionator), the mailbox or another
window, Cross (Interact) and the jump button do nothing. Spells still work. Only `/reload` helps.
Companion says `Pad stuck by <addon> · hold Cross to reload` (Cross held 1 s reloads) and keeps
the evidence in its trace (`errors`).

## The chain (Blizzard's, from !BugGrabber's stacks, 2026-11-24)

```
HideUIPanel                                   UIParentPanelManager.lua:933 -> :133 -> :530 -> :563 -> :513 -> :486
EventRegistry "UIParentPanelManager.ForcePanelHide"
FrameControlsManager:FrameHidden              FrameControlsManager.lua:473 -> :549
CheckForInputBinding                          FrameControlsManager.lua:114 -> :122
GamepadMode.DeactivateBindingGroup            BindingSetFactory.lua:254
InputBindingManager:RemoveSet                 InputBindingManager.lua:173 -> :190
CheckCoreBindingActive                        InputBindingManager.lua:38 -> :42   (only-core flipped: listeners)
UpdateActionBarFocusedState                   MainActionBarFrame.lua:41 -> :57
UpdateInteractIcons                           MainActionBarFrame.lua:355 -> :373
SetPreferredGamepadInteractTarget             protected: refused when the execution is tainted
```

Twelve addons have been blamed for the same chain (Auctionator, Details, CompanionJournal,
DungeonMap, Spoken, GamepadCompanion, BugSack, GraphicsLab, ...): whichever addon's taint is on
the closing. The closing picks it up when the window's `OnHide` (or a child's) reads a field that
addon wrote. For the Auction House that is Auctionator driving Blizzard's frames from its own
code: `AuctionHouseFrame.displayMode = nil` (LibAHTab.lua:90, Buying/Item/Main.lua:39,
Buying/Commodity/Main.lua:78), `AuctionHouseFrame:SetDisplayMode({})` (LibAHTab.lua:89),
`ItemSellFrame:SetItem(nil)` / `CommoditiesSellFrame:SetItem(nil)` (Selling/Hooks.lua:7-8),
`CachePendingPost` (SaleItem.lua:725, :732), `SetCustomError` (DirectSearchProviderMixin.lua:101).
`AuctionHouseFrame:OnHide -> ClearPostItem -> SetItem(nil)` reads that state before writing it.
Which field exactly: the trace's `SLOTS` line says next time (`issecurevariable` on each).

## Why it stays stuck

The refused call is a no-op; the rest of the listener runs tainted. It rewrites every HUD button's
`ApplyExtraButtonStylesForState` closure (ActionBarStyles.lua:214, :227) and the manager's
`currentCoreBindingActive` and `activeBindings`. Cross, jump and back are plain `OnClick`
handlers (MainActionBarFrame.lua: SetupNonBindableJump, SetupNonBindableInteractFunction) that
call `ApplyPressedStyle` first, which reads that closure: from then on `RunBinding("JUMP")`,
`InteractUnit`, `AttackTarget` are refused. Spell buttons use secure attributes and keep working.
Every later hand-back reads the tainted manager fields before writing them, so no secure
rewrite ever happens: `/reload` is the only way out. Companion cannot clean a Blizzard field.

## 2026-11-25: the name can lie

- Tonight's first block (GPC trace 1537489.39) came on a quest-log toggle, 13 s after the
  Auction House closed (pad moves on `LibAHFrame-1.0-AuctionatorTabs_Selling`, Auctionator's
  config tab, `AuctionatorPostButton`, then Blizzard's Buy tab, 1537353-1537476). Yesterday's
  (1470386) also came after pad use in the AH. The AH's own fields (`ah.*` slots) were clean.
- First tainted slot: `activeBindings[PADLTRIGGER]`. L2 there is the focus manager's
  `FocusPreviousFrame` (FrameControlsManager.lua:193), activated by `CheckForInputBinding`,
  which runs on every `FrameShown` / `FrameHidden`. Those run from EventRegistry's
  `UIParentPanelManager.ShowUIPanel` / `HideUIPanel` callbacks, in the caller's taint: any
  insecure `ShowUIPanel` / `HideUIPanel` (or a popup shown from addon code) writes it.
- Auctionator's own code calls none of ShowUIPanel, HideUIPanel or StaticPopup_Show.
- The name is a LibStub stamp. The game names the addon whose value the execution read last.
  Auctionator's `Libs/LibStub` loads first, so the `LibStub` global is Auctionator's. The
  2026-11-20 taint log shows GatherMate2's `HBD`, Details' DF frames and BugSack's LibDBIcon
  all "tainted by Auctionator", each right after a `LibStub(...)` call. So "Auctionator" may be
  any addon that calls LibStub and then drives a Blizzard panel.
- Not proven which addon: no taint log ran tonight. `PadRescue.lua` now catches it (below).

## The way out

`PadRescue.lua`: while stuck, a Passage line at the bottom left ("Pad stuck", Cross glyph,
"Hold to reload"); Cross held 1 s, out of combat, calls `ReloadUI()`. It reads the pad
(`C_GamePad.GetDeviceMappedState`), binds nothing and takes no input. A Cross already held when
the line comes up counts only after a release.

## Catching the writer

`PadRescue.lua` post-hooks (hooksecurefunc, reads only) the focus manager (`FrameShown`,
`FrameHidden`, `SetUIFocusState`, `SetFallThroughCatcherActive`, popups, `FocusNext/Previous`),
`GamepadMode.Activate/DeactivateBindingGroup` and the binding stack (`AddBindingSet`,
`RemoveSet`, `AssumeCoreBindingsAreUsable`). After each call it reads the slots
(`Keys.PadSlots(into)`). The first slot newly tainted (vs. login) gets, once a session:

```
TAINT FIRST binding PADLTRIGGER=Auctionator after ActivateBindingGroup(...); clean after FrameShown
TAINT STACK <the caller's Lua stack: the addon file that drove Blizzard's code>
```

A 1 s check catches a write no hook saw (its stack is ours: only the time counts).

## What Companion does

- `Keys.Blocked`: on the game's ADDON_ACTION_BLOCKED / FORBIDDEN for that function, the trace
  gets `BLOCKED`, `STACK` (the Lua stack of the refused call: Blizzard's frames and the addon's),
  `SLOTS` (which slots are tainted, by whom) and `SLOTS+1` a frame later. First three a session.
- `Keys.PadHealth` every 5 s out of combat: Cross's closure tainted means the pad is stuck, even
  with no event seen; `STUCK by <addon>` and `SLOTS` in the trace, said once per addon.
- Reads only (`issecurevariable`); nothing of ours is written into Blizzard's tables.

## To test in game

1. Open the Auction House, switch to an Auctionator tab (Shopping or Selling), close the window
   with its X. Try jump. If dead: `/gpc trace` or read `GamepadCompanionTraceDB.errors`.
2. Same, but switch back to Blizzard's Buy tab before closing. If jump survives, the tainted
   field is one Blizzard's own `SetDisplayMode` rewrites.
3. While stuck, toggle the gamepad off and on in Settings (secure re-init). If jump returns,
   the re-init rewrites the closures securely; the next window may stick it again.
