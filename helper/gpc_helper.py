"""Gamepad Companion helper: reads the addon's corner strip, drives DualSense triggers and haptics.

    python gpc_helper.py --list | --selftest | --dry-run | --run | --demo-triggers | --demo-audio

Protocol: docs/HELPER.md. Python 3.12 standard library only (ctypes for Windows).
"""
import argparse
import ctypes
import os
import sys
import threading
import time
from ctypes import wintypes

sys.dont_write_bytecode = True   # (no __pycache__ in the addon folder)
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import protocol  # noqa: E402
from protocol import State, Trigger, DecodeError  # noqa: E402

VERBOSE = False


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def vlog(msg):
    if VERBOSE:
        log(msg)


# --- Link logic (pure, tested) ------------------------------------------------------------

class Link:
    """Turns decoded frames into actions. A frame counts once it was read `confirm` times in a row;
    triggers follow every new state, an event fires when the sequence number changes."""

    def __init__(self, confirm=2):
        self.confirm = max(1, confirm)
        self.pending, self.count = None, 0
        self.current = None

    def feed(self, state):
        """-> (new State or None, (event, gain) or None)"""
        if state == self.pending:
            self.count += 1
        else:
            self.pending, self.count = state, 1
        if self.count != self.confirm or state == self.current:
            return None, None
        prev, self.current = self.current, state
        event = None
        if prev is not None and state.seq != prev.seq and state.event:
            event = (state.event, state.gain)
        return state, event


def gain_factor(gain):
    """Event gain 0-7 -> 1/8 .. 1 (0 is the quietest, not silent)."""
    return (gain + 1) / 8


# --- Safety: reset on any exit --------------------------------------------------------------

class Session:
    def __init__(self):
        self.out = None      # dualsense.TriggerOutput
        self.pad = None
        self.player = None
        self.stop = threading.Event()
        self._lock = threading.Lock()
        self._closed = False
        self._handler = None

    def install(self):
        HANDLER = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.DWORD)

        def on_ctrl(kind):   # Ctrl+C, Ctrl+Break, window closed, logoff, shutdown
            self.stop.set()
            if kind != 0:    # (Ctrl+C: the main loop cleans up; the others may not return)
                self.close()
            return kind != 0
        self._handler = HANDLER(on_ctrl)
        ctypes.WinDLL("kernel32").SetConsoleCtrlHandler(self._handler, True)

    def close(self):
        with self._lock:
            if self._closed:
                return
            self._closed = True
        if self.player:
            try:
                self.player.close()
            except Exception as e:  # noqa: BLE001
                log(f"audio close: {e}")
        if self.out and self.pad:
            try:
                self.out.reset()
                log("triggers reset (off)")
            except Exception as e:  # noqa: BLE001
                log(f"trigger reset failed: {e}")
        if self.pad:
            self.pad.close()


def open_pad(args):
    import dualsense
    pads = dualsense.find_dualsenses()
    if not pads:
        return None
    info = pads[0]
    pad = dualsense.Pad(info, transport=args.transport)
    log(f"pad: {info['name']} over {pad.transport.upper()} (output report {info['out_len']} bytes)")
    return pad


def open_audio(args):
    import audio
    if args.no_audio:
        return None
    dev = audio.find_dualsense_device() if args.audio_device is None else (args.audio_device, "chosen", 0)
    if not dev:
        log("audio: no DualSense output device (USB only): haptic clips and sounds off")
        return None
    log(f"audio: device {dev[0]} '{dev[1]}'")
    if dev[2] and dev[2] < 4:
        vlog(f"audio: the device reports {dev[2]} channels; trying 4 (check Sound settings: Quadraphonic)")
    try:
        return audio.Player(dev[0], channels=4, frames=args.audio_frames, buffers=args.audio_buffers, log=log)
    except OSError as e:
        log(f"audio: {e}")
        return None


# --- Modes ------------------------------------------------------------------------------------

def do_list(args):
    import screen
    import dualsense
    import audio
    screen.dpi_aware()
    print("WoW windows:")
    wins = screen.find_wow_windows()
    for h in wins:
        print(f"  hwnd {h:#x}  '{screen.window_title(h)}'  client {screen.client_rect(h)}")
    if not wins:
        print("  (none)")
    print("DualSense (HID, opened without access; nothing written):")
    pads = dualsense.find_dualsenses()
    for p in pads:
        print(f"  {p['name']}  {p['transport'].upper()}  out {p['out_len']} in {p['in_len']}  {p['path']}")
    if not pads:
        print("  (none)")
    print("Audio outputs:")
    match = audio.find_dualsense_device()
    for i, name, ch in audio.list_devices():
        mark = "  <- DualSense" if match and match[0] == i else ""
        print(f"  {i}: {name} ({ch} ch){mark}")
    return 0


def run_loop(args, dry):
    import screen
    import clips
    screen.dpi_aware()
    s = Session()
    s.install()
    library = clips.build_all()
    out = None
    if not dry:
        import dualsense
        try:
            s.pad = open_pad(args)
        except OSError as e:
            log(f"pad: {e}")
        if not s.pad:
            log("pad: no DualSense found; will look again every 5 s")
        s.out = out = dualsense.TriggerOutput(s.pad, legacy=args.legacy_triggers, log=vlog)
        s.player = open_audio(args)
    reader = screen.StripReader(use_foreground=args.foreground)
    link = Link(args.confirm)
    period = 1.0 / args.fps
    now = time.perf_counter()
    last_valid = last_window = last_pad_try = last_stats = now
    lost = True
    shown = None
    reads = valid = bad = 0
    log("dry run: reading only, nothing is sent" if dry else "running: Ctrl+C to stop")
    try:
        while not s.stop.is_set():
            t0 = time.perf_counter()
            cells, info = reader.read()
            reads += 1
            if info == "no window":
                if t0 - last_window > 10:
                    log("game gone for 10 s: stopping")
                    break
            else:
                last_window = t0
            state = None
            if cells and None not in cells:
                try:
                    state = protocol.decode(cells)
                except DecodeError as e:
                    bad += 1
                    if bad in (1, 60) or bad % 600 == 0:
                        vlog(f"invalid frame at {info}: {e} ({bad} in a row)")
                    if bad % 30 == 0:
                        reader.forget()   # stuck on a wrong spot: scan the corner again
            if state:
                bad = 0
                valid += 1
                last_valid = t0
                if lost:
                    log(f"strip found at {info}")
                    lost = False
                new, event = link.feed(state)
                if new:
                    vlog(f"state seq {new.seq} L {new.left} R {new.right}")
                    if dry:
                        if (new.left, new.right) != shown:
                            shown = (new.left, new.right)
                            log(f"triggers L {new.left} R {new.right}")
                    else:
                        out.set(new.left, new.right)
                if event:
                    eid, gain = event
                    name = library[eid][0] if eid in library else f"#{eid}"
                    kind = "haptic" if clips.is_haptic(eid) else "sound"
                    if dry:
                        log(f"would play {kind} {name} gain {gain}")
                    elif s.player and eid in library:
                        _, left, right = library[eid]
                        if s.player.play(left, right, clips.is_haptic(eid), args.volume * gain_factor(gain)):
                            vlog(f"play {kind} {name} gain {gain}")
                    else:
                        vlog(f"skip {kind} {name}")
            elif not lost and t0 - last_valid > 1.0:
                log(f"strip lost ({info}): triggers off")
                lost = True
                link = Link(args.confirm)
                shown = None
                if out:
                    out.set(Trigger(), Trigger())
            if out:
                if not s.pad and t0 - last_pad_try > 5:
                    last_pad_try = t0
                    try:
                        s.pad = out.pad = open_pad(args)
                        out.sent = None
                    except OSError as e:
                        vlog(f"pad: {e}")
                try:
                    out.tick()
                except OSError as e:
                    log(f"pad: {e}; reopening")
                    s.pad.close()
                    s.pad = out.pad = None
            if VERBOSE and t0 - last_stats > 5:
                log(f"{reads / (t0 - last_stats):.0f} reads/s, {valid} valid")
                reads = valid = 0
                last_stats = t0
            spare = period - (time.perf_counter() - t0)
            if spare > 0:
                time.sleep(spare)
    except KeyboardInterrupt:
        pass
    finally:
        reader.close()
        s.close()
    return 0


def ask_enter(what):
    print(what)
    try:
        input("Press Enter to start (Ctrl+C to cancel): ")
        return True
    except (KeyboardInterrupt, EOFError):
        print("cancelled")
        return False


def do_demo_triggers(args):
    import dualsense
    pads = dualsense.find_dualsenses()
    if not pads:
        print("No DualSense found.")
        return 1
    print(f"{pads[0]['name']} over {pads[0]['transport'].upper()}.")
    D = dualsense
    # Numbered so the player can report which ones they felt: 1-5 the multi-position formats
    # (0x21/0x25/0x26), 6-8 the legacy raw modes (0x01/0x02/0x06). R2 only, then one L2 check.
    steps = [("R2", "1 resistance from the middle (0x21)", D.effect_feedback(4, 6)),
             ("R2", "2 resistance only in the middle (0x21 zones)", D.effect_multi_feedback([0, 0, 0, 6, 6, 6, 6, 0, 0, 0])),
             ("R2", "3 weapon click (0x25)", D.effect_weapon(3, 6, 8)),
             ("R2", "4 vibration 30 Hz (0x26)", D.effect_vibration(0, 6, 30)),
             ("R2", "5 slope, light to hard (0x21)", D.effect_slope(0, 9, 1, 8)),
             ("R2", "6 legacy resistance (0x01)", D.legacy_resistance(100, 200)),
             ("R2", "7 legacy section (0x02)", D.legacy_section(60, 160, 200)),
             ("R2", "8 legacy vibration (0x06)", D.legacy_vibration(30, 200, 0)),
             ("L2", "9 L2 resistance from the middle (0x21)", D.effect_feedback(4, 6))]
    if args.legacy_triggers:
        steps = [st for st in steps if "legacy" in st[1]]
    hold = 5
    if not ask_enter(f"Demo: {len(steps)} trigger effects, {hold} s each, numbered. "
                     "Keep squeezing slowly in and out; note which numbers you feel."):
        return 0
    s = Session()
    s.install()
    s.pad = dualsense.Pad(pads[0], transport=args.transport)
    s.out = out = dualsense.TriggerOutput(s.pad, log=log)
    off = D.effect_off()
    try:
        for side, label, eff in steps:
            print(f"{side}: {label}")
            out.wanted = (eff, off) if side == "L2" else (off, eff)
            out.tick(time.perf_counter() + 1)
            end = time.perf_counter() + hold
            while time.perf_counter() < end and not s.stop.is_set():
                time.sleep(0.05)
            if s.stop.is_set():
                raise KeyboardInterrupt
    except KeyboardInterrupt:
        pass
    finally:
        s.close()
    return 0


def do_demo_audio(args):
    import audio
    import clips
    dev = audio.find_dualsense_device() if args.audio_device is None else (args.audio_device, "chosen", 0)
    if not dev:
        print("No DualSense audio device (USB only).")
        return 1
    print(f"Device {dev[0]}: {dev[1]}")
    if not ask_enter("Demo: every built-in clip once, haptic clips first, then the speaker sounds."):
        return 0
    s = Session()
    s.install()
    library = clips.build_all()
    try:
        s.player = audio.Player(dev[0], channels=4, frames=args.audio_frames, buffers=args.audio_buffers, log=print)
        for cid in sorted(library):
            name, left, right = library[cid]
            if s.stop.is_set():
                break
            haptic = clips.is_haptic(cid)
            ok = s.player.play(left, right, haptic, args.volume)
            print(f"{cid:3d} {'haptic' if haptic else 'sound '} {name}{'' if ok else ' (skipped: 2 channels)'}")
            time.sleep(len(left) / clips.RATE + 0.8)
    except (KeyboardInterrupt, OSError) as e:
        if isinstance(e, OSError):
            print(f"audio: {e}")
    finally:
        s.close()
    return 0


def main(argv=None):
    global VERBOSE
    p = argparse.ArgumentParser(description="Gamepad Companion helper: DualSense triggers and haptics from the addon's corner strip.")
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument("--list", action="store_true", help="show the game window, DualSense HID devices and audio outputs (no writes)")
    mode.add_argument("--selftest", action="store_true", help="protocol, clips and report checks; no hardware")
    mode.add_argument("--dry-run", action="store_true", help="read the strip and print what would happen; sends nothing")
    mode.add_argument("--run", action="store_true", help="read the strip, drive triggers and play clips")
    mode.add_argument("--demo-triggers", action="store_true", help="try each trigger effect (asks first)")
    mode.add_argument("--demo-audio", action="store_true", help="play each built-in clip (asks first)")
    p.add_argument("-v", "--verbose", action="store_true", help="log every change")
    p.add_argument("--fps", type=float, default=60, help="reads per second (default 60)")
    p.add_argument("--confirm", type=int, default=2, help="identical reads before acting (default 2)")
    p.add_argument("--foreground", action="store_true", help="no WoW window found: read the foreground window")
    p.add_argument("--volume", type=float, default=1.0, help="master gain for clips (default 1.0; clips are quiet)")
    p.add_argument("--transport", choices=("usb", "bt"), help="override USB / Bluetooth detection")
    p.add_argument("--legacy-triggers", action="store_true", help="old raw effect modes 0x01/0x02/0x06 instead of 0x21/0x25/0x26")
    p.add_argument("--no-audio", action="store_true", help="triggers only")
    p.add_argument("--audio-device", type=int, help="waveOut device index (see --list)")
    p.add_argument("--audio-frames", type=int, default=480, help="frames per buffer (default 480 = 10 ms)")
    p.add_argument("--audio-buffers", type=int, default=3, help="buffers queued (default 3)")
    args = p.parse_args(argv)
    VERBOSE = args.verbose
    if args.list:
        return do_list(args)
    if args.selftest:
        import selftest
        return selftest.run()
    if args.dry_run:
        return run_loop(args, dry=True)
    if args.run:
        return run_loop(args, dry=False)
    if args.demo_triggers:
        return do_demo_triggers(args)
    if args.demo_audio:
        return do_demo_audio(args)
    return 2


if __name__ == "__main__":
    sys.exit(main())
