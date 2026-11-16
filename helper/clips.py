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

WOOD = ((1.0, 0.020, 1.0), (2.31, 0.012, 0.45), (3.87, 0.008, 0.25), (5.9, 0.005, 0.12))


def s_click():
    """A fingertip on a small wooden box: short, dry, woody."""
    s = resonate(strike(0.0012, 1.0, soft=0.3, seed=3), 0.06, [(820 * m, d, g) for m, d, g in WOOD])
    return _finish(s, 0.15, size=0.5, mix=0.08, tail=0.12)


# Speaker sounds follow WoW's mood: immersive and analog, never chiptune (no clean arpeggios,
# square waves, pure beeps or arcade pitch jumps). Built like real objects: a short strike of noise
# (the mallet, the finger, the coin edge) rings a bank of resonant modes (wood, metal, bell, cloth),
# then a small room, a little warmth (soft saturation, gentle top-end roll-off). The pad's speaker
# is tiny: low sounds carry their weight in their 150-400 Hz modes, not in a sub fundamental.

def strike(seconds, amp=1.0, soft=0.5, seed=1):
    """The excitation: a few ms of noise, smoothed (soft 0 = hard/bright, 0.9 = felt mallet)."""
    rnd = random.Random(seed)
    n = max(2, _n(seconds))
    out = array("f", bytes(4 * n))
    y = 0.0
    for i in range(n):
        y = soft * y + (1 - soft) * rnd.uniform(-1, 1)
        out[i] = amp * y * (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)))
    return out


def resonate(excite, seconds, modes):
    """Modal body: each (freq Hz, decay s, gain) is a two-pole resonator rung by the excitation."""
    n = _n(seconds)
    out = array("f", bytes(4 * n))
    for f, decay, g in modes:
        if f >= RATE / 2 - 100:
            continue
        r = math.exp(-1 / (decay * RATE))
        c1, c2 = 2 * r * math.cos(2 * math.pi * f / RATE), -r * r
        gain = g * (1 - r * r) * 40          # roughly level-independent of decay
        y1 = y2 = 0.0
        for i in range(n):
            x = excite[i] if i < len(excite) else 0.0
            y = c1 * y1 + c2 * y2 + gain * x
            out[i] += y
            y2, y1 = y1, y
    return out


def room(sig, size=1.0, mix=0.18, damp=0.45, tail=0.4):
    """A small wooden room (Schroeder: 4 damped combs + 2 allpasses), mixed under the dry sound."""
    extra = _n(tail)
    n = len(sig) + extra
    dry = array("f", sig) + array("f", bytes(4 * extra))
    wet = array("f", bytes(4 * n))
    for d_ms, fb in ((29.7, 0.80), (37.1, 0.78), (41.1, 0.76), (43.7, 0.74)):
        d = max(1, _n(d_ms * size / 1000))
        buf = [0.0] * d
        lp = 0.0
        for i in range(n):
            j = i % d
            out = buf[j]
            lp = out * (1 - damp) + lp * damp
            buf[j] = dry[i] + lp * fb
            wet[i] += out * 0.25
    for d_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = max(1, _n(d_ms / 1000))
        buf = [0.0] * d
        for i in range(n):
            j = i % d
            b = buf[j]
            v = wet[i] + g * b
            buf[j] = v
            wet[i] = b - g * v
    for i in range(n):
        dry[i] = dry[i] + mix * wet[i]
    # fade the very end so it lands on silence
    nf = min(n, _n(0.05))
    for i in range(nf):
        dry[n - 1 - i] *= i / nf
    return dry


def warm(sig, drive=1.6, roll=0.25):
    """Soft saturation and a gentle top-end roll-off: analog, not clinical."""
    k = math.tanh(drive)
    y = 0.0
    out = array("f", bytes(4 * len(sig)))
    peak = max((abs(v) for v in sig), default=1.0) or 1.0
    for i, v in enumerate(sig):
        x = math.tanh(drive * v / peak) / k * peak
        y = roll * y + (1 - roll) * x
        out[i] = y
    return out


def _finish(sig, peak=0.2, **room_args):
    return _both(_fit(warm(room(sig, **room_args)), peak))


# Struck metal rings at inharmonic ratios (a free plate / coin: 1, 2.76, 5.40, 8.93).
COIN = ((1.0, 0.09, 1.0), (2.76, 0.05, 0.6), (5.40, 0.03, 0.35), (8.93, 0.018, 0.2))


def s_coin():
    """A few coins settling in a leather pouch: irregular clinks, muffled by cloth."""
    rnd = random.Random(11)
    s = _blank(0.45)
    _add(s, noise(0.20, 0.05, decay=0.06, seed=12, lowpass=0.94))            # leather rustle
    for at, k in ((0.0, 1.0), (0.047, 0.65), (0.081, 0.5), (0.142, 0.35), (0.19, 0.2)):
        f0 = rnd.uniform(2100, 3200)
        modes = [(f0 * m, d * rnd.uniform(0.8, 1.2), g) for m, d, g in COIN]
        _add(s, resonate(strike(0.0015, k, soft=0.2, seed=rnd.randrange(999)), 0.25, modes),
             at=at + rnd.uniform(0, 0.01))
    return _finish(s, 0.22, size=0.6, mix=0.12)


def s_chime():
    """One small bronze bell, struck with a felt mallet: hum, strike note and a warm minor-third
    partial (real bell ratios), two of them slightly detuned so the tail breathes."""
    modes = ((0.5, 0.9, 0.35), (1.0, 0.7, 1.0), (1.003, 0.7, 0.6), (1.19, 0.5, 0.45),
             (1.5, 0.35, 0.3), (2.0, 0.25, 0.25), (2.66, 0.15, 0.12))
    s = resonate(strike(0.004, 1.0, soft=0.8, seed=21), 0.9, [(740 * m, d, g) for m, d, g in modes])
    return _finish(s, 0.2, size=1.3, mix=0.22, tail=0.5)


def s_thud():
    """A heavy pack set down on a wooden floor: a padded hit, the boards ringing low."""
    floor = ((150, 0.06, 1.0), (235, 0.045, 0.7), (370, 0.03, 0.4), (610, 0.015, 0.2))
    s = resonate(strike(0.008, 1.0, soft=0.85, seed=4), 0.22, floor)
    _add(s, noise(0.05, 0.08, decay=0.012, seed=6, lowpass=0.9))           # cloth and dust
    return _finish(s, 0.2, size=0.9, mix=0.15, tail=0.25)


def s_heartbeat():
    """A heartbeat heard from inside: lub-dub, muffled, felt more than heard."""
    body = ((95, 0.05, 1.0), (165, 0.04, 0.8), (260, 0.025, 0.35))
    s = _blank(0.5)
    _add(s, resonate(strike(0.012, 1.0, soft=0.9, seed=7), 0.16, body))
    _add(s, resonate(strike(0.010, 0.7, soft=0.9, seed=8), 0.16, [(f * 1.08, d, g) for f, d, g in body]), at=0.19)
    return _finish(s, 0.2, size=0.7, mix=0.08, tail=0.15)


def s_error():
    """Two dull knocks on an old door, the second softer: 'no' without a buzzer."""
    door = [(f * 1.0, d * 1.4, g) for f, d, g in ((230, 0.020, 1.0), (530, 0.012, 0.5),
                                                  (890, 0.008, 0.25), (1360, 0.005, 0.1))]
    s = _blank(0.32)
    for at, k, seed in ((0.0, 1.0, 5), (0.15, 0.65, 9)):
        _add(s, resonate(strike(0.003, k, soft=0.6, seed=seed), 0.14, door), at=at)
    return _finish(s, 0.2, size=1.0, mix=0.16, tail=0.2)


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
