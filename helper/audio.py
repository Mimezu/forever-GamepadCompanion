"""DualSense audio out through winmm waveOut (ctypes): 4 channels, 48 kHz, 16-bit, a small mixer.

Over USB the DualSense is a 4-channel audio device: channels 1-2 the speaker / headset jack,
channels 3-4 the left / right haptic actuators. Speaker sounds mix into 1-2, haptic clips into
3-4. If 4 channels can't be opened, it falls back to 2 (speaker only) and says so.

UNCERTAIN (hardware): Windows must keep the device at 4 channels (Sound settings, the controller's
speaker setup "Quadraphonic"); set to stereo, the audio engine may fold channels 3-4 into the
speaker. Device names are cut to 31 characters by WAVEOUTCAPS, so we match "Wireless Contr".
"""
import ctypes
import threading
from array import array
from ctypes import wintypes

RATE = 48000
WAVE_FORMAT_EXTENSIBLE = 0xFFFE
WAVE_FORMAT_PCM = 1
CALLBACK_EVENT = 0x00050000
WHDR_DONE = 0x00000001
WAVERR_BADFORMAT = 32
SPEAKER_FL, SPEAKER_FR, SPEAKER_BL, SPEAKER_BR = 0x1, 0x2, 0x10, 0x20
NAME_HINTS = ("wireless contr", "dualsense")

winmm = ctypes.WinDLL("winmm")
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)


class GUID(ctypes.Structure):
    _fields_ = [("Data1", wintypes.DWORD), ("Data2", wintypes.WORD), ("Data3", wintypes.WORD),
                ("Data4", ctypes.c_ubyte * 8)]


KSDATAFORMAT_SUBTYPE_PCM = GUID(0x00000001, 0x0000, 0x0010, (ctypes.c_ubyte * 8)(0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71))


class WAVEFORMATEX(ctypes.Structure):
    _pack_ = 1
    _fields_ = [("wFormatTag", wintypes.WORD), ("nChannels", wintypes.WORD), ("nSamplesPerSec", wintypes.DWORD),
                ("nAvgBytesPerSec", wintypes.DWORD), ("nBlockAlign", wintypes.WORD),
                ("wBitsPerSample", wintypes.WORD), ("cbSize", wintypes.WORD)]


class WAVEFORMATEXTENSIBLE(ctypes.Structure):
    _pack_ = 1
    _fields_ = [("Format", WAVEFORMATEX), ("wValidBitsPerSample", wintypes.WORD),
                ("dwChannelMask", wintypes.DWORD), ("SubFormat", GUID)]


class WAVEHDR(ctypes.Structure):
    _fields_ = [("lpData", ctypes.c_void_p), ("dwBufferLength", wintypes.DWORD),
                ("dwBytesRecorded", wintypes.DWORD), ("dwUser", ctypes.c_size_t), ("dwFlags", wintypes.DWORD),
                ("dwLoops", wintypes.DWORD), ("lpNext", ctypes.c_void_p), ("reserved", ctypes.c_size_t)]


class WAVEOUTCAPSW(ctypes.Structure):
    _fields_ = [("wMid", wintypes.WORD), ("wPid", wintypes.WORD), ("vDriverVersion", wintypes.UINT),
                ("szPname", wintypes.WCHAR * 32), ("dwFormats", wintypes.DWORD), ("wChannels", wintypes.WORD),
                ("wReserved1", wintypes.WORD), ("dwSupport", wintypes.DWORD)]


HWAVEOUT = ctypes.c_void_p
winmm.waveOutGetNumDevs.restype = wintypes.UINT
winmm.waveOutGetDevCapsW.argtypes = [ctypes.c_size_t, ctypes.POINTER(WAVEOUTCAPSW), wintypes.UINT]
winmm.waveOutOpen.argtypes = [ctypes.POINTER(HWAVEOUT), wintypes.UINT, ctypes.c_void_p, ctypes.c_size_t,
                              ctypes.c_size_t, wintypes.DWORD]
winmm.waveOutPrepareHeader.argtypes = [HWAVEOUT, ctypes.POINTER(WAVEHDR), wintypes.UINT]
winmm.waveOutUnprepareHeader.argtypes = [HWAVEOUT, ctypes.POINTER(WAVEHDR), wintypes.UINT]
winmm.waveOutWrite.argtypes = [HWAVEOUT, ctypes.POINTER(WAVEHDR), wintypes.UINT]
winmm.waveOutReset.argtypes = [HWAVEOUT]
winmm.waveOutClose.argtypes = [HWAVEOUT]
kernel32.CreateEventW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.BOOL, wintypes.LPCWSTR]
kernel32.CreateEventW.restype = wintypes.HANDLE
kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
kernel32.CloseHandle.argtypes = [wintypes.HANDLE]


def list_devices():
    """[(index, name, channels)]"""
    out = []
    for i in range(winmm.waveOutGetNumDevs()):
        caps = WAVEOUTCAPSW()
        if winmm.waveOutGetDevCapsW(i, ctypes.byref(caps), ctypes.sizeof(caps)) == 0:
            out.append((i, caps.szPname, caps.wChannels))
    return out


def find_dualsense_device():
    for i, name, ch in list_devices():
        if any(h in name.lower() for h in NAME_HINTS):
            return i, name, ch
    return None


def make_format(channels):
    fmt = WAVEFORMATEXTENSIBLE()
    f = fmt.Format
    f.wFormatTag = WAVE_FORMAT_EXTENSIBLE
    f.nChannels = channels
    f.nSamplesPerSec = RATE
    f.wBitsPerSample = 16
    f.nBlockAlign = channels * 2
    f.nAvgBytesPerSec = RATE * channels * 2
    f.cbSize = ctypes.sizeof(WAVEFORMATEXTENSIBLE) - ctypes.sizeof(WAVEFORMATEX)   # 22
    fmt.wValidBitsPerSample = 16
    fmt.dwChannelMask = (SPEAKER_FL | SPEAKER_FR | SPEAKER_BL | SPEAKER_BR) if channels == 4 else (SPEAKER_FL | SPEAKER_FR)
    fmt.SubFormat = KSDATAFORMAT_SUBTYPE_PCM
    return fmt


class Mixer:
    """Pure mixing (testable without a device): voices add up per channel, clamped to 16 bits."""

    def __init__(self, channels):
        self.channels = channels
        self.voices = []        # [left, right, pos, ch_left, ch_right, gain]
        self.lock = threading.Lock()

    def add(self, left, right, haptic, gain):
        if haptic and self.channels < 4:
            return False
        a, b = (2, 3) if haptic else (0, 1)
        with self.lock:
            self.voices.append([left, right, 0, a, b, gain])
        return True

    def stop(self):
        with self.lock:
            self.voices.clear()

    def render(self, frames):
        ch = self.channels
        with self.lock:
            voices = list(self.voices)
        if not voices:
            return None
        mix = [0.0] * (frames * ch)
        done = []
        for v in voices:
            left, right, pos, a, b, gain = v
            n = min(frames, len(left) - pos)
            for i in range(n):
                k = i * ch
                mix[k + a] += left[pos + i] * gain
                mix[k + b] += right[pos + i] * gain
            v[2] = pos + n
            if v[2] >= len(left):
                done.append(v)
        if done:
            with self.lock:
                self.voices = [v for v in self.voices if v not in done]
        return array("h", (32767 if s >= 1 else -32767 if s <= -1 else int(s * 32767) for s in mix))


class Player:
    """waveOut device + mixer thread. N buffers of `frames` frames (default 3 x 10 ms)."""

    def __init__(self, device, channels=4, frames=480, buffers=3, log=print):
        self.log = log
        self.device = device
        self.handle = HWAVEOUT()
        self.event = kernel32.CreateEventW(None, False, False, None)
        self.channels = None
        for ch in ((channels, 2) if channels == 4 else (channels,)):
            fmt = make_format(ch)
            r = winmm.waveOutOpen(ctypes.byref(self.handle), device, ctypes.byref(fmt), self.event, 0, CALLBACK_EVENT)
            if r == 0:
                self.channels = ch
                break
            log(f"audio: {ch} channels refused (MMRESULT {r})")
        if self.channels is None:
            kernel32.CloseHandle(self.event)
            raise OSError("audio device would not open")
        if self.channels < 4:
            log("audio: opened as 2 channels: speaker only, no haptics (USB and the 4-channel setup needed)")
        self.frames = frames
        self.mixer = Mixer(self.channels)
        self.silence = bytes(frames * self.channels * 2)
        self.bufs, self.hdrs = [], []
        for _ in range(buffers):
            buf = ctypes.create_string_buffer(len(self.silence))
            hdr = WAVEHDR()
            hdr.lpData = ctypes.cast(buf, ctypes.c_void_p)
            hdr.dwBufferLength = len(self.silence)
            winmm.waveOutPrepareHeader(self.handle, ctypes.byref(hdr), ctypes.sizeof(WAVEHDR))
            self.bufs.append(buf)
            self.hdrs.append(hdr)
        self.running = True
        for i in range(buffers):
            self._submit(i)
        self.thread = threading.Thread(target=self._loop, name="gpc-audio", daemon=True)
        self.thread.start()

    def _submit(self, i):
        data = self.mixer.render(self.frames)
        raw = self.silence if data is None else data.tobytes()
        ctypes.memmove(self.bufs[i], raw, len(raw))
        self.hdrs[i].dwFlags &= ~WHDR_DONE
        winmm.waveOutWrite(self.handle, ctypes.byref(self.hdrs[i]), ctypes.sizeof(WAVEHDR))

    def _loop(self):
        while self.running:
            kernel32.WaitForSingleObject(self.event, 50)
            for i, hdr in enumerate(self.hdrs):
                if self.running and hdr.dwFlags & WHDR_DONE:
                    self._submit(i)

    def play(self, left, right, haptic, gain):
        return self.mixer.add(left, right, haptic, gain)

    def stop(self):
        self.mixer.stop()

    def close(self):
        if not self.running:
            return
        self.running = False
        self.mixer.stop()
        self.thread.join(1)
        winmm.waveOutReset(self.handle)
        for hdr in self.hdrs:
            winmm.waveOutUnprepareHeader(self.handle, ctypes.byref(hdr), ctypes.sizeof(WAVEHDR))
        winmm.waveOutClose(self.handle)
        kernel32.CloseHandle(self.event)
