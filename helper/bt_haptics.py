"""True haptics (and later the speaker) over Bluetooth: output report 0x36.

Layout from daidr/dualsense-tester (src/utils/dualsense/btAudioStream.ts, MIT), which plays music
and haptics over Bluetooth from a browser. 398 bytes: report id 0x36, then a 397-byte payload of
three sub-packets and a CRC32 (seeded with 0xA2, 0x36) in the last 4 bytes:
  [0]       seq << 4
  [1..65]   0x90 control sub-packet (0x90, 0x3F, then the common output block from [3]:
            valid_flag0 [3], flag1 [4], speaker volume [8], audio control [10])
  [66..276] 0x91 audio sub-packet: 0x91 07 FE 40 40 40 40 40, frame counter, route (0x93 speaker,
            0x96 headphone), 0xC8 (200), then one 200-byte Opus frame (48 kHz stereo CBR 160k, 10 ms)
  [277..340] 0x92 haptics sub-packet: 0x92, 0x40 (64), 32 stereo frames of int8 PCM at 3000 Hz
One report per 10.667 ms (the pad plays 32 haptic frames at 3 kHz, and 480 audio samples at ~45 kHz).
No Opus encoder here: the audio sub-packet carries a silent frame (what WebCodecs makes for silence
at these settings: F4 FF FE then zeros).
"""
import time
import zlib
from array import array

REPORT_ID = 0x36
PAYLOAD_LEN = 397
HAPTIC_RATE = 3000
FRAMES_PER_REPORT = 32
PERIOD = FRAMES_PER_REPORT / HAPTIC_RATE      # 10.667 ms
SILENT_OPUS = bytes([0xF4, 0xFF, 0xFE]) + bytes(197)


def _i8(v):
    v = int(round(max(-1.0, min(1.0, v)) * 127))
    return v & 0xFF


def to_haptic_frames(left, right, rate=48000, gain=1.0):
    """Float clips (any rate) -> list of 64-byte frames (int8 L/R interleaved, 3000 Hz).
    Box-filter decimation: the average over each 1/3000 s step."""
    step = rate / HAPTIC_RATE
    n = int(len(left) / step)
    frames = []
    for start in range(0, n, FRAMES_PER_REPORT):
        f = bytearray(64)
        for j in range(FRAMES_PER_REPORT):
            k = start + j
            if k >= n:
                break
            a, b = int(k * step), max(int(k * step) + 1, int((k + 1) * step))
            f[2 * j] = _i8(gain * sum(left[a:b]) / (b - a))
            f[2 * j + 1] = _i8(gain * sum(right[a:b]) / (b - a))
        frames.append(bytes(f))
    return frames


def build_report(haptic, seq, counter, control=True, length=None):
    p = bytearray(PAYLOAD_LEN)
    p[0] = (seq & 0x0F) << 4
    p[1], p[2] = 0x90, 0x3F
    if control:              # as the tester: speaker volume + audio control valid, audio control 0x09
        p[3] = 0xA0
        p[8] = 0x00          # speaker volume 0: haptics only
        p[10] = 0x09
    p[66:74] = bytes([0x91, 0x07, 0xFE, 0x40, 0x40, 0x40, 0x40, 0x40])
    p[74] = counter & 0xFF
    p[75] = 0x93
    p[76] = 0xC8
    p[77:277] = SILENT_OPUS
    p[277], p[278] = 0x92, 0x40
    p[279:343] = haptic
    crc = zlib.crc32(bytes(p[:-4]), zlib.crc32(bytes([0xA2, REPORT_ID]))) & 0xFFFFFFFF
    p[-4:] = crc.to_bytes(4, "little")
    r = bytes([REPORT_ID]) + bytes(p)
    if length and length > len(r):
        r += bytes(length - len(r))
    return r


class Streamer:
    """Plays haptic frames to a dualsense.Pad, one report per 10.667 ms, catching up on late sleeps."""

    def __init__(self, pad, control=True):
        self.pad, self.control = pad, control
        self.seq = 0
        self.counter = 0

    def play(self, frames, tail=4):
        frames = list(frames) + [bytes(64)] * tail   # a few silent frames to end cleanly
        t = time.perf_counter()
        for f in frames:
            self.pad.write_raw(build_report(f, self.seq, self.counter, self.control, self.pad.length))
            self.seq = (self.seq + 1) & 0x0F
            self.counter = (self.counter + 1) & 0xFF
            t += PERIOD
            wait = t - time.perf_counter()
            if wait > 0.002:
                time.sleep(wait - 0.0015)
            while time.perf_counter() < t:
                pass


def selftest(check):
    from clips import micro_tap
    l, r = micro_tap()
    fr = to_haptic_frames(l, r)
    check(len(fr) == -(-int(len(l) / 16) // 32), "frame count")
    check(all(len(f) == 64 for f in fr), "frame size")
    check(max(b if b < 128 else 256 - b for f in fr for b in f) > 10, "tap has signal")
    rep = build_report(fr[0], 3, 7, length=547)
    check(len(rep) == 547 and rep[0] == 0x36 and rep[1] == 0x30, "header")
    check(rep[2] == 0x90 and rep[67] == 0x91 and rep[278] == 0x92 and rep[279] == 0x40, "sub-packets")
    body = rep[1:398]
    crc = zlib.crc32(bytes([0xA2, 0x36]) + body[:-4]) & 0xFFFFFFFF
    check(int.from_bytes(body[-4:], "little") == crc, "crc")
