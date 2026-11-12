# Adaptive triggers (idea, not built)

Research notes, 2026-11-12. Nothing here is in the addon yet.

## Goal

DualSense trigger resistance and effects driven by game events, as a second
choice next to each Rumble event: R2 stiffening while a cast builds, a click
per shot or swing, a buzz in the trigger at low health, light resistance while
a layer is held.

## What the game allows

- `C_GamePad` has `SetVibration(type, intensity)`, `StopVibration`, the light
  bar (`SetLedColor`, `GetLedColor`, `ClearLedColor`) and `GetPowerLevel`.
  No trigger effect call.
- The client drives the DualSense with SDL's HIDAPI PS5 driver (its hint names
  are in the executable). There `RumbleJoystickTriggers` is unsupported, so the
  `LTrigger` / `RTrigger` vibration types most likely do nothing on a DualSense
  (check with `/gpc rumble test`).

## Why a helper could work

From SDL's `SDL_hidapi_ps5.c` (SDL2 branch, read 2026-11-12; the client may
ship another version):

- `UpdateEffects` zeroes the effects block on every send and sets only
  rumble (`ucEnableBits1` 0x01 / 0x02, `ucEnableBits3` 0x04 on firmware
  2.24+), LED and pad-light bits (`ucEnableBits2`).
- It never writes `rgucRightTriggerEffect` (offset 10) or
  `rgucLeftTriggerEffect` (offset 21) and never sets their enable bits
  (`ucEnableBits1` 0x04 right, 0x08 left). The controller ignores the zeroed
  trigger bytes, so an effect set by another program should survive the
  game's rumble and light bar updates.
- Packets go out on change only, plus a Bluetooth keep-alive that should have
  no effect.
- Windows normally lets two programs open the pad at once (not with
  DS4Windows exclusive mode or HidHide).

## Design

1. **Addon -> helper:** addons can't write files live, use the network or
   start programs. The addon draws a few pixels in a screen corner (parent
   nil, top strata, shown with the UI hidden). Each colour channel is on/off
   (threshold 128) so gamma and brightness don't matter; a marker pixel and a
   checksum let the helper find and trust it. About 12 bits per trigger:
   effect mode, start, end or strength.
2. **Helper:** reads the pixels 30 to 60 times a second (GDI or desktop
   duplication; windowed or borderless display mode only) and writes only the
   trigger part of the output report: USB report 0x02, or Bluetooth 0x31 with
   its sequence byte and CRC32. Rumble and LED flags left off. Writes on
   change only (very fast writes buzz under finger pressure, per the Forza
   project notes). Python with hidapi, or hosted in BridgeControl.
3. **Addon side:** a "Trigger" choice per Rumble event (Rumble.lua's events,
   casts with their progress, Halo rings), and a Triggers card on the Rumble
   page.

Not DualSenseX: it hides the real pad and presents a virtual one, so the game
would stop seeing a DualSense (touchpad zones and PlayStation glyphs break).

## Effect modes (Sony's trigger modes, as community tools use them)

- Off / neutral (0x05 returns the stop to neutral; 0x00 only clears).
- Continuous resistance from a start point, with a force.
- Section resistance (start, end, force).
- Weapon: a click between a start and an end point.
- Vibration in the trigger: start point, amplitude, frequency.
- Multi-position feedback and vibration (per-zone strengths).

Exact byte layouts: check against a current source (OpenDS5 Trigger Lab,
pydualsense) before building.

## Open questions (decide whether to build)

1. Does an outside program's trigger effect hold while the game runs, on
   USB and on Bluetooth? Test first: a standalone helper script that puts
   resistance on R2 with the game open, then rumble from the Rumble page.
2. Does the game ever reset the triggers (reconnect, focus change, UI mode)?
3. How reliably do the corner pixels read with the player's display settings?

Blizzard has not ruled on screen-reading helpers. This one only reads pixels
and writes to the controller (no key presses), like RGB lighting tools.

## Sources

- SDL source: https://raw.githubusercontent.com/libsdl-org/SDL/SDL2/src/joystick/hidapi/SDL_hidapi_ps5.c
- Rumble enable bits: https://skia.googlesource.com/third_party/sdl/+/99e8f00f7a842ed69ca06d9ef88fbfe79c11c9a1%5E%21/
- SDL custom effects (SendEffect): https://discourse.libsdl.org/t/sdl-added-sdl-gamecontrollersendeffect-and-sdl-joysticksendeffect-to-allow-applications-to-send-custom-effects-to-the-ps4-and/32082
- DualSenseX: https://dualsensex.com/game-devs/ and https://github.com/Paliverse/DualSenseX
- Forza trigger notes (DSX modes, write timing): https://git.sigkill.computer/titaniumtown/nixos/src/commit/bb640b4b538ed3a7a98a942a3e8266a8691c9452/hosts/yarn/forza-trigger/forza_trigger.py
- OpenDS5 Trigger Lab: https://github.com/LordVicky/OpenDS5/wiki/Trigger-Lab
