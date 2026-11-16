"""Built-in clips, generated in code (no files). Ids and names match HelperLink.lua's K.CLIPS / K.SOUNDS.

Haptic clips (1-127) go to the pad's actuators (audio channels 3-4: left, right grip). Speaker
sounds (128-255) go to channels 1-2. Every clip is (left, right) float arrays at 48 kHz in -1..1.

Design rule from the in-game probes (docs/HAPTICS.md): rhythm and contrast. Very faint short
micro taps (150-250 Hz, 30-60 ms) against longer, lower rumbles; length reads as intensity.
All levels are quiet by default: the helper's --volume and the event gain scale them further.
"""
import math
import random
from array import array

RATE = 48000


def _n(seconds):
    return int(round(seconds * RATE))


def _blank(seconds):
    return array("f", bytes(4 * _n(seconds)))


def _add(dst, src, at=0.0, gain=1.0):
    o = _n(at)
    end = min(len(dst), o + len(src))
    for i in range(o, end):
        dst[i] += src[i - o] * gain
    return dst


def tone(freq, seconds, attack=0.004, decay=None, release=0.01, amp=1.0, freq_to=None, harmonics=None):
    """A sine (with optional harmonics and glide). decay: exponential time constant (s), else held.
    attack / release: raised-cosine edges (no clicks)."""
    n = _n(seconds)
    out = array("f", bytes(4 * n))
    na, nr = max(1, _n(attack)), max(1, _n(release))
    phase = 0.0
    harmonics = harmonics or ((1, 1.0),)
    norm = sum(a for _, a in harmonics)
    for i in range(n):
        t = i / RATE
        f = freq if freq_to is None else freq + (freq_to - freq) * (i / n)
        phase += 2 * math.pi * f / RATE
        env = amp
        if i < na:
            env *= 0.5 - 0.5 * math.cos(math.pi * i / na)
        if decay:
            env *= math.exp(-t / decay)
        if i >= n - nr:
            env *= 0.5 - 0.5 * math.cos(math.pi * (n - i) / nr)
        out[i] = env * sum(a * math.sin(phase * k) for k, a in harmonics) / norm
    return out


def burst(freq, seconds, amp):
    """A Hann-windowed burst: the micro tap shape (no ramp to smear it)."""
    n = _n(seconds)
    return array("f", (amp * (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1))) *
                       math.sin(2 * math.pi * freq * i / RATE) for i in range(n)))


def noise(seconds, amp, decay=None, seed=1, lowpass=0.0):
    rnd = random.Random(seed)
    n = _n(seconds)
    out = array("f", bytes(4 * n))
    y = 0.0
    for i in range(n):
        x = rnd.uniform(-1, 1)
        y = lowpass * y + (1 - lowpass) * x
        env = amp * (math.exp(-(i / RATE) / decay) if decay else 1.0)
        out[i] = y * env
    return out


def _fit(sig, peak):
    """Scale to a peak level."""
    m = max((abs(v) for v in sig), default=0.0)
    if m > 0:
        k = peak / m
        for i in range(len(sig)):
            sig[i] *= k
    return sig


def _pan(sig, start, end):
    """Mono -> (left, right), panned -1..1 linearly from start to end (constant power)."""
    n = len(sig)
    left, right = array("f", bytes(4 * n)), array("f", bytes(4 * n))
    for i in range(n):
        p = start + (end - start) * i / max(1, n - 1)
        a = (p + 1) * math.pi / 4
        left[i], right[i] = sig[i] * math.cos(a), sig[i] * math.sin(a)
    return left, right


def _both(sig):
    return sig, array("f", sig)


def _left(sig):
    return sig, array("f", bytes(4 * len(sig)))


def _right(sig):
    return array("f", bytes(4 * len(sig))), sig


# --- Haptic clips ---------------------------------------------------------------------------

def micro_tap():
    return _both(burst(200, 0.040, 0.18))


def heartbeat():
    s = _blank(0.60)
    _add(s, tone(65, 0.16, attack=0.006, decay=0.05, amp=0.55))
    _add(s, tone(58, 0.16, attack=0.006, decay=0.05, amp=0.35), at=0.20)
    return _both(s)


def thump():
    return _both(tone(75, 0.28, attack=0.004, decay=0.07, amp=0.6))


def crackle():
    rnd = random.Random(7)
    s = _blank(0.45)
    t = 0.0
    while t < 0.40:
        _add(s, burst(rnd.uniform(170, 240), rnd.uniform(0.008, 0.016), rnd.uniform(0.12, 0.3)), at=t)
        t += rnd.uniform(0.012, 0.05)
    return _pan(s, -0.5, 0.5)


def rumble_rise():
    n = _n(0.9)
    base = tone(60, 0.9, attack=0.01, release=0.03, freq_to=110)
    for i in range(n):
        base[i] *= 0.05 + 0.55 * (i / n) ** 1.6
    return _both(base)


def release_hit():
    s = _blank(0.25)
    _add(s, burst(220, 0.012, 0.6))
    _add(s, tone(90, 0.24, attack=0.003, decay=0.06, amp=0.8), at=0.004)
    return _both(_fit(s, 0.8))


def swing_light():
    s = tone(160, 0.18, attack=0.08, release=0.08, amp=0.25)
    return _pan(s, -1, 1)


def swing_heavy():
    s = tone(90, 0.30, attack=0.14, release=0.12, amp=0.5, harmonics=((1, 1.0), (2, 0.25)))
    return _pan(s, -1, 1)


def landing_soft():
    s = _blank(0.20)
    _add(s, burst(120, 0.060, 0.25))
    _add(s, tone(70, 0.13, attack=0.01, decay=0.05, amp=0.15), at=0.05)
    return _both(s)


def landing_hard():
    s = _blank(0.40)
    _add(s, burst(200, 0.010, 0.5))
    _add(s, tone(70, 0.38, attack=0.003, decay=0.11, amp=0.8, freq_to=50), at=0.003)
    return _both(_fit(s, 0.8))


# --- Speaker sounds (mono to both speaker channels) -------------------------------------------

def s_click():
    s = _blank(0.02)
    _add(s, burst(2000, 0.004, 0.15))
    _add(s, noise(0.006, 0.05, decay=0.002, seed=3))
    return _both(s)


def s_coin():
    s = _blank(0.45)
    for at, k in ((0.0, 1.0), (0.09, 0.8)):
        _add(s, tone(2637, 0.3, attack=0.001, decay=0.06, amp=0.12 * k, harmonics=((1, 1.0), (1.5, 0.6))), at=at)
    return _both(s)


def s_chime():
    s = _blank(0.9)
    for i, f in enumerate((1047, 1319, 1568)):
        _add(s, tone(f, 0.5, attack=0.003, decay=0.15, amp=0.10, harmonics=((1, 1.0), (2, 0.2))), at=i * 0.15)
    return _both(s)


def s_thud():
    s = _blank(0.2)
    _add(s, tone(110, 0.18, attack=0.002, decay=0.04, amp=0.2, freq_to=80, harmonics=((1, 1.0), (2, 0.5), (3, 0.25))))
    _add(s, noise(0.03, 0.06, decay=0.008, seed=4, lowpass=0.8))
    return _both(s)


def s_heartbeat():
    s = _blank(0.5)
    _add(s, tone(120, 0.12, attack=0.004, decay=0.035, amp=0.18, harmonics=((1, 1.0), (2, 0.4), (3, 0.2))))
    _add(s, tone(110, 0.12, attack=0.004, decay=0.035, amp=0.12, harmonics=((1, 1.0), (2, 0.4), (3, 0.2))), at=0.2)
    return _both(s)


def s_error():
    s = _blank(0.32)
    buzz = ((1, 1.0), (3, 0.33), (5, 0.2), (7, 0.14))   # a soft square
    _add(s, tone(150, 0.11, attack=0.004, release=0.02, amp=0.10, harmonics=buzz))
    _add(s, tone(150, 0.11, attack=0.004, release=0.02, amp=0.10, harmonics=buzz), at=0.18)
    return _both(s)


# id -> (name, generator). Haptic 1-127, speaker 128-255.
CLIPS = {
    1: ("micro_tap", micro_tap),
    2: ("micro_tap_left", lambda: _left(burst(200, 0.040, 0.18))),
    3: ("micro_tap_right", lambda: _right(burst(200, 0.040, 0.18))),
    4: ("thump", thump),
    5: ("heartbeat", heartbeat),
    6: ("crackle", crackle),
    7: ("rumble_rise", rumble_rise),
    8: ("release_hit", release_hit),
    9: ("swing_light", swing_light),
    10: ("swing_heavy", swing_heavy),
    11: ("landing_soft", landing_soft),
    12: ("landing_hard", landing_hard),
}
SOUNDS = {
    128: ("click", s_click),
    129: ("coin", s_coin),
    130: ("chime", s_chime),
    131: ("thud", s_thud),
    132: ("heartbeat_thump", s_heartbeat),
    133: ("error", s_error),
}


def is_haptic(event_id):
    return 1 <= event_id <= 127


def build_all():
    """id -> (name, left, right)."""
    out = {}
    for table in (CLIPS, SOUNDS):
        for cid, (name, gen) in table.items():
            left, right = gen()
            out[cid] = (name, left, right)
    return out
