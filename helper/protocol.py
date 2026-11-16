"""The corner-pixel protocol (docs/HELPER.md). Identical to HelperLink.lua's K.Encode / K.Decode."""
from dataclasses import dataclass, field

NCELLS = 18
MARKERS = ((1, 0, 1), (0, 1, 0))  # magenta, green
ON, OFF = 160, 96                 # channel thresholds (0-255): >= ON on, <= OFF off, else invalid

MODE_NAMES = {0: "off", 1: "resist", 2: "section", 3: "weapon", 4: "vibrate", 5: "slope"}


@dataclass(frozen=True)
class Trigger:
    mode: int = 0
    start: int = 0
    finish: int = 0
    force: int = 0

    def __str__(self):
        if self.mode == 0:
            return "off"
        return f"{MODE_NAMES.get(self.mode, self.mode)}({self.start},{self.finish},{self.force})"


@dataclass(frozen=True)
class State:
    seq: int = 0
    left: Trigger = field(default_factory=Trigger)
    right: Trigger = field(default_factory=Trigger)
    event: int = 0
    gain: int = 0


def _clamp(v, hi):
    v = int(round(v or 0))
    return 0 if v < 0 else hi if v > hi else v


def _put(bits, pos, value, n):
    for i in range(n):
        bits[pos + i] = (value >> i) & 1


def _get(bits, pos, n):
    return sum(bits[pos + i] << i for i in range(n))


def _checksum(bits):
    x = 0
    for g in range(15):
        x ^= _get(bits, g * 3, 3)
    return x


def _put_trigger(bits, pos, t):
    _put(bits, pos, _clamp(t.mode, 7), 3)
    _put(bits, pos + 3, _clamp(t.start, 15), 4)
    _put(bits, pos + 7, _clamp(t.finish, 15), 4)
    _put(bits, pos + 11, _clamp(t.force, 15), 4)


def _get_trigger(bits, pos):
    return Trigger(_get(bits, pos, 3), _get(bits, pos + 3, 4), _get(bits, pos + 7, 4), _get(bits, pos + 11, 4))


def encode(state):
    """State -> 18 (r, g, b) cells of 0/1."""
    bits = [0] * 48
    _put(bits, 0, _clamp(state.seq, 10**9) % 16, 4)
    _put_trigger(bits, 4, state.left)
    _put_trigger(bits, 19, state.right)
    _put(bits, 34, _clamp(state.event, 255), 8)
    _put(bits, 42, _clamp(state.gain, 7), 3)
    _put(bits, 45, _checksum(bits), 3)
    return [MARKERS[0], MARKERS[1]] + [tuple(bits[c * 3:c * 3 + 3]) for c in range(16)]


class DecodeError(ValueError):
    pass


def decode(cells):
    """18 (r, g, b) cells of 0/1 -> State. Raises DecodeError (length, marker, value, checksum)."""
    if len(cells) != NCELLS:
        raise DecodeError("length")
    if tuple(cells[0]) != MARKERS[0] or tuple(cells[1]) != MARKERS[1]:
        raise DecodeError("marker")
    bits = []
    for cell in cells[2:]:
        for v in cell:
            if v not in (0, 1):
                raise DecodeError("value")
            bits.append(v)
    if _checksum(bits) != _get(bits, 45, 3):
        raise DecodeError("checksum")
    return State(_get(bits, 0, 4), _get_trigger(bits, 4), _get_trigger(bits, 19), _get(bits, 34, 8), _get(bits, 42, 3))


def classify(v):
    """One colour channel (0-255) -> 1, 0 or None (invalid)."""
    if v >= ON:
        return 1
    if v <= OFF:
        return 0
    return None


def classify_rgb(r, g, b):
    c = (classify(r), classify(g), classify(b))
    return None if None in c else c


def parse_fixture_line(line):
    """'seq lm ls lf lfo rm rs rf rfo event gain : 18 digits' -> (State, cells)."""
    nums, digits = line.split(":")
    n = [int(x) for x in nums.split()]
    state = State(n[0], Trigger(*n[1:5]), Trigger(*n[5:9]), n[9], n[10])
    cells = [((int(d) >> 2) & 1, (int(d) >> 1) & 1, int(d) & 1) for d in digits.strip()]
    return state, cells
