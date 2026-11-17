# Release UI audit (0.37.0, 2026-11-17)

Two reviews of every page, popup and picker, from the code: a brand-new player installing it
tomorrow, and a senior UI designer. Most visible first. ✔ fixed in 0.37.0 · ◻ left (why).

## A new player

| | Found | Done |
|---|---|---|
| 1 | **Edit was a trap** without WoW Helper: a copy made and assigned at once, into the hidden Lab; a second click, a second copy | ✔ Edit shows only with Tools › Lab or WoW Helper; your own copy reopens, no second copy |
| 2 | **Tab order not fixed** (Gestures and Bars both 3, Setup and Tools both 4) | ✔ 1 Controller · 2 Moments · 3 Gestures · 4 Setup · 5 Bars · 6 Tools · 7 Help · Lab |
| 3 | WoW Helper a dead end (no link to get it) | ◻ no public download yet (private repo); Setup says what to run |
| 4 | Jargon: "HD" label, "No data", Try saying "rumble (HD link off)", "Lights: game", Lab "Mixer, probes, editor", `/gpc beta` in Help | ✔ Detail, Not read yet, Try names the moment only, gone, Advanced, removed |
| 5 | Every light row: "Game" / "WoW Helper" | ✔ only "While it lasts" |
| 6 | Help › Profiles out of date | ✔ Controls · Feel · Recommended · the footer's chips |
| 7 | "Light" card vs "Base colour" everywhere else | ✔ Base colour |
| 8 | Profile menu: profiles and actions with a feel icon each; "For new Death Knight: on" truncates; "Reset Thrall?" | ✔ plain words, no icons; "Class start"; "Back to Recommended?"; opens upward |
| 9 | Touch zones off by default, editor still live | ◻ next pass (ControllerWindow) |
| 10 | Your spells: "Guess", "the rules" | ✔ when only; "As it ships" |
| 11 | Hit delay without a label; "Rising… Felt it"; Battery blank | ✔ Delay; "Rising · click Felt it"; "Battery —" |
| 12 | Edit Mode layouts card for players with nothing to convert | ◻ next pass |
| 13 | "Rumble off" | ✔ Feel off |
| 14 | "True haptics" among the Triggers | ✔ WoW Helper card: USB feels |
| 15 | Light picker's colour chips "·, B, S" | ◻ the Lights session's picker |
| 16 | The palette's empty Yours | ◻ next pass |
| — | First run: Recommended shows many red Off rows | ◻ a "calm set" mark: next pass |

## A senior UI designer

| | Found | Done |
|---|---|---|
| 1 | Gestures: two full-height cards, 55% empty | ✔ cards hug their 6 rows |
| 2 | Tab order collisions | ✔ (above) |
| 3 | Footer status ran under the profile chips | ✔ narrower |
| 4-5 | Header switch and segment at different x per page | ◻ `Shell.HeaderSwitch`, `HUI.Segment`: next pass |
| 6 | Setup columns misaligned, dead space | ✔ both columns break at 200 / 210 |
| 7 | Gaps 10 / 12 / 16 | ◻ `S.GAP`: next pass |
| 8 | Popups over their anchor or off the window (footer chips) | ✔ `HUI.Popup(…, up)` for the footer; PickFeel ◻ |
| 9-10 | Two swatch grids, three "light now" tickers | ◻ `HUI.Swatches`, `HUI.LedNow`: next pass |
| 11 | Hand-made steppers in the touch panel | ◻ next pass |
| 12-13 | List buttons in five sizes; selected state in five alphas | ◻ `HUI.ListButton`, `S.SELECT`: next pass |
| 14 | Red for Off, warnings and an action | ◻ next pass (warnings yellow) |
| 15 | Empty-label Choice hack | ◻ `HUI.Choice` labelWidth: next pass |
| 16 | Developer text: "%ds ago", "· Guess", Game/WoW Helper per row | ✔ (ago, Guess, per-row driver gone) |
| 17 | Explaining sentences on Tools | ◻ next pass |
| 18 | Moments left card buttons unaligned | ◻ next pass |
| 19 | Tooltips repeating the name | ◻ next pass |
| 20 | "Light" vs "Base colour" | ✔ |

## Re-check

Both reviewers re-read the fixes. Leftovers, fixed: the footer status still ran under the
left chip (now `Shell.W - 600`); Delete's list opened downward; plain-word tiles kept a 30 px
icon gap; Help still named Edit; Setup's "%.2f/s", "a guess", "learned · N", "Data · N
sounds" (now Synced / Learned / Not synced, "Read 18:02"). Still left: Controller's second
status line ("Drag: pick up · Drop: bind") and the 9 pt credit on Moments; Base colour's card
is full height with room to spare.
