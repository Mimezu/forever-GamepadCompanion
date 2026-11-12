# Touchpad zones

`/gpc touch on` turns them on. Blizzard's own touchpad function (an open window takes the
pad, or gives it back to the world) stays reachable in both modes:

- **Mode B, chord** (default, `/gpc touch mode chord`): the whole pad is six zones (3 × 2)
  while the world has the pad, even with windows open. A focused window gets the plain click
  back, so one click takes you out of it. **L1 + touchpad** always runs Blizzard's function,
  in combat too. Change the button with `/gpc touch chord PADRSHOULDER`.
- **Mode A, split** (`/gpc touch mode split`): a gamepad config makes the touchpad's right
  half its own button (`PAD6`), with three zones top to bottom. The left half stays
  Blizzard's. Turning it off (or `/gpc touch restore`) puts your controller config back.

Setting zones (no settings tab yet):

- `/gpc touch set tl character`: a game window (`/gpc touch windows` lists them).
- `/gpc touch set tr lt`: with a spell, item or macro on the cursor, the L2 layer's zone.
- `/gpc touch clear tl`, `/gpc touch list`.
- Zones: `tl tc tr bl bc br` in mode B, `top mid bot` in mode A. An empty L2 / R2 zone uses
  Base.

While your finger moves on the pad, a small drawing of it shows each zone and lights the one
under your finger (`/gpc touch preview off` hides it). `/gpc touch probe` prints what the pad
reports; `/gpc touch debug on` prints each click's zone. If Improved Forever's touchpad corners
are on, mode B stays out of their way.

The secure-click method comes from Improved Forever's touchpad corners (markgravity, MIT).
