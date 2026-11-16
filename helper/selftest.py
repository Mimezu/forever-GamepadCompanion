"""--selftest: protocol, strip reading, clips, effect bytes and reports. No hardware, nothing sent."""
import math
import os
import random
import re

import protocol
from protocol import State, Trigger, DecodeError

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
FIXTURE = os.path.join(ADDON, "tests", "fixtures", "helperlink-vectors.txt")
LUA = os.path.join(ADDON, "HelperLink.lua")

_count = 0


def check(cond, msg):
    global _count
    if not cond:
        raise AssertionError(msg)
    _count += 1


def rand_state(rnd):
    t = lambda: Trigger(rnd.randrange(8), rnd.randrange(16), rnd.randrange(16), rnd.randrange(16))  # noqa: E731
    return State(rnd.randrange(16), t(), t(), rnd.randrange(256), rnd.randrange(8))


def test_protocol():
    rnd = random.Random(5)
    for _ in range(3000):
        s = rand_state(rnd)
        cells = protocol.encode(s)
        check(len(cells) == 18 and all(v in (0, 1) for c in cells for v in c), "binary cells")
        check(protocol.decode(cells) == s, f"round trip {s}")
    for _ in range(500):
        cells = [list(c) for c in protocol.encode(rand_state(rnd))]
        c, k = 2 + rnd.randrange(16), rnd.randrange(3)
        cells[c][k] ^= 1
        try:
            protocol.decode(cells)
            check(False, "flip accepted")
        except DecodeError as e:
            check(str(e) == "checksum", "flip -> checksum")
    for bad, why in ((protocol.encode(State())[:17], "length"),
                     ([(0, 1, 0)] + protocol.encode(State())[1:], "marker")):
        try:
            protocol.decode(bad)
            check(False, why)
        except DecodeError as e:
            check(str(e) == why, why)
    check(protocol.classify(160) == 1 and protocol.classify(96) == 0 and protocol.classify(128) is None, "thresholds")
    # bit order spot checks (docs/HELPER.md): seq bit 0 = data cell 0 red; event bit 0 = bit 34 = cell 11 green
    check(protocol.encode(State(seq=1))[2][0] == 1, "seq bit 0")
    check(protocol.encode(State(event=1))[13][1] == 1, "event bit 0")


def test_fixture():
    """Vectors written by the Lua side (tests/HelperLink.lua --write): both encoders agree."""
    check(os.path.exists(FIXTURE), f"fixture missing: {FIXTURE}")
    n = 0
    with open(FIXTURE, encoding="ascii") as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            state, cells = protocol.parse_fixture_line(line)
            check(protocol.decode(cells) == state, f"Lua cells decode: {line.strip()}")
            check(protocol.encode(state) == [tuple(c) for c in cells], f"Python encodes as Lua: {line.strip()}")
            n += 1
    check(n >= 60, "fixture vectors")
    return n


def lua_table(name):
    with open(LUA, encoding="utf-8") as f:
        text = f.read()
    m = re.search(r"K\." + name + r"\s*=\s*\{(.*?)\n\}", text, re.S)
    check(m is not None, f"K.{name} in HelperLink.lua")
    return {k: int(v) for k, v in re.findall(r"(\w+)\s*=\s*(\d+)", m.group(1))}


def image(cells, size, ox, oy, w=320, h=40, on=225, off=30, bg=(40, 40, 40)):
    """A BGRA screen grab holding the strip."""
    buf = bytearray(w * h * 4)
    for i in range(w * h):
        buf[i * 4:i * 4 + 4] = bytes((bg[2], bg[1], bg[0], 255))
    for i, c in enumerate(cells):
        rgb = [on if v else off for v in c]
        for y in range(oy, oy + size):
            for x in range(ox + i * size, ox + (i + 1) * size):
                k = (y * w + x) * 4
                buf[k:k + 4] = bytes((rgb[2], rgb[1], rgb[0], 255))
    return bytes(buf), w, h


def test_strip():
    import screen
    s = State(9, Trigger(1, 3, 0, 9), Trigger(4, 0, 10, 7), 130, 5)
    cells = protocol.encode(s)
    for size, ox, oy in ((4, 0, 0), (4, 3, 2), (1, 0, 0), (2, 10, 5), (8, 1, 1), (3, 0, 7)):
        buf, w, h = image(cells, size, ox, oy)
        got, where = screen.read_strip(buf, w, h)
        check(got is not None and where == (ox, oy, size), f"found at {ox},{oy} size {size}: {where}")
        check(protocol.decode(got) == s, "strip decodes")
        got2, where2 = screen.read_strip(buf, w, h, hint=where)
        check(where2 == where, "hint")
    # gamma / brightness: 'on' at 170, 'off' at 90 still reads
    buf, w, h = image(cells, 4, 0, 0, on=170, off=90)
    got, _ = screen.read_strip(buf, w, h)
    check(protocol.decode(got) == s, "dim strip")
    # a blend between on and off (e.g. a scaled strip): invalid, not misread
    buf, w, h = image(cells, 4, 0, 0, on=130, off=30)
    got, _ = screen.read_strip(buf, w, h)
    check(got is None or None in got, "mid values invalid")
    # nothing there
    got, why = screen.read_strip(*image([], 4, 0, 0))
    check(got is None and why == "no strip", "no strip")


def _zero_cross_freq(sig, rate):
    xs = [i for i in range(1, len(sig)) if (sig[i - 1] < 0) != (sig[i] < 0)]
    if len(xs) < 3:
        return 0
    return (len(xs) - 1) / 2 / ((xs[-1] - xs[0]) / rate)


def test_clips():
    import clips
    lua_clips, lua_sounds = lua_table("CLIPS"), lua_table("SOUNDS")
    check({n: i for i, (n, _) in clips.CLIPS.items()} == lua_clips, "clip names / ids match K.CLIPS")
    check({n: i for i, (n, _) in clips.SOUNDS.items()} == lua_sounds, "sound names / ids match K.SOUNDS")
    lib = clips.build_all()
    for cid, (name, left, right) in lib.items():
        check(len(left) == len(right) and len(left) > 0, f"{name} length")
        peak = max(max(abs(v) for v in left), max(abs(v) for v in right))
        check(all(math.isfinite(v) for v in left) and all(math.isfinite(v) for v in right), f"{name} finite")
        check(0 < peak <= 0.85, f"{name} peak {peak:.2f}")
        if cid >= 128:
            check(peak <= 0.25, f"{name} quiet speaker sound")
        check(abs(left[-1]) < 0.02 and abs(right[-1]) < 0.02, f"{name} ends near zero")
    for cid in (1, 2, 3):
        name, left, right = lib[cid]
        sig = left if cid != 3 else right
        dur = len(sig) / clips.RATE
        f = _zero_cross_freq(sig, clips.RATE)
        peak = max(abs(v) for v in sig)
        check(0.030 <= dur <= 0.060, f"{name} 30-60 ms: {dur * 1000:.0f}")
        check(150 <= f <= 250, f"{name} 150-250 Hz: {f:.0f}")
        check(peak <= 0.25, f"{name} faint")
    check(max(abs(v) for v in lib[2][2]) == 0 and max(abs(v) for v in lib[3][1]) == 0, "one-sided taps")
    f = _zero_cross_freq(lib[4][1], clips.RATE)
    check(55 <= f <= 95, f"thump low: {f:.0f}")
    check(len(lib[4][1]) > 4 * len(lib[1][1]), "thump much longer than a tap (contrast)")


def crc32_bitwise(data, crc=0):
    crc ^= 0xFFFFFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ (0xEDB88320 if crc & 1 else 0)
    return crc ^ 0xFFFFFFFF


def test_reports():
    import dualsense as d
    h = lambda b: b.hex(" ")  # noqa: E731
    check(d.effect_off() == bytes([5] + [0] * 10), "off")
    check(h(d.effect_feedback(0, 8)) == "21 ff 03 ff ff ff 3f 00 00 00 00", "feedback full")
    check(h(d.effect_feedback(5, 1)) == "21 e0 03 00 00 00 00 00 00 00 00", "feedback light from zone 5")
    check(h(d.effect_feedback(9, 2)) == "21 00 02 00 00 00 08 00 00 00 00", "feedback zone 9 strength 2")
    check(h(d.effect_weapon(2, 8, 8)) == "25 04 01 07 00 00 00 00 00 00 00", "weapon")
    check(h(d.effect_weapon(4, 6, 5)) == "25 50 00 04 00 00 00 00 00 00 00", "weapon 4-6")
    check(h(d.effect_vibration(0, 8, 10)) == "26 ff 03 ff ff ff 3f 00 00 0a 00", "vibration")
    check(d.effect_weapon(1, 8, 8) == d.effect_off() and d.effect_feedback(10, 1) == d.effect_off(), "out of range -> off")
    check(h(d.effect_multi_feedback([0, 0, 3, 3, 3, 0, 0, 0, 0, 0])) == "21 1c 00 80 24 00 00 00 00 00 00", "section")
    sl = d.effect_slope(0, 9, 1, 8)
    check(sl[0] == 0x21 and sl[1] == 0xFF and sl[2] == 0x03, "slope zones")
    forces = int.from_bytes(sl[3:7], "little")
    strengths = [((forces >> (3 * i)) & 7) + 1 for i in range(10)]
    check(strengths == sorted(strengths) and strengths[0] == 1 and strengths[-1] == 8, f"slope rises {strengths}")
    rnd = random.Random(2)
    for _ in range(2000):
        t = Trigger(rnd.randrange(8), rnd.randrange(16), rnd.randrange(16), rnd.randrange(16))
        for legacy in (False, True):
            e = d.trigger_effect(t, legacy)
            check(len(e) == 11, "11 bytes")
            if t.mode == 0 or t.mode > 5:
                check(e == d.effect_off(), "off modes")
            elif not legacy:
                check(e[0] in (0x21, 0x25, 0x26), f"modern id {t}")
            else:
                check(e[0] in (0x01, 0x02, 0x06), f"legacy id {t}")
    # USB report: only flag0 trigger bits and the two trigger blocks
    right, left = d.effect_feedback(3, 6), d.effect_weapon(2, 6, 7)
    r = d.build_report("usb", right=right, left=left)
    check(len(r) == 64 and r[0] == 0x02, "usb id / length")
    check(r[1] == 0x0C and r[2] == 0, "usb flags: triggers only, no LED flags")
    check(r[11:22] == right and r[22:33] == left, "usb trigger offsets")
    rest = r[3:11] + r[33:]
    check(not any(rest), "usb: every other byte (rumble, volumes, LEDs) zero")
    r1 = d.build_report("usb", right=right)
    check(r1[1] == 0x04 and not any(r1[22:33]), "right only")
    # Bluetooth: id, seq_tag, tag, common at 3, CRC32 seeded with 0xA2 at 74
    b = d.build_report("bt", right=right, left=left, seq=5)
    check(len(b) == 78 and b[0] == 0x31 and b[1] == 0x50 and b[2] == 0x10, "bt header")
    check(b[3] == 0x0C and b[4] == 0 and b[13:24] == right and b[24:35] == left, "bt common")
    check(not any(b[5:13] + b[35:74]), "bt: every other byte zero")
    check(crc32_bitwise(b"123456789") == 0xCBF43926, "reference CRC32")
    want = crc32_bitwise(b"\xa2" + b[:74])
    check(int.from_bytes(b[74:78], "little") == want, "bt crc = crc32(0xA2 + report[0:74])")
    check(d.bt_crc(b"abc") == crc32_bitwise(b"\xa2abc"), "seeded crc")
    check(len(d.build_report("bt", right=right, length=547)) == 547, "bt padded to the device length")


def test_output_and_link():
    import dualsense as d
    from gpc_helper import Link, gain_factor

    class FakePad:
        def __init__(self):
            self.sent = []

        def send(self, right=None, left=None):
            self.sent.append((left, right))

    pad = FakePad()
    out = d.TriggerOutput(pad, interval=0.020)
    check(out.tick(0.0) is True and pad.sent[-1] == (d.effect_off(), d.effect_off()), "first write: off")
    check(out.tick(0.1) is False, "unchanged: no write")
    out.set(Trigger(1, 0, 0, 15), Trigger())
    check(out.tick(0.105) is True, "change written")
    out.set(Trigger(1, 5, 0, 15), Trigger())
    check(out.tick(0.110) is False, "within 20 ms: waits")
    check(out.tick(0.126) is True and len(pad.sent) == 3, "then written")

    link = Link(confirm=2)
    a = State(3, Trigger(1, 0, 0, 9), Trigger(), 0, 0)
    check(link.feed(a) == (None, None), "needs 2 reads")
    check(link.feed(a) == (a, None), "first state: no event")
    check(link.feed(a) == (None, None), "unchanged")
    b = State(4, a.left, a.right, 5, 3)
    link.feed(b)
    check(link.feed(b) == (b, (5, 3)), "seq change fires")
    c = State(4, Trigger(2, 1, 2, 3), a.right, 5, 3)
    link.feed(c)
    check(link.feed(c) == (c, None), "trigger change, same seq: no event")
    d0 = State(4, c.left, c.right, 0, 0)
    link.feed(d0)
    check(link.feed(d0) == (d0, None), "event cleared: nothing")
    glitch = State(9, Trigger(), Trigger(), 77, 1)
    check(link.feed(glitch) == (None, None) and link.feed(d0) == (None, None), "a one-frame glitch is ignored")
    check(gain_factor(0) == 0.125 and gain_factor(7) == 1.0, "gain")


def test_mixer():
    from array import array
    import audio
    m = audio.Mixer(4)
    one = array("f", [0.6] * 10)
    zero = array("f", [0.0] * 10)
    check(m.add(one, zero, haptic=True, gain=1.0), "haptic voice")
    check(m.add(one, one, haptic=False, gain=0.5), "speaker voice")
    m.add(one, zero, haptic=True, gain=1.0)
    out = m.render(8)
    check(len(out) == 32, "4 channels x 8 frames")
    check(out[0] == int(0.3 * 32767) and out[1] == int(0.3 * 32767), "speaker on 1-2")
    check(out[2] == 32767 and out[3] == 0, "haptics on 3-4, summed and clamped")
    out = m.render(8)
    check(out[8] == 0 and len(m.voices) == 0, "voices end")
    check(m.render(8) is None, "silence")
    m2 = audio.Mixer(2)
    check(not m2.add(one, one, haptic=True, gain=1) and m2.add(one, one, haptic=False, gain=1), "2 ch: speaker only")
    fmt = audio.make_format(4)
    import ctypes
    check(ctypes.sizeof(fmt) == 40 and fmt.Format.cbSize == 22 and fmt.dwChannelMask == 0x33, "WAVEFORMATEXTENSIBLE")
    check(fmt.Format.nBlockAlign == 8 and fmt.Format.nAvgBytesPerSec == 384000, "format numbers")
    check(ctypes.sizeof(audio.WAVEOUTCAPSW) == 84, "WAVEOUTCAPSW size")


def run():
    steps = [("protocol", test_protocol), ("Lua fixture", test_fixture), ("strip reader", test_strip),
             ("clips", test_clips), ("trigger effects and reports", test_reports),
             ("output and link", test_output_and_link), ("mixer", test_mixer)]
    failed = 0
    for name, fn in steps:
        before = _count
        try:
            extra = fn()
            print(f"ok    {name} ({_count - before} checks{', %d vectors' % extra if extra else ''})")
        except AssertionError as e:
            failed += 1
            print(f"FAIL  {name}: {e}")
    print("selftest:", "passed" if not failed else f"{failed} failed", f"({_count} checks)")
    return 1 if failed else 0
